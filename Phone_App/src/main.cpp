/**
 * ============================================================
 *  OpenClaw ESP32 Firmware — Arduino Core 3.x  (No BLE, No MQTT)
 *
 *  Features:
 *   - 4 relays (active LOW), 2 PWM outputs (LEDC Core 3.x API)
 *   - APDS-9930 I2C driver (lux + proximity)
 *   - MQ-2 smoke detection with fan-lock override
 *   - Gamma-corrected eased LED fading
 *   - Radar presence + proximity flashlight + touch strip control
 *   - AsyncWebServer + WebSocket dashboard
 *   - ArduinoOTA with password
 *   - NVS state persistence + smoke calibration
 *   - FreeRTOS sensor task on Core 0
 *   - Watchdog armed AFTER setup() completes
 *
 *  Build:
 *   platform = https://github.com/platformio/platform-espressif32.git#develop
 *   See platformio.ini for full config.
 * ============================================================
 */

// ─────────────────────────────────────────────
//  SECTION 0 — INCLUDES
// ─────────────────────────────────────────────
#include <Arduino.h>
#include <ArduinoJson.h>
#include <ArduinoOTA.h>
#include <AsyncTCP.h>
#include <ESPAsyncWebServer.h>
#include <ESPmDNS.h>
#include <Preferences.h>
#include <WiFi.h>
#include <Wire.h>
#include <esp_task_wdt.h>
#include <time.h>

// ─────────────────────────────────────────────
//  SECTION 1 — USER CONFIG
// ─────────────────────────────────────────────
#define WIFI_SSID "1706-2.4G"
#define WIFI_PASS "12345678@"

#define NTP_SERVER "pool.ntp.org"
#define NTP_OFFSET_SEC 19800 // IST = UTC+5:30

#define WDT_TIMEOUT_MS 30000 // 30 seconds

// ─────────────────────────────────────────────
//  SECTION 2 — PIN DEFINITIONS
// ─────────────────────────────────────────────
// Relays (Active LOW)
#define PIN_RELAY_LIGHTS 26
#define PIN_RELAY_FAN 27
#define PIN_RELAY_RGB_AC 14
#define PIN_RELAY_SOCKET 25

// MOSFET PWM (D4184) — 5kHz max
#define PIN_MOSFET_FLASH 32
#define PIN_MOSFET_STRIP 33

// Sensors
#define PIN_RADAR 4
#define PIN_TOUCH 5
#define PIN_MQ2_ANALOG 34  // ADC1_CH6 — input only
#define PIN_MQ2_DIGITAL 35 // input only

// I2C — APDS-9930
#define PIN_I2C_SDA 21
#define PIN_I2C_SCL 22

// Status
#define PIN_STATUS_LED 2

// LEDC — Core 3.x
#define LEDC_FREQ_HZ 5000
#define LEDC_RESOLUTION 8 // 8-bit = 0–255
#define LEDC_CH_FLASH 0
#define LEDC_CH_STRIP 1

// ─────────────────────────────────────────────
//  SECTION 3 — FADE STATE STRUCT
// ─────────────────────────────────────────────
struct FadeState {
  uint8_t current = 0;
  uint8_t target = 0;
  uint32_t stepMs = 10;
  uint32_t lastMs = 0;
  bool active = false;
  uint8_t channel = 0;
};

static FadeState gFlashFade;
static FadeState gStripFade;

// ─────────────────────────────────────────────
//  SECTION 4 — APDS-9930 I2C DRIVER (raw, no lib)
// ─────────────────────────────────────────────
#define APDS9930_ADDR 0x39
#define APDS9930_ENABLE 0x00
#define APDS9930_ATIME 0x01
#define APDS9930_PPULSE 0x0E
#define APDS9930_CONTROL 0x0F
#define APDS9930_ID 0x12
#define APDS9930_CH0DATAL 0x14
#define APDS9930_CH0DATAH 0x15
#define APDS9930_CH1DATAL 0x16
#define APDS9930_CH1DATAH 0x17
#define APDS9930_PDATAL 0x18
#define APDS9930_PDATAH 0x19
#define APDS9930_POFFSET 0x1E
#define CMD_BYTE 0x80

static bool apds_ok = false;

static bool apds_write(uint8_t reg, uint8_t val) {
  Wire.beginTransmission(APDS9930_ADDR);
  Wire.write(CMD_BYTE | reg);
  Wire.write(val);
  return Wire.endTransmission() == 0;
}

static uint8_t apds_read8(uint8_t reg) {
  Wire.beginTransmission(APDS9930_ADDR);
  Wire.write(CMD_BYTE | reg);
  Wire.endTransmission();
  Wire.requestFrom((uint8_t)APDS9930_ADDR, (uint8_t)1);
  return Wire.available() ? Wire.read() : 0;
}

static uint16_t apds_read16(uint8_t regLow) {
  Wire.beginTransmission(APDS9930_ADDR);
  Wire.write(CMD_BYTE | regLow);
  Wire.endTransmission();
  Wire.requestFrom((uint8_t)APDS9930_ADDR, (uint8_t)2);
  if (Wire.available() < 2)
    return 0;
  uint16_t lo = Wire.read();
  uint16_t hi = Wire.read();
  return (hi << 8) | lo;
}

static bool apds_init() {
  Wire.begin(PIN_I2C_SDA, PIN_I2C_SCL);
  Wire.setClock(100000);
  delay(10);
  uint8_t id = apds_read8(APDS9930_ID);
  if (id != 0x39 && id != 0x12 && id != 0x29) {
    Serial.printf(
        "[APDS] Bad ID: 0x%02X — check wiring (continuing without sensor)\n",
        id);
    return false;
  }
  apds_write(APDS9930_ENABLE, 0x00);
  apds_write(APDS9930_ATIME, 0xED);   // 50ms integration
  apds_write(APDS9930_PPULSE, 0x08);  // 8 pulses
  apds_write(APDS9930_CONTROL, 0x20); // PDRIVE=100mA, AGAIN=1x
  apds_write(APDS9930_POFFSET, 0x00);
  apds_write(APDS9930_ENABLE, 0x0F); // PON|AEN|PEN|WEN
  delay(60);
  Serial.printf("[APDS] OK — ID=0x%02X\n", id);
  return true;
}

static float apds_getLux() {
  if (!apds_ok)
    return 0.0f;
  uint16_t ch0 = apds_read16(APDS9930_CH0DATAL);
  uint16_t ch1 = apds_read16(APDS9930_CH1DATAL);
  if (ch0 == 0)
    return 0.0f;
  float ratio = (float)ch1 / (float)ch0;
  float lux;
  if (ratio < 0.50f)
    lux = 0.0304f * ch0 - 0.062f * ch0 * powf(ratio, 1.4f);
  else if (ratio < 0.61f)
    lux = 0.0224f * ch0 - 0.031f * ch1;
  else if (ratio < 0.80f)
    lux = 0.0128f * ch0 - 0.0153f * ch1;
  else if (ratio < 1.30f)
    lux = 0.00146f * ch0 - 0.00112f * ch1;
  else
    lux = 0.0f;
  return lux * 52.0f; // DF=52
}

static uint16_t apds_getProximity() {
  if (!apds_ok)
    return 0;
  return apds_read16(APDS9930_PDATAL);
}

// ─────────────────────────────────────────────
//  SECTION 5 — SENSOR CACHE (mutex-safe)
// ─────────────────────────────────────────────
struct SensorCache {
  float lux = 0.0f;
  uint16_t prox = 0;
  int mqRaw = 0;
  bool mqAlarm = false;
  bool radar = false;
};

static SensorCache gSensors;
static portMUX_TYPE gSensorMux = portMUX_INITIALIZER_UNLOCKED;

static float sensors_getLux() {
  portENTER_CRITICAL(&gSensorMux);
  float v = gSensors.lux;
  portEXIT_CRITICAL(&gSensorMux);
  return v;
}
static uint16_t sensors_getProximity() {
  portENTER_CRITICAL(&gSensorMux);
  uint16_t v = gSensors.prox;
  portEXIT_CRITICAL(&gSensorMux);
  return v;
}
static int sensors_getMQRaw() {
  portENTER_CRITICAL(&gSensorMux);
  int v = gSensors.mqRaw;
  portEXIT_CRITICAL(&gSensorMux);
  return v;
}
static bool sensors_getRadar() {
  portENTER_CRITICAL(&gSensorMux);
  bool v = gSensors.radar;
  portEXIT_CRITICAL(&gSensorMux);
  return v;
}

// ─────────────────────────────────────────────
//  SECTION 6 — NVS PERSISTENCE
// ─────────────────────────────────────────────
static Preferences prefs;

struct PersistState {
  bool r[4] = {false, false, false, false};
  uint8_t flash = 0;
  uint8_t strip = 0;
  int cigs = 0;
  String mode = "awake";
};
static PersistState gNVS;

static void nvs_save() {
  prefs.begin("openclaw", false);
  prefs.putBool("r0", gNVS.r[0]);
  prefs.putBool("r1", gNVS.r[1]);
  prefs.putBool("r2", gNVS.r[2]);
  prefs.putBool("r3", gNVS.r[3]);
  prefs.putUChar("flash", gNVS.flash);
  prefs.putUChar("strip", gNVS.strip);
  prefs.putInt("cigs", gNVS.cigs);
  prefs.putString("mode", gNVS.mode);
  prefs.end();
}

static void nvs_load() {
  prefs.begin("openclaw", false);
  gNVS.r[0] = prefs.getBool("r0", false);
  gNVS.r[1] = prefs.getBool("r1", false);
  gNVS.r[2] = prefs.getBool("r2", false);
  gNVS.r[3] = prefs.getBool("r3", false);
  gNVS.flash = prefs.getUChar("flash", 0);
  gNVS.strip = prefs.getUChar("strip", 0);
  gNVS.cigs = prefs.getInt("cigs", 0);
  gNVS.mode = prefs.getString("mode", "awake");
  prefs.end();
  Serial.println("[NVS] Loaded from flash.");
}

// ─────────────────────────────────────────────
//  SECTION 7 — HARDWARE CONTROL
// ─────────────────────────────────────────────

// Forward declaration — defined in Section 8 (Smoke Tracker)
static bool gSmokeOverride = false;

static const uint8_t RELAY_PINS[4] = {PIN_RELAY_LIGHTS, PIN_RELAY_FAN,
                                      PIN_RELAY_RGB_AC, PIN_RELAY_SOCKET};
static bool gRelayState[4] = {false, false, false, false};
static uint8_t gFlashBright = 0;
static uint8_t gStripBright = 0;

static void hw_initGPIO() {
  for (int i = 0; i < 4; i++) {
    pinMode(RELAY_PINS[i], OUTPUT);
    digitalWrite(RELAY_PINS[i], HIGH); // Active LOW — start OFF
  }

  // Core 2.x LEDC API: setup channel, then attach pin
  ledcSetup(LEDC_CH_FLASH, LEDC_FREQ_HZ, LEDC_RESOLUTION);
  ledcAttachPin(PIN_MOSFET_FLASH, LEDC_CH_FLASH);
  ledcWrite(LEDC_CH_FLASH, 0);

  ledcSetup(LEDC_CH_STRIP, LEDC_FREQ_HZ, LEDC_RESOLUTION);
  ledcAttachPin(PIN_MOSFET_STRIP, LEDC_CH_STRIP);
  ledcWrite(LEDC_CH_STRIP, 0);

  pinMode(PIN_RADAR, INPUT);
  pinMode(PIN_TOUCH, INPUT);
  pinMode(PIN_MQ2_DIGITAL, INPUT);
  pinMode(PIN_STATUS_LED, OUTPUT);
  digitalWrite(PIN_STATUS_LED, LOW);

  Serial.println("[HW] GPIO initialized (LEDC channels 0,1)");
}

// Active LOW: true = ON → GPIO LOW
static void hw_setRelay(int ch, bool on) {
  if (ch == 1 && gSmokeOverride && !on)
    return;
  if (ch < 0 || ch > 3)
    return;
  gRelayState[ch] = on;
  digitalWrite(RELAY_PINS[ch], on ? LOW : HIGH);
  gNVS.r[ch] = on;
  nvs_save();
}

static void hw_setPWM_flash(uint8_t val) {
  ledcWrite(LEDC_CH_FLASH, val);
  gFlashBright = val;
  gNVS.flash = val;
  nvs_save();
}

static void hw_setPWM_strip(uint8_t val) {
  ledcWrite(LEDC_CH_STRIP, val);
  gStripBright = val;
  gNVS.strip = val;
  nvs_save();
}

// Non-blocking fades
static void hw_fadeFlash(uint8_t target, uint32_t durationMs) {
  gFlashFade.current = gFlashBright;
  gFlashFade.target = target;
  gFlashFade.channel = LEDC_CH_FLASH;
  uint8_t delta = (uint8_t)abs((int)target - (int)gFlashBright);
  gFlashFade.stepMs = (delta == 0)
                          ? durationMs
                          : max((uint32_t)1, (uint32_t)(durationMs / delta));
  gFlashFade.lastMs = millis();
  gFlashFade.active = true;
}

static void hw_fadeStrip(uint8_t target, uint32_t durationMs) {
  gStripFade.current = gStripBright;
  gStripFade.target = target;
  gStripFade.channel = LEDC_CH_STRIP;
  uint8_t delta = (uint8_t)abs((int)target - (int)gStripBright);
  gStripFade.stepMs = (delta == 0)
                          ? durationMs
                          : max((uint32_t)1, (uint32_t)(durationMs / delta));
  gStripFade.lastMs = millis();
  gStripFade.active = true;
}

static uint8_t gamma8(uint8_t x) {
  float xf = x / 255.0f;
  xf = powf(xf, 2.2f);
  return (uint8_t)(xf * 255.0f);
}
static void hw_processSingleFade(FadeState &f) {
  if (!f.active)
    return;
  uint32_t now = millis();
  if (now - f.lastMs < f.stepMs)
    return;
  f.lastMs = now;
  if (f.current == f.target) {
    f.active = false;
    return;
  }
  int diff = (int)f.target - (int)f.current;
  int step = diff / 5;
  if (step == 0)
    step = (diff > 0) ? 1 : -1;
  f.current += step;
  uint8_t corrected = gamma8(f.current);
  ledcWrite(f.channel, corrected);
  if (f.channel == LEDC_CH_STRIP)
    gStripBright = f.current;
  else
    gFlashBright = f.current;
}

static void hw_processFades() {
  hw_processSingleFade(gFlashFade);
  hw_processSingleFade(gStripFade);
}

static uint8_t hw_getFlashBrightness() { return gFlashBright; }
static uint8_t hw_getStripBrightness() { return gStripBright; }

// ─────────────────────────────────────────────
//  SECTION 8 — SMOKE TRACKER DSP
// ─────────────────────────────────────────────
// gSmokeOverride declared in Section 7 (before hw_setRelay uses it)
enum SmokePhase { SMOKE_WARMUP, SMOKE_CALIBRATE, SMOKE_IDLE, SMOKE_COOLDOWN };

struct SmokeTracker {
  SmokePhase phase = SMOKE_WARMUP;
  uint32_t phaseMs = 0;
  float sumAcc = 0;
  float sumSq = 0;
  int samples = 0;
  float baseline = 310.0f;
  float sigma = 30.0f;
  float threshold = 380.0f;
  bool smoking = false;
  uint32_t cooldownMs = 0;
  int cigCount = 0;
};
static SmokeTracker gSmoke;

static void smoke_update(int raw) {
  uint32_t now = millis();
  switch (gSmoke.phase) {
  case SMOKE_WARMUP:
    if (now - gSmoke.phaseMs > 30000UL) {
      gSmoke.phase = SMOKE_CALIBRATE;
      gSmoke.phaseMs = now;
      gSmoke.sumAcc = 0;
      gSmoke.sumSq = 0;
      gSmoke.samples = 0;
      Serial.println("[Smoke] Calibrating...");
    }
    break;
  case SMOKE_CALIBRATE:
    gSmoke.sumAcc += raw;
    gSmoke.sumSq += (float)raw * raw;
    gSmoke.samples++;
    if (now - gSmoke.phaseMs > 120000UL) {
      float mean = gSmoke.sumAcc / gSmoke.samples;
      float var = (gSmoke.sumSq / gSmoke.samples) - mean * mean;
      gSmoke.baseline = mean;
      gSmoke.sigma = sqrtf(var);
      gSmoke.threshold = mean + 3.0f * gSmoke.sigma;
      gSmoke.phase = SMOKE_IDLE;
      Serial.printf("[Smoke] Done — base=%.0f σ=%.0f thr=%.0f\n",
                    gSmoke.baseline, gSmoke.sigma, gSmoke.threshold);
      prefs.begin("openclaw", false);
      prefs.putFloat("smk_base", gSmoke.baseline);
      prefs.putFloat("smk_thr", gSmoke.threshold);
      prefs.end();
    }
    break;
  case SMOKE_IDLE:
    if (raw > 2700) {
      gSmoke.smoking = true;
      gSmoke.phase = SMOKE_COOLDOWN;
      gSmokeOverride = true;
      gSmoke.cooldownMs = now;
      gSmoke.cigCount++;
      gNVS.cigs = gSmoke.cigCount;
      nvs_save();
      Serial.printf("[Smoke] Detected! count=%d\n", gSmoke.cigCount);
      hw_setRelay(1, true); // fan ON
    }
    break;
  case SMOKE_COOLDOWN:
    if (raw <= gSmoke.baseline + gSmoke.sigma) {
      if (now - gSmoke.cooldownMs > 180000UL) {
        gSmoke.smoking = false;
        gSmoke.phase = SMOKE_IDLE;
        gSmokeOverride = false;
        hw_setRelay(1, false); // fan OFF
        Serial.println("[Smoke] Cleared — fan off.");
      }
    } else {
      gSmoke.cooldownMs = now;
    }
    break;
  }
}

static bool smoke_isCalibrated() {
  return gSmoke.phase != SMOKE_WARMUP && gSmoke.phase != SMOKE_CALIBRATE;
}

// ─────────────────────────────────────────────
//  SECTION 9 — AUTOMATION STATE MACHINE
// ─────────────────────────────────────────────
enum SystemMode { MODE_AWAKE, MODE_SLEEP };
static SystemMode gMode = MODE_AWAKE;

static bool gPresent = false;
static uint32_t gAbsenceStartMs = 0;
static bool gLastRadar = false;
static bool gStripManualOff = false;

static bool gLastTouch = false;
static uint32_t gTouchDownMs = 0;
static bool gTouchHeld = false;

static bool gLastProxHigh = false;
static uint32_t gLastProxTrigMs = 0;

#define ABSENCE_TIMEOUT_MS 300000UL // 5 min
#define PROX_COOLDOWN_MS 1500UL
#define PROX_THRESHOLD 200

static uint8_t luxToStripTarget(float lux) {
  if (lux < 30.0f)
    return 80;
  if (lux < 80.0f)
    return 140;
  if (lux < 150.0f)
    return 200;
  return 255;
}

static uint8_t luxToFlashTarget(float lux) {
  if (lux < 50.0f)
    return 60;
  if (lux < 150.0f)
    return 150;
  return 255;
}

static uint8_t triangleWave(uint32_t elapsed, uint32_t period, uint8_t lo,
                            uint8_t hi) {
  uint32_t pos = elapsed % period;
  float t = (float)pos / (float)period;
  float val = (t < 0.5f) ? lo + (hi - lo) * (t * 2.0f)
                         : hi - (hi - lo) * ((t - 0.5f) * 2.0f);
  return (uint8_t)constrain((int)val, (int)lo, (int)hi);
}

static void automation_setMode(const String &modeStr) {
  if (modeStr == "sleep") {
    gMode = MODE_SLEEP;
    hw_fadeStrip(30, 1500);
    hw_fadeFlash(0, 1000);
  } else {
    gMode = MODE_AWAKE;
  }
  gNVS.mode = modeStr;
  nvs_save();
}

static void automation_tick() {
  uint32_t now = millis();
  float lux = sensors_getLux();
  bool radar = sensors_getRadar();
  uint16_t prox = sensors_getProximity();
  bool touch = (bool)digitalRead(PIN_TOUCH);

  // ── RADAR PRESENCE ──
  if (radar && !gLastRadar) {
    if (!gPresent) {
      gPresent = true;
      Serial.println("[Auto] Presence ENTRY");
      if (gMode == MODE_AWAKE) {
        hw_fadeStrip(luxToStripTarget(lux), 1200);
        gStripManualOff = false;
      }
    }
    gAbsenceStartMs = 0;
  }
  if (!radar && gLastRadar && gPresent) {
    gAbsenceStartMs = now;
  }
  gLastRadar = radar;

  // ── ABSENCE TIMEOUT ──
  if (gPresent && gAbsenceStartMs > 0) {
    if (now - gAbsenceStartMs > ABSENCE_TIMEOUT_MS) {
      gPresent = false;
      gAbsenceStartMs = 0;
      gStripManualOff = false;
      hw_fadeStrip(0, 2000);
      hw_fadeFlash(0, 1500);
      Serial.println("[Auto] Absence timeout — all off");
    }
  }

  // ── PROXIMITY → FLASHLIGHT TOGGLE ──
  bool proxHigh = (prox > PROX_THRESHOLD);
  if (proxHigh && !gLastProxHigh) {
    if (now - gLastProxTrigMs > PROX_COOLDOWN_MS) {
      gLastProxTrigMs = now;
      if (hw_getFlashBrightness() > 0)
        hw_fadeFlash(0, 1000);
      else
        hw_fadeFlash(luxToFlashTarget(lux), 1000);
      Serial.println("[Auto] Prox → Flash toggle");
    }
  }
  gLastProxHigh = proxHigh;

  // ── TOUCH SENSOR ──
  if (touch && !gLastTouch) {
    gTouchDownMs = now;
    gTouchHeld = false;
  }
  if (touch) {
    uint32_t held = now - gTouchDownMs;
    if (held >= 2000) {
      if (!gTouchHeld) {
        gTouchHeld = true;
        Serial.println("[Auto] Long-press: ramp");
      }
      uint8_t rv = triangleWave(now - (gTouchDownMs + 2000), 4000, 30, 255);
      ledcWrite(LEDC_CH_STRIP, rv);
      gStripBright = rv;
    }
  }
  if (!touch && gLastTouch) {
    uint32_t held = now - gTouchDownMs;
    if (gTouchHeld) {
      gNVS.strip = gStripBright;
      nvs_save();
      Serial.printf("[Auto] Strip locked at %d\n", gStripBright);
    } else if (held < 2000) {
      if (gStripBright > 0) {
        hw_fadeStrip(0, 600);
        gStripManualOff = true;
      } else {
        hw_fadeStrip(luxToStripTarget(lux), 600);
        gStripManualOff = false;
      }
    }
    gTouchHeld = false;
  }
  gLastTouch = touch;
}

// ─────────────────────────────────────────────
//  SECTION 10 — TIME HELPER
// ─────────────────────────────────────────────
static bool getLocalHourMinute(int &hour, int &minute) {
  struct tm ti;
  if (!getLocalTime(&ti, 0)) {
    hour = 0;
    minute = 0;
    return false;
  }
  hour = ti.tm_hour;
  minute = ti.tm_min;
  return true;
}

// ─────────────────────────────────────────────
//  SECTION 11 — STATE JSON BUILDER
// ─────────────────────────────────────────────
// Use DynamicJsonDocument — avoids large stack allocation on Core 3.x
static String buildStateJson() {
  DynamicJsonDocument doc(512);
  JsonArray rel = doc.createNestedArray("relays");
  for (int i = 0; i < 4; i++)
    rel.add(gRelayState[i]);

  doc["flash"] = gFlashBright;
  doc["strip"] = gStripBright;
  doc["lux"] = sensors_getLux();
  doc["smoke"] = sensors_getMQRaw();
  doc["present"] = gPresent;
  doc["prox"] = sensors_getProximity();
  doc["cigs"] = gSmoke.cigCount;
  doc["calibrated"] = smoke_isCalibrated();
  doc["baseline"] = (int)gSmoke.baseline;
  doc["threshold"] = (int)gSmoke.threshold;
  doc["smoking"] = gSmoke.smoking;
  doc["mode"] = (gMode == MODE_SLEEP) ? "sleep" : "awake";
  doc["rssi"] = WiFi.RSSI();
  doc["ip"] = WiFi.localIP().toString();
  doc["uptime"] = (uint32_t)(millis() / 1000);
  doc["heap"] = ESP.getFreeHeap();

  int h, m;
  getLocalHourMinute(h, m);
  doc["hour"] = h;
  doc["minute"] = m;

  String out;
  serializeJson(doc, out);
  return out;
}

// ─────────────────────────────────────────────
//  SECTION 12 — UNIFIED COMMAND HANDLER
// ─────────────────────────────────────────────
static void handleCommand(const String &jsonStr) {
  DynamicJsonDocument doc(256);
  if (deserializeJson(doc, jsonStr))
    return;

  // ── Primary dialect ──
  if (doc.containsKey("cmd")) {
    String cmd = doc["cmd"].as<String>();
    if (cmd == "relay") {
      int ch = doc["ch"] | -1;
      bool val = doc["val"] | false;
      if (ch >= 0 && ch <= 3)
        hw_setRelay(ch, val);
    } else if (cmd == "flash") {
      hw_fadeFlash((uint8_t)constrain(doc["val"] | 0, 0, 255), 400);
    } else if (cmd == "strip") {
      hw_fadeStrip((uint8_t)constrain(doc["val"] | 0, 0, 255), 400);
    } else if (cmd == "mode") {
      automation_setMode(doc["val"] | "awake");
    } else if (cmd == "all_off") {
      for (int i = 0; i < 4; i++)
        hw_setRelay(i, false);
      hw_fadeFlash(0, 800);
      hw_fadeStrip(0, 800);
    } else if (cmd == "all_on") {
      for (int i = 0; i < 4; i++)
        hw_setRelay(i, true);
    } else if (cmd == "reset_cigs") {
      gSmoke.cigCount = 0;
      gNVS.cigs = 0;
      nvs_save();
    }
    return;
  }

  // ── PWM dialect ──
  if (doc.containsKey("command")) {
    String command = doc["command"].as<String>();
    if (command == "set_pwm") {
      int ch = doc["channel"] | 0;
      int val = doc["value"] | 0;
      if (ch == 0)
        hw_fadeFlash((uint8_t)constrain(val, 0, 255), 300);
      else
        hw_fadeStrip((uint8_t)constrain(val, 0, 255), 300);
    }
  }
}

// ─────────────────────────────────────────────
//  SECTION 13 — WEB SERVER + WEBSOCKET
// ─────────────────────────────────────────────
static const char DASHBOARD_HTML[] PROGMEM = R"rawhtml(
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
<title>OpenClaw</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#000;color:#fff;font-family:system-ui;display:flex;flex-direction:column;height:100vh;align-items:center;justify-content:center;gap:12px;padding:12px}
.card{background:rgba(255,255,255,0.08);backdrop-filter:blur(20px);border:1px solid rgba(255,255,255,0.14);border-radius:18px;padding:16px 20px;width:100%;max-width:480px}
.row{display:flex;gap:10px;flex-wrap:wrap;justify-content:center}
.btn{flex:1;min-width:90px;height:58px;border-radius:14px;border:1px solid rgba(255,255,255,0.18);background:rgba(255,255,255,0.06);color:#fff;font-size:13px;cursor:pointer;transition:all .2s;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:3px}
.btn.on{background:rgba(255,255,255,0.22);border-color:rgba(255,255,255,0.5);box-shadow:0 0 20px rgba(255,255,255,0.2)}
.clock{font-size:2.6rem;font-weight:700;letter-spacing:2px;text-align:center;text-shadow:0 0 30px rgba(255,255,255,0.4)}
.lbl{font-size:11px;color:#777;text-align:center}
.stat-row{display:flex;justify-content:space-around;font-size:12px;color:#aaa}
.sv{font-weight:700;color:#fff}
input[type=range]{width:100%;accent-color:#fff;margin:4px 0}
.dot{width:8px;height:8px;border-radius:50%;background:#333;position:fixed;top:12px;right:12px;transition:background .3s}
.dot.ok{background:#fff}
</style>
</head>
<body>
<div class="dot" id="dot"></div>
<div class="card"><div class="clock" id="clk">--:--</div><div class="lbl" id="lbl2">openclaw</div></div>
<div class="card">
 <div class="row">
  <button class="btn" id="b0" onclick="toggle(0)"><span>💡</span><span>Lights</span></button>
  <button class="btn" id="b1" onclick="toggle(1)"><span>⌀</span><span>Fan</span></button>
  <button class="btn" id="b2" onclick="toggle(2)"><span>✦</span><span>RGB AC</span></button>
  <button class="btn" id="b3" onclick="toggle(3)"><span>⚡</span><span>Socket</span></button>
 </div>
</div>
<div class="card">
 <div class="lbl">LED Strip</div>
 <input type="range" min="0" max="255" id="slS" oninput="setPWM('strip',this.value)" onpointerdown="drag=true" onpointerup="drag=false">
 <div class="lbl">Flashlight</div>
 <input type="range" min="0" max="255" id="slF" oninput="setPWM('flash',this.value)" onpointerdown="drag=true" onpointerup="drag=false">
</div>
<div class="card">
 <div class="stat-row">
  <span>LUX <span class="sv" id="lux">-</span></span>
  <span>SMOKE <span class="sv" id="smk">-</span></span>
  <span>PRESENT <span class="sv" id="prs">-</span></span>
  <span>🚬 <span class="sv" id="cig">0</span></span>
 </div>
</div>
<script>
var st={relays:[0,0,0,0],flash:0,strip:0},drag=false,ws,rt=1000;
function conn(){
 ws=new WebSocket('ws://'+location.host+'/ws');
 ws.onopen=()=>{document.getElementById('dot').className='dot ok';rt=1000};
 ws.onmessage=e=>upd(JSON.parse(e.data));
 ws.onclose=()=>{document.getElementById('dot').className='dot';setTimeout(conn,rt);rt=Math.min(rt*2,30000)};
}
function upd(s){
 st=s;
 for(var i=0;i<4;i++){var b=document.getElementById('b'+i);if(b)b.className='btn'+(s.relays[i]?' on':'')}
 if(!drag){document.getElementById('slS').value=s.strip;document.getElementById('slF').value=s.flash}
 document.getElementById('lux').textContent=(s.lux||0).toFixed(0);
 document.getElementById('smk').textContent=s.smoke||0;
 document.getElementById('prs').textContent=s.present?'YES':'NO';
 document.getElementById('cig').textContent=s.cigs||0;
 if(s.hour!==undefined)document.getElementById('clk').textContent=String(s.hour).padStart(2,'0')+':'+String(s.minute).padStart(2,'0');
}
function toggle(ch){ws.send(JSON.stringify({cmd:'relay',ch:ch,val:!st.relays[ch]}))}
function setPWM(t,v){ws.send(JSON.stringify({cmd:t,val:parseInt(v)}))}
setInterval(()=>{var d=new Date();if(document.getElementById('clk').textContent=='--:--')document.getElementById('clk').textContent=String(d.getHours()).padStart(2,'0')+':'+String(d.getMinutes()).padStart(2,'0')},1000);
conn();
</script>
</body></html>
)rawhtml";

static AsyncWebServer gHttpServer(80);
static AsyncWebSocket gWs("/ws");

static void ws_onEvent(AsyncWebSocket *, AsyncWebSocketClient *,
                       AwsEventType type, void *arg, uint8_t *data,
                       size_t len) {
  if (type == WS_EVT_DATA) {
    AwsFrameInfo *info = (AwsFrameInfo *)arg;
    if (info->opcode == WS_TEXT) {
      data[len] = 0;
      handleCommand(String((char *)data));
    }
  }
}

static uint32_t lastWsMs = 0;

static void webserver_init() {
  gWs.onEvent(ws_onEvent);
  gHttpServer.addHandler(&gWs);

  gHttpServer.on("/", HTTP_GET, [](AsyncWebServerRequest *req) {
    req->send(200, "text/html", DASHBOARD_HTML);
  });
  gHttpServer.on("/api/state", HTTP_GET, [](AsyncWebServerRequest *req) {
    req->send(200, "application/json", buildStateJson());
  });
  gHttpServer.on("/api/ping", HTTP_GET, [](AsyncWebServerRequest *req) {
    req->send(200, "application/json",
              String("{\"alive\":true,\"uptime\":") + String(millis() / 1000) +
                  "}");
  });
  gHttpServer.on(
      "/api/cmd", HTTP_POST, [](AsyncWebServerRequest *req) {}, nullptr,
      [](AsyncWebServerRequest *req, uint8_t *data, size_t len, size_t,
         size_t) {
        String body;
        for (size_t i = 0; i < len; i++)
          body += (char)data[i];
        handleCommand(body);
        req->send(200, "application/json", "{\"ok\":true}");
      });
  gHttpServer.begin();
  Serial.println("[HTTP] Started: http://shreyansh.local");
}

static void webserver_tick() {
  gWs.cleanupClients();
  // Broadcast every 1000 ms — reduced from 500 ms to ease heap pressure
  if (gWs.count() > 0 && millis() - lastWsMs > 1000) {
    lastWsMs = millis();
    gWs.textAll(buildStateJson());
  }
}

// ─────────────────────────────────────────────
//  SECTION 14 — OTA
// ─────────────────────────────────────────────
static void ota_init() {
  ArduinoOTA.setHostname("openclaw-esp32");
  ArduinoOTA.setPassword("openclaw-ota-2024");

  ArduinoOTA.onStart([]() { Serial.println("[OTA] Starting update..."); });
  ArduinoOTA.onEnd([]() { Serial.println("\n[OTA] Done — rebooting"); });
  ArduinoOTA.onProgress([](unsigned int p, unsigned int t) {
    Serial.printf("[OTA] %u%%\r", (p * 100) / t);
    digitalWrite(PIN_STATUS_LED, (p / 5000) % 2);
  });
  ArduinoOTA.onError(
      [](ota_error_t e) { Serial.printf("[OTA] Error %u\n", e); });
  ArduinoOTA.begin();
  Serial.println("[OTA] Ready");
}

// ─────────────────────────────────────────────
//  SECTION 15 — WIFI
// ─────────────────────────────────────────────
static void wifi_connect() {
  WiFi.mode(WIFI_STA);
  WiFi.setHostname("openclaw-esp32");
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  Serial.printf("[WiFi] Connecting to %s", WIFI_SSID);

  // Non-blocking: poll with WDT resets so we never trip the watchdog
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 40) {
    esp_task_wdt_reset(); // keep watchdog happy during slow joins
    delay(500);
    Serial.print(".");
    attempts++;
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("[WiFi] IP: %s\n", WiFi.localIP().toString().c_str());
    if (MDNS.begin("shreyansh")) {
      MDNS.addService("http", "tcp", 80);
      Serial.println("[mDNS] shreyansh.local");
    }
    configTime(NTP_OFFSET_SEC, 0, NTP_SERVER);
  } else {
    Serial.println("[WiFi] Failed — will retry in loop");
  }
}

static uint32_t lastWifiCheckMs = 0;
static void wifi_tick() {
  if (millis() - lastWifiCheckMs < 10000)
    return;
  lastWifiCheckMs = millis();
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[WiFi] Lost — reconnecting");
    WiFi.reconnect();
  }
}

// ─────────────────────────────────────────────
//  SECTION 16 — FREERTOS SENSOR TASK (Core 0)
// ─────────────────────────────────────────────
static void sensorTask(void *) {
  vTaskDelay(pdMS_TO_TICKS(30000)); // MQ-2 warm-up
  for (;;) {
    // 32× oversampled ADC
    int32_t acc = 0;
    for (int i = 0; i < 32; i++) {
      acc += analogRead(PIN_MQ2_ANALOG);
      delayMicroseconds(100);
    }
    int mqRaw = acc / 32;
    bool mqDig = (bool)digitalRead(PIN_MQ2_DIGITAL);
    float lux = apds_getLux();
    uint16_t prox = apds_getProximity();
    bool radar = (bool)digitalRead(PIN_RADAR);

    portENTER_CRITICAL(&gSensorMux);
    gSensors.lux = lux;
    gSensors.prox = prox;
    gSensors.mqRaw = mqRaw;
    gSensors.mqAlarm = mqDig;
    gSensors.radar = radar;
    portEXIT_CRITICAL(&gSensorMux);

    smoke_update(mqRaw);

    static bool led = false;
    led = !led;
    digitalWrite(PIN_STATUS_LED, led);

    vTaskDelay(pdMS_TO_TICKS(1000));
  }
}

// ─────────────────────────────────────────────
//  SECTION 17 — SETUP
//
//  KEY FIX: WDT is armed AFTER all blocking setup calls complete.
//  Previously WDT was armed before wifi_connect() + mqtt TLS handshake,
//  causing abort() when those took > 30s together.
// ─────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  Serial.println("\n===========================");
  Serial.println("  OpenClaw — No BLE/MQTT");
  Serial.println("===========================\n");

  hw_initGPIO();
  apds_ok = apds_init();

  nvs_load();
  for (int i = 0; i < 4; i++)
    hw_setRelay(i, gNVS.r[i]);
  hw_fadeStrip(gNVS.strip, 2000);
  hw_fadeFlash(gNVS.flash, 2000);
  gMode = (gNVS.mode == "sleep") ? MODE_SLEEP : MODE_AWAKE;
  gSmoke.cigCount = gNVS.cigs;

  // Restore smoke calibration if saved
  prefs.begin("openclaw", true);
  float sb = prefs.getFloat("smk_base", 0);
  float st = prefs.getFloat("smk_thr", 0);
  prefs.end();
  if (sb > 0) {
    gSmoke.baseline = sb;
    gSmoke.threshold = st;
    gSmoke.phase = SMOKE_IDLE;
    Serial.printf("[Smoke] Restored: base=%.0f thr=%.0f\n", sb, st);
  }

  // WiFi blocks up to 20s — do this before arming WDT
  wifi_connect();
  if (WiFi.status() == WL_CONNECTED)
    ota_init();

  webserver_init();

  // Init fade channel references
  gFlashFade.channel = LEDC_CH_FLASH;
  gStripFade.channel = LEDC_CH_STRIP;

  xTaskCreatePinnedToCore(sensorTask, "sensors", 4096, nullptr, 1, nullptr, 0);

  // ── Arm WDT LAST — after all blocking init is done ──
  esp_task_wdt_init(WDT_TIMEOUT_MS / 1000, true); // IDF 4.x: (seconds, panic)
  esp_task_wdt_add(NULL); // watch main loop task only

  Serial.println("\n[BOOT] All systems nominal.");
  Serial.printf("[INFO] Dashboard  : http://shreyansh.local\n");
  Serial.printf("[INFO] State JSON : GET  http://%s/api/state\n",
                WiFi.localIP().toString().c_str());
  Serial.printf("[INFO] Command    : POST http://%s/api/cmd\n",
                WiFi.localIP().toString().c_str());
  Serial.printf(
      "[INFO] OTA        : pio run -t upload --upload-port shreyansh.local\n");
}

// ─────────────────────────────────────────────
//  SECTION 18 — LOOP
// ─────────────────────────────────────────────
void loop() {
  esp_task_wdt_reset();
  ArduinoOTA.handle(); // MUST be first
  wifi_tick();
  webserver_tick();
  hw_processFades();
  automation_tick();
  delay(10);
}

/*
 * ─────────────────────────────────────────────────────────────────
 *  PYTHON INTEGRATION (local HTTP — no broker needed)
 * ─────────────────────────────────────────────────────────────────
 *
 *  import requests
 *  BASE = "http://shreyansh.local"
 *
 *  # Read full state
 *  state = requests.get(f"{BASE}/api/state").json()
 *
 *  # Toggle relay
 *  requests.post(f"{BASE}/api/cmd", json={"cmd":"relay","ch":0,"val":True})
 *
 *  # Set strip brightness
 *  requests.post(f"{BASE}/api/cmd", json={"cmd":"strip","val":180})
 *
 *  # Sleep mode
 *  requests.post(f"{BASE}/api/cmd", json={"cmd":"mode","val":"sleep"})
 *
 * ─────────────────────────────────────────────────────────────────
 *  OTA FLASH
 * ─────────────────────────────────────────────────────────────────
 *
 *  platformio.ini:
 *    upload_protocol = espota
 *    upload_port     = shreyansh.local
 *    upload_flags    = --auth=openclaw-ota-2024
 *
 *  Then: pio run -t upload
 * ─────────────────────────────────────────────────────────────────
 */
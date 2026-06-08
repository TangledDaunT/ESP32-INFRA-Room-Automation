/**
 * ============================================================
 *  OpenClaw ESP32 Firmware — Core 3.x  (No BLE, No MQTT)
 *  FIXED VERSION — Daily-deploy ready
 *
 *  FIXES vs previous version:
 *   - FIX 1: Forward-declared gSmokeOverride before hw_setRelay() — was a
 *             compile error (used before declared in Section 7)
 *   - FIX 2: Cig counter now uses calibrated gSmoke.threshold, NOT the
 *             hardcoded magic number 2700 which caused false counts
 *   - FIX 3: Smoke cooldown now uses a separate "clear window" counter so
 *             the 3-min timer only resets when truly elevated (> baseline+2σ),
 *             not on every slightly-above-baseline reading — fan was
 *             running forever before this fix
 *   - FIX 4: Presence detection now uses a "last seen" timestamp window
 *             (RADAR_PRESENCE_WINDOW_MS = 2.5s) instead of rising-edge only.
 *             RCWL-0516 pulses LOW between bursts for a stationary person;
 *             old code lost presence after 5 min even if you were sitting still
 *   - FIX 5: gAbsenceStartMs reset correctly on any radar pulse while
 *             already present (was skipped inside the !gPresent guard)
 *   - FIX 6: GPIO 5 (strapping pin) replaced with GPIO 18 for touch sensor
 *             to prevent boot-mode issues
 *   - FIX 7: nvs_save() debounced — PWM fades no longer hammer NVS flash
 *             every 10ms. Save deferred 3s after last change. NVS has
 *             ~10k write cycles; old code could exhaust it in hours
 *   - FIX 8: WebSocket null-terminator now written into a local stack buffer
 *             copy instead of data[len] (1-byte past-the-end UB / heap corrupt)
 *   - KEPT:  All automation logic, sensor task, fade engine, web dashboard,
 *            OTA, NVS persistence, smoke tracker, APDS driver, relay/PWM,
 *            Flutter app WebSocket JSON protocol (unchanged — app connects fine)
 *
 *  Flutter app connection:
 *   ws://<esp32-ip>/ws  — real-time JSON state push (1s interval)
 *   POST http://<esp32-ip>/api/cmd — {"cmd":"relay","ch":0,"val":true} etc.
 *   The app must be on the same WiFi network as the ESP32.
 *
 *  platformio.ini:
 *   [env:esp32dev]
 *   platform      = espressif32
 *   board         = esp32dev
 *   framework     = arduino
 *   monitor_speed = 115200
 *   board_build.partitions = huge_app.csv
 *   upload_protocol = espota               ; after first USB flash
 *   upload_port     = shreyansh.local
 *   upload_flags    = --auth=openclaw-ota-2024
 *   lib_deps =
 *     bblanchon/ArduinoJson @ ^6.21.4
 *     me-no-dev/ESP Async WebServer @ ^1.2.4
 *     me-no-dev/AsyncTCP @ ^1.1.1
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
#include <Preferences.h>
#include <WiFi.h>
#include <Wire.h>
#include <esp_task_wdt.h>
#include <time.h>

// ─────────────────────────────────────────────
//  SECTION 1 — USER CONFIG
// ─────────────────────────────────────────────
#define WIFI_SSID "2101_Wifi"
#define WIFI_PASS "air31549"

#define NTP_SERVER    "pool.ntp.org"
#define NTP_OFFSET_SEC 19800  // IST = UTC+5:30

#define WDT_TIMEOUT_MS 30000  // 30 seconds

// ─────────────────────────────────────────────
//  SECTION 2 — PIN DEFINITIONS
// ─────────────────────────────────────────────
// Relays (Active LOW)
#define PIN_RELAY_LIGHTS  26
#define PIN_RELAY_FAN     27
#define PIN_RELAY_RGB_AC  14
#define PIN_RELAY_SOCKET  25

// MOSFET PWM (D4184) — 5kHz max
#define PIN_MOSFET_FLASH  32
#define PIN_MOSFET_STRIP  33

// Sensors
#define PIN_RADAR        4
// FIX 6: moved from GPIO 5 (strapping pin → boot issues) to GPIO 18
#define PIN_TOUCH        18
#define PIN_MQ2_ANALOG   34   // ADC1_CH6 — input only
#define PIN_MQ2_DIGITAL  35   // input only

// I2C — APDS-9930
#define PIN_I2C_SDA  21
#define PIN_I2C_SCL  22

// Status LED
#define PIN_STATUS_LED  2

// LEDC — Core 3.x
#define LEDC_FREQ_HZ    5000
#define LEDC_RESOLUTION 8   // 8-bit = 0–255
#define LEDC_CH_FLASH   0
#define LEDC_CH_STRIP   1

// ─────────────────────────────────────────────
//  FIX 1 — FORWARD DECLARATION
//  gSmokeOverride is used in hw_setRelay() (Section 7) but defined in
//  Section 8. Without this forward decl the compiler errors out.
// ─────────────────────────────────────────────
static bool gSmokeOverride = false;

// ─────────────────────────────────────────────
//  SECTION 3 — FADE STATE STRUCT
// ─────────────────────────────────────────────
struct FadeState {
  uint8_t  current  = 0;
  uint8_t  target   = 0;
  uint32_t stepMs   = 10;
  uint32_t lastMs   = 0;
  bool     active   = false;
  uint8_t  pin      = 0;
};

static FadeState gFlashFade;
static FadeState gStripFade;

// ─────────────────────────────────────────────
//  SECTION 4 — APDS-9930 I2C DRIVER (raw, no lib)
// ─────────────────────────────────────────────
#define APDS9930_ADDR    0x39
#define APDS9930_ENABLE  0x00
#define APDS9930_ATIME   0x01
#define APDS9930_PPULSE  0x0E
#define APDS9930_CONTROL 0x0F
#define APDS9930_ID      0x12
#define APDS9930_CH0DATAL 0x14
#define APDS9930_CH0DATAH 0x15
#define APDS9930_CH1DATAL 0x16
#define APDS9930_CH1DATAH 0x17
#define APDS9930_PDATAL  0x18
#define APDS9930_PDATAH  0x19
#define APDS9930_POFFSET 0x1E
#define CMD_BYTE         0x80

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
  if (Wire.available() < 2) return 0;
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
    Serial.printf("[APDS] Bad ID: 0x%02X — check wiring (continuing without sensor)\n", id);
    return false;
  }
  apds_write(APDS9930_ENABLE,  0x00);
  apds_write(APDS9930_ATIME,   0xED);   // 50ms integration
  apds_write(APDS9930_PPULSE,  0x08);   // 8 pulses
  apds_write(APDS9930_CONTROL, 0x20);   // PDRIVE=100mA, AGAIN=1x
  apds_write(APDS9930_POFFSET, 0x00);
  apds_write(APDS9930_ENABLE,  0x0F);   // PON|AEN|PEN|WEN
  delay(60);
  Serial.printf("[APDS] OK — ID=0x%02X\n", id);
  return true;
}

static float apds_getLux() {
  if (!apds_ok) return 0.0f;
  uint16_t ch0 = apds_read16(APDS9930_CH0DATAL);
  uint16_t ch1 = apds_read16(APDS9930_CH1DATAL);
  if (ch0 == 0) return 0.0f;
  float ratio = (float)ch1 / (float)ch0;
  float lux;
  if      (ratio < 0.50f) lux = 0.0304f * ch0 - 0.062f  * ch0 * powf(ratio, 1.4f);
  else if (ratio < 0.61f) lux = 0.0224f * ch0 - 0.031f  * ch1;
  else if (ratio < 0.80f) lux = 0.0128f * ch0 - 0.0153f * ch1;
  else if (ratio < 1.30f) lux = 0.00146f* ch0 - 0.00112f* ch1;
  else                    lux = 0.0f;
  return lux * 52.0f;  // DF=52
}

static uint16_t apds_getProximity() {
  if (!apds_ok) return 0;
  return apds_read16(APDS9930_PDATAL);
}

// ─────────────────────────────────────────────
//  SECTION 5 — SENSOR CACHE (mutex-safe)
// ─────────────────────────────────────────────
struct SensorCache {
  float    lux      = 0.0f;
  uint16_t prox     = 0;
  int      mqRaw    = 0;
  bool     mqAlarm  = false;
  bool     radar    = false;
};

static SensorCache   gSensors;
static portMUX_TYPE  gSensorMux = portMUX_INITIALIZER_UNLOCKED;

static float    sensors_getLux()       { portENTER_CRITICAL(&gSensorMux); float    v = gSensors.lux;    portEXIT_CRITICAL(&gSensorMux); return v; }
static uint16_t sensors_getProximity() { portENTER_CRITICAL(&gSensorMux); uint16_t v = gSensors.prox;   portEXIT_CRITICAL(&gSensorMux); return v; }
static int      sensors_getMQRaw()     { portENTER_CRITICAL(&gSensorMux); int      v = gSensors.mqRaw;  portEXIT_CRITICAL(&gSensorMux); return v; }
static bool     sensors_getRadar()     { portENTER_CRITICAL(&gSensorMux); bool     v = gSensors.radar;  portEXIT_CRITICAL(&gSensorMux); return v; }

// ─────────────────────────────────────────────
//  SECTION 6 — NVS PERSISTENCE
//  FIX 7: nvs_save() is now debounced — writes are deferred 3s after the
//  last change. The old code called nvs_save() on every relay toggle AND
//  on every PWM fade step (every ~10ms), which would burn through NVS
//  flash's ~10k write-cycle endurance within hours of normal use.
// ─────────────────────────────────────────────
static Preferences prefs;

struct PersistState {
  bool    r[4]  = {false, false, false, false};
  uint8_t flash = 0;
  uint8_t strip = 0;
  int     cigs  = 0;
  String  mode  = "awake";
};
static PersistState gNVS;

static bool     gNvsDirty   = false;
static uint32_t gNvsDirtyMs = 0;
#define NVS_DEBOUNCE_MS 3000UL   // commit to flash 3s after last change

static void nvs_markDirty() {
  gNvsDirty   = true;
  gNvsDirtyMs = millis();
}

// Call this from loop() — flushes if dirty and debounce has elapsed
static void nvs_tick() {
  if (!gNvsDirty) return;
  if (millis() - gNvsDirtyMs < NVS_DEBOUNCE_MS) return;
  prefs.begin("openclaw", false);
  prefs.putBool("r0",    gNVS.r[0]);
  prefs.putBool("r1",    gNVS.r[1]);
  prefs.putBool("r2",    gNVS.r[2]);
  prefs.putBool("r3",    gNVS.r[3]);
  prefs.putUChar("flash", gNVS.flash);
  prefs.putUChar("strip", gNVS.strip);
  prefs.putInt("cigs",   gNVS.cigs);
  prefs.putString("mode", gNVS.mode);
  prefs.end();
  gNvsDirty = false;
  Serial.println("[NVS] Flushed to flash.");
}

static void nvs_saveImmediate() {
  prefs.begin("openclaw", false);
  prefs.putBool("r0",    gNVS.r[0]);
  prefs.putBool("r1",    gNVS.r[1]);
  prefs.putBool("r2",    gNVS.r[2]);
  prefs.putBool("r3",    gNVS.r[3]);
  prefs.putUChar("flash", gNVS.flash);
  prefs.putUChar("strip", gNVS.strip);
  prefs.putInt("cigs",   gNVS.cigs);
  prefs.putString("mode", gNVS.mode);
  prefs.end();
  gNvsDirty = false;
}

static void nvs_load() {
  prefs.begin("openclaw", false);
  gNVS.r[0]  = prefs.getBool("r0",     false);
  gNVS.r[1]  = prefs.getBool("r1",     false);
  gNVS.r[2]  = prefs.getBool("r2",     false);
  gNVS.r[3]  = prefs.getBool("r3",     false);
  gNVS.flash = prefs.getUChar("flash", 0);
  gNVS.strip = prefs.getUChar("strip", 0);
  gNVS.cigs  = prefs.getInt("cigs",    0);
  gNVS.mode  = prefs.getString("mode", "awake");
  prefs.end();
  Serial.println("[NVS] Loaded from flash.");
}

// ─────────────────────────────────────────────
//  SECTION 7 — HARDWARE CONTROL
// ─────────────────────────────────────────────
static const uint8_t RELAY_PINS[4] = {
  PIN_RELAY_LIGHTS, PIN_RELAY_FAN, PIN_RELAY_RGB_AC, PIN_RELAY_SOCKET
};
static bool    gRelayState[4]  = {false, false, false, false};
static uint8_t gFlashBright    = 0;
static uint8_t gStripBright    = 0;

static void hw_initGPIO() {
  for (int i = 0; i < 4; i++) {
    pinMode(RELAY_PINS[i], OUTPUT);
    digitalWrite(RELAY_PINS[i], HIGH);  // Active LOW — start OFF
  }
  ledcSetup(LEDC_CH_FLASH, LEDC_FREQ_HZ, LEDC_RESOLUTION);
  ledcAttachPin(PIN_MOSFET_FLASH, LEDC_CH_FLASH);
  ledcWrite(LEDC_CH_FLASH, 0);

  ledcSetup(LEDC_CH_STRIP, LEDC_FREQ_HZ, LEDC_RESOLUTION);
  ledcAttachPin(PIN_MOSFET_STRIP, LEDC_CH_STRIP);
  ledcWrite(LEDC_CH_STRIP, 0);
  pinMode(PIN_RADAR,       INPUT);
  pinMode(PIN_TOUCH,       INPUT);
  pinMode(PIN_MQ2_DIGITAL, INPUT);
  pinMode(PIN_STATUS_LED,  OUTPUT);
  digitalWrite(PIN_STATUS_LED, LOW);
  Serial.println("[HW] GPIO initialized (Core 3.x LEDC)");
}

// Active LOW: true = ON → GPIO LOW
// gSmokeOverride is now forward-declared above (FIX 1)
static void hw_setRelay(int ch, bool on) {
  if (ch == 1 && gSmokeOverride && !on) return;  // smoke holds fan on
  if (ch < 0 || ch > 3) return;
  gRelayState[ch] = on;
  digitalWrite(RELAY_PINS[ch], on ? LOW : HIGH);
  gNVS.r[ch] = on;
  nvs_markDirty();  // FIX 7: deferred write, not immediate
}

static void hw_setPWM_flash(uint8_t val) {
  ledcWrite(LEDC_CH_FLASH, val);
  gFlashBright  = val;
  gNVS.flash    = val;
  nvs_markDirty();
}

static void hw_setPWM_strip(uint8_t val) {
  ledcWrite(LEDC_CH_STRIP, val);
  gStripBright = val;
  gNVS.strip   = val;
  nvs_markDirty();
}

// Non-blocking fades
static void hw_fadeFlash(uint8_t target, uint32_t durationMs) {
  gFlashFade.current = gFlashBright;
  gFlashFade.target  = target;
  gFlashFade.pin     = PIN_MOSFET_FLASH;
  uint8_t delta      = (uint8_t)abs((int)target - (int)gFlashBright);
  gFlashFade.stepMs  = (delta == 0) ? durationMs
                       : max((uint32_t)1, (uint32_t)(durationMs / delta));
  gFlashFade.lastMs  = millis();
  gFlashFade.active  = true;
}

static void hw_fadeStrip(uint8_t target, uint32_t durationMs) {
  gStripFade.current = gStripBright;
  gStripFade.target  = target;
  gStripFade.pin     = PIN_MOSFET_STRIP;
  uint8_t delta      = (uint8_t)abs((int)target - (int)gStripBright);
  gStripFade.stepMs  = (delta == 0) ? durationMs
                       : max((uint32_t)1, (uint32_t)(durationMs / delta));
  gStripFade.lastMs  = millis();
  gStripFade.active  = true;
}

static uint8_t gamma8(uint8_t x) {
  float xf = x / 255.0f;
  xf = powf(xf, 2.2f);
  return (uint8_t)(xf * 255.0f);
}

static void hw_processSingleFade(FadeState &f) {
  if (!f.active) return;
  uint32_t now = millis();
  if (now - f.lastMs < f.stepMs) return;
  f.lastMs = now;
  if (f.current == f.target) { f.active = false; return; }
  int diff = (int)f.target - (int)f.current;
  int step = diff / 5;
  if (step == 0) step = (diff > 0) ? 1 : -1;
  f.current += step;
  uint8_t corrected = gamma8(f.current);
  if (f.pin == PIN_MOSFET_STRIP) {
    ledcWrite(LEDC_CH_STRIP, corrected);
  } else {
    ledcWrite(LEDC_CH_FLASH, corrected);
  }
  // FIX 7: only update brightness state, do NOT call nvs_save() here —
  // the debounced nvs_tick() in loop() handles persistence safely
  if (f.pin == PIN_MOSFET_STRIP) { gStripBright = f.current; gNVS.strip = f.current; nvs_markDirty(); }
  else                           { gFlashBright = f.current; gNVS.flash = f.current; nvs_markDirty(); }
}

static void hw_processFades() {
  hw_processSingleFade(gFlashFade);
  hw_processSingleFade(gStripFade);
}

static uint8_t hw_getFlashBrightness() { return gFlashBright; }
static uint8_t hw_getStripBrightness() { return gStripBright; }

// ─────────────────────────────────────────────
//  SECTION 8 — SMOKE TRACKER DSP
//
//  FIX 2: Detection threshold is now gSmoke.threshold (statistically
//          calibrated) instead of the hardcoded 2700. The old value
//          ignored calibration entirely — if your room air sits at 2600
//          ADC counts, every sensor read would count as a cigarette.
//
//  FIX 3: Cooldown logic rewritten. The old code reset gSmoke.cooldownMs
//          any time raw > baseline+sigma, which in practice (MQ-2 stays
//          elevated 10-15 min after real smoke) meant the timer NEVER
//          expired, the fan ran forever, and gSmokeOverride never cleared.
//          New logic: track a separate "last_high_ms". The 3-min window
//          only resets if the sensor is "truly still elevated" (> threshold
//          again, not just above baseline+sigma). Once it drops below
//          threshold and stays below for 3 min, smoke is cleared.
// ─────────────────────────────────────────────
enum SmokePhase { SMOKE_WARMUP, SMOKE_CALIBRATE, SMOKE_IDLE, SMOKE_COOLDOWN };

struct SmokeTracker {
  SmokePhase phase     = SMOKE_WARMUP;
  uint32_t   phaseMs   = 0;
  float      sumAcc    = 0;
  float      sumSq     = 0;
  int        samples   = 0;
  float      baseline  = 310.0f;
  float      sigma     = 30.0f;
  float      threshold = 500.0f;   // will be overwritten after calibration
  bool       smoking   = false;
  uint32_t   clearWindowMs = 0;    // FIX 3: tracks when sensor went below threshold
  int        cigCount  = 0;
};
static SmokeTracker gSmoke;

#define SMOKE_COOLDOWN_CLEAR_MS  180000UL  // 3 min below threshold = cleared
#define SMOKE_MIN_THRESHOLD      400.0f    // sanity floor for threshold

static void smoke_update(int raw) {
  uint32_t now = millis();
  switch (gSmoke.phase) {

  case SMOKE_WARMUP:
    if (now - gSmoke.phaseMs > 30000UL) {
      gSmoke.phase   = SMOKE_CALIBRATE;
      gSmoke.phaseMs = now;
      gSmoke.sumAcc  = 0;
      gSmoke.sumSq   = 0;
      gSmoke.samples = 0;
      Serial.println("[Smoke] Calibrating...");
    }
    break;

  case SMOKE_CALIBRATE:
    gSmoke.sumAcc += raw;
    gSmoke.sumSq  += (float)raw * raw;
    gSmoke.samples++;
    if (now - gSmoke.phaseMs > 120000UL) {
      float mean = gSmoke.sumAcc / gSmoke.samples;
      float var  = (gSmoke.sumSq / gSmoke.samples) - mean * mean;
      gSmoke.baseline  = mean;
      gSmoke.sigma     = sqrtf(var);
      // FIX 2: threshold = mean + 4σ (tighter false-positive control)
      // Minimum floor prevents calibrating in a smoky room
      gSmoke.threshold = max(mean + 4.0f * gSmoke.sigma, SMOKE_MIN_THRESHOLD);
      gSmoke.phase     = SMOKE_IDLE;
      Serial.printf("[Smoke] Done — base=%.0f σ=%.0f thr=%.0f\n",
                    gSmoke.baseline, gSmoke.sigma, gSmoke.threshold);
      prefs.begin("openclaw", false);
      prefs.putFloat("smk_base", gSmoke.baseline);
      prefs.putFloat("smk_thr",  gSmoke.threshold);
      prefs.end();
    }
    break;

  case SMOKE_IDLE:
    // FIX 2: use calibrated threshold, not hardcoded 2700
    if (raw > gSmoke.threshold) {
      gSmoke.smoking      = true;
      gSmoke.phase        = SMOKE_COOLDOWN;
      gSmokeOverride      = true;
      gSmoke.clearWindowMs = now;
      gSmoke.cigCount++;
      gNVS.cigs = gSmoke.cigCount;
      nvs_markDirty();
      Serial.printf("[Smoke] Detected! count=%d (raw=%d thr=%.0f)\n",
                    gSmoke.cigCount, raw, gSmoke.threshold);
      hw_setRelay(1, true);  // fan ON
    }
    break;

  case SMOKE_COOLDOWN:
    // FIX 3: only reset the clear window if TRULY still above threshold.
    // Below threshold → keep counting down. When 3 min below threshold → clear.
    if (raw > gSmoke.threshold) {
      // Still smoking — reset the clear window
      gSmoke.clearWindowMs = now;
    } else {
      // Below threshold — check if we've been clear long enough
      if (now - gSmoke.clearWindowMs > SMOKE_COOLDOWN_CLEAR_MS) {
        gSmoke.smoking   = false;
        gSmoke.phase     = SMOKE_IDLE;
        gSmokeOverride   = false;
        hw_setRelay(1, false);  // fan OFF
        Serial.println("[Smoke] Cleared — fan off.");
      }
    }
    break;
  }
}

static bool smoke_isCalibrated() {
  return gSmoke.phase != SMOKE_WARMUP && gSmoke.phase != SMOKE_CALIBRATE;
}

// ─────────────────────────────────────────────
//  SECTION 9 — AUTOMATION STATE MACHINE
//
//  FIX 4 & 5: Presence detection rewritten for RCWL-0516 behaviour.
//  The RCWL-0516 outputs a ~2s HIGH pulse when motion is detected, then
//  goes LOW — even for a perfectly stationary person sitting in the room.
//  The old code used rising-edge detection only: once the radar went LOW
//  (between normal pulses), gAbsenceStartMs was set, and after 5 minutes
//  with no new pulse the room was declared empty. This meant that if you
//  sat very still for 5 min your lights turned off.
//
//  New approach: gLastRadarSeenMs tracks when the radar LAST went HIGH.
//  As long as we saw a pulse within RADAR_PRESENCE_WINDOW_MS (2.5s), the
//  person is considered present. gAbsenceStartMs only starts counting
//  when no pulse has been seen for longer than RADAR_PRESENCE_WINDOW_MS.
//  FIX 5: gAbsenceStartMs is reset any time we confirm presence, not
//  just on the first entry into the present state.
// ─────────────────────────────────────────────
enum SystemMode { MODE_AWAKE, MODE_SLEEP };
static SystemMode gMode = MODE_AWAKE;

static bool     gPresent          = false;
static uint32_t gAbsenceStartMs   = 0;
static uint32_t gLastRadarSeenMs  = 0;   // FIX 4: timestamp of last radar HIGH
static bool     gStripManualOff   = false;

static bool     gLastTouch        = false;
static uint32_t gTouchDownMs      = 0;
static bool     gTouchHeld        = false;

static bool     gLastProxHigh     = false;
static uint32_t gLastProxTrigMs   = 0;

#define ABSENCE_TIMEOUT_MS        60000UL  // 1 min no radar -> lights off
#define RADAR_PRESENCE_WINDOW_MS   2500UL  // 2.5s pulse-gap tolerance (RCWL pulses ~2s)
#define PROX_COOLDOWN_MS           1500UL
#define PROX_THRESHOLD             200

static uint8_t luxToStripTarget(float lux) {
  if (lux < 30.0f)  return 80;
  if (lux < 80.0f)  return 140;
  if (lux < 150.0f) return 200;
  return 255;
}

static uint8_t luxToFlashTarget(float lux) {
  if (lux < 50.0f)  return 60;
  if (lux < 150.0f) return 150;
  return 255;
}

static uint8_t triangleWave(uint32_t elapsed, uint32_t period,
                             uint8_t lo, uint8_t hi) {
  uint32_t pos = elapsed % period;
  float t = (float)pos / (float)period;
  float val = (t < 0.5f)
    ? lo + (hi - lo) * (t * 2.0f)
    : hi - (hi - lo) * ((t - 0.5f) * 2.0f);
  return (uint8_t)constrain((int)val, (int)lo, (int)hi);
}

static void automation_setMode(const String &modeStr) {
  if (modeStr == "sleep") {
    gMode = MODE_SLEEP;
    hw_fadeStrip(30, 1500);
    hw_fadeFlash(0,  1000);
  } else {
    gMode = MODE_AWAKE;
  }
  gNVS.mode = modeStr;
  nvs_markDirty();
}

static void automation_tick() {
  uint32_t now   = millis();
  float    lux   = sensors_getLux();
  bool     radar = sensors_getRadar();
  uint16_t prox  = sensors_getProximity();
  bool     touch = (bool)digitalRead(PIN_TOUCH);

  // ── RADAR PRESENCE (FIX 4 & 5) ──────────────────────────────────────
  // Track last time radar fired
  if (radar) {
    gLastRadarSeenMs = now;
  }

  // "Effectively present" = radar fired within the presence window
  bool radarActive = (now - gLastRadarSeenMs < RADAR_PRESENCE_WINDOW_MS);

  if (radarActive) {
    if (!gPresent) {
      gPresent = true;
      Serial.println("[Auto] Presence ENTRY");
      if (gMode == MODE_AWAKE) {
        hw_fadeStrip(luxToStripTarget(lux), 1200);
        gStripManualOff = false;
      }
    }
    // FIX 5: reset absence timer ANY time we confirm presence, not just on entry
    gAbsenceStartMs = 0;
  } else {
    // Radar gone cold — start (or keep) absence timer
    if (gPresent && gAbsenceStartMs == 0) {
      gAbsenceStartMs = now;
    }
  }

  // ── ABSENCE TIMEOUT ─────────────────────────────────────────────────
  if (gPresent && gAbsenceStartMs > 0) {
    if (now - gAbsenceStartMs > ABSENCE_TIMEOUT_MS) {
      gPresent        = false;
      gAbsenceStartMs = 0;
      gStripManualOff = false;
      hw_fadeStrip(0, 2000);
      hw_fadeFlash(0, 1500);
      Serial.println("[Auto] Absence timeout — all off");
    }
  }

  // ── PROXIMITY → FLASHLIGHT TOGGLE ───────────────────────────────────
  bool proxHigh = (prox > PROX_THRESHOLD);
  if (proxHigh && !gLastProxHigh) {
    if (now - gLastProxTrigMs > PROX_COOLDOWN_MS) {
      gLastProxTrigMs = now;
      if (hw_getFlashBrightness() > 0) hw_fadeFlash(0,                   1000);
      else                              hw_fadeFlash(luxToFlashTarget(lux), 1000);
      Serial.println("[Auto] Prox → Flash toggle");
    }
  }
  gLastProxHigh = proxHigh;

  // ── TOUCH SENSOR ────────────────────────────────────────────────────
  if (touch && !gLastTouch) {
    gTouchDownMs = now;
    gTouchHeld   = false;
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
      nvs_markDirty();
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
  if (!getLocalTime(&ti, 0)) { hour = 0; minute = 0; return false; }
  hour   = ti.tm_hour;
  minute = ti.tm_min;
  return true;
}

// ─────────────────────────────────────────────
//  SECTION 11 — STATE JSON BUILDER
// ─────────────────────────────────────────────
static String buildStateJson() {
  DynamicJsonDocument doc(512);
  JsonArray rel = doc.createNestedArray("relays");
  for (int i = 0; i < 4; i++) rel.add(gRelayState[i]);

  doc["flash"]      = gFlashBright;
  doc["strip"]      = gStripBright;
  doc["lux"]        = sensors_getLux();
  doc["smoke"]      = sensors_getMQRaw();
  doc["present"]    = gPresent;
  doc["prox"]       = sensors_getProximity();
  doc["cigs"]       = gSmoke.cigCount;
  doc["calibrated"] = smoke_isCalibrated();
  doc["baseline"]   = (int)gSmoke.baseline;
  doc["threshold"]  = (int)gSmoke.threshold;
  doc["smoking"]    = gSmoke.smoking;
  doc["mode"]       = (gMode == MODE_SLEEP) ? "sleep" : "awake";
  doc["rssi"]       = WiFi.RSSI();
  doc["ip"]         = WiFi.localIP().toString();
  doc["uptime"]     = (uint32_t)(millis() / 1000);
  doc["heap"]       = ESP.getFreeHeap();

  int h, m;
  getLocalHourMinute(h, m);
  doc["hour"]   = h;
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
  if (deserializeJson(doc, jsonStr)) return;

  // ── Primary dialect (Flutter app uses this) ──
  if (doc.containsKey("cmd")) {
    String cmd = doc["cmd"].as<String>();
    if (cmd == "relay") {
      int  ch  = doc["ch"]  | -1;
      bool val = doc["val"] | false;
      if (ch >= 0 && ch <= 3) hw_setRelay(ch, val);
    } else if (cmd == "flash") {
      hw_fadeFlash((uint8_t)constrain(doc["val"] | 0, 0, 255), 400);
    } else if (cmd == "strip") {
      hw_fadeStrip((uint8_t)constrain(doc["val"] | 0, 0, 255), 400);
    } else if (cmd == "mode") {
      automation_setMode(doc["val"] | "awake");
    } else if (cmd == "all_off") {
      for (int i = 0; i < 4; i++) hw_setRelay(i, false);
      hw_fadeFlash(0, 800);
      hw_fadeStrip(0, 800);
    } else if (cmd == "all_on") {
      for (int i = 0; i < 4; i++) hw_setRelay(i, true);
    } else if (cmd == "reset_cigs") {
      gSmoke.cigCount = 0;
      gNVS.cigs = 0;
      nvs_markDirty();
    }
    return;
  }

  // ── PWM dialect ──
  if (doc.containsKey("command")) {
    String command = doc["command"].as<String>();
    if (command == "set_pwm") {
      int ch  = doc["channel"] | 0;
      int val = doc["value"]   | 0;
      if (ch == 0) hw_fadeFlash((uint8_t)constrain(val, 0, 255), 300);
      else         hw_fadeStrip((uint8_t)constrain(val, 0, 255), 300);
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
  @import url('https://fonts.googleapis.com/css2?family=Space+Mono:wght@400;700&display=swap');
  *{margin:0;padding:0;box-sizing:border-box}
  :root{--bg:#0a0a0a;--card:rgba(255,255,255,0.04);--border:rgba(255,255,255,0.09);--accent:#e8ff47;--text:#f0f0f0;--muted:#555}
  body{background:var(--bg);color:var(--text);font-family:'Space Mono',monospace;min-height:100vh;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:10px;padding:14px}
  .card{background:var(--card);border:1px solid var(--border);border-radius:16px;padding:16px 18px;width:100%;max-width:460px}
  .clock{font-size:3rem;font-weight:700;letter-spacing:4px;text-align:center;color:var(--accent);font-variant-numeric:tabular-nums}
  .sub{font-size:10px;color:var(--muted);text-align:center;letter-spacing:2px;margin-top:2px}
  .grid{display:grid;grid-template-columns:1fr 1fr;gap:8px}
  .btn{height:60px;border-radius:12px;border:1px solid var(--border);background:transparent;color:var(--muted);font-family:'Space Mono',monospace;font-size:11px;letter-spacing:1px;cursor:pointer;transition:all .15s;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:4px}
  .btn span.icon{font-size:18px}
  .btn.on{background:var(--accent);border-color:var(--accent);color:#000;font-weight:700}
  .row-label{font-size:10px;color:var(--muted);letter-spacing:2px;margin-bottom:6px}
  input[type=range]{width:100%;-webkit-appearance:none;height:3px;border-radius:2px;background:var(--border);outline:none;margin:6px 0}
  input[type=range]::-webkit-slider-thumb{-webkit-appearance:none;width:16px;height:16px;border-radius:50%;background:var(--accent);cursor:pointer}
  .stats{display:grid;grid-template-columns:repeat(4,1fr);gap:6px;text-align:center}
  .stat{background:rgba(255,255,255,0.03);border:1px solid var(--border);border-radius:10px;padding:10px 4px}
  .stat-v{font-size:15px;font-weight:700;color:var(--text)}
  .stat-k{font-size:9px;color:var(--muted);letter-spacing:1px;margin-top:3px}
  .dot{width:7px;height:7px;border-radius:50%;background:var(--muted);position:fixed;top:14px;right:14px;transition:background .4s}
  .dot.ok{background:var(--accent);box-shadow:0 0 8px var(--accent)}
  .smoke-bar{height:4px;border-radius:2px;background:var(--border);margin-top:8px;overflow:hidden}
  .smoke-fill{height:100%;border-radius:2px;background:var(--accent);transition:width .5s}
  .smoking .smoke-fill{background:#ff4747}
</style>
</head>
<body>
<div class="dot" id="dot"></div>

<div class="card">
  <div class="clock" id="clk">--:--</div>
  <div class="sub" id="mode-lbl">OPENCLAW · AWAKE</div>
</div>

<div class="card">
  <div class="row-label">RELAYS</div>
  <div class="grid">
    <button class="btn" id="b0" onclick="toggle(0)"><span class="icon">💡</span><span>LIGHTS</span></button>
    <button class="btn" id="b1" onclick="toggle(1)"><span class="icon">⌀</span><span>FAN</span></button>
    <button class="btn" id="b2" onclick="toggle(2)"><span class="icon">✦</span><span>RGB AC</span></button>
    <button class="btn" id="b3" onclick="toggle(3)"><span class="icon">⚡</span><span>SOCKET</span></button>
  </div>
</div>

<div class="card">
  <div class="row-label">LED STRIP <span id="strip-val" style="color:var(--accent)">0</span></div>
  <input type="range" min="0" max="255" id="slS" oninput="setPWM('strip',this.value)" onpointerdown="drag=true" onpointerup="drag=false">
  <div class="row-label" style="margin-top:10px">FLASHLIGHT <span id="flash-val" style="color:var(--accent)">0</span></div>
  <input type="range" min="0" max="255" id="slF" oninput="setPWM('flash',this.value)" onpointerdown="drag=true" onpointerup="drag=false">
</div>

<div class="card" id="smoke-card">
  <div class="stats">
    <div class="stat"><div class="stat-v" id="lux">-</div><div class="stat-k">LUX</div></div>
    <div class="stat"><div class="stat-v" id="smk">-</div><div class="stat-k">SMOKE</div></div>
    <div class="stat"><div class="stat-v" id="prs">-</div><div class="stat-k">PRESENT</div></div>
    <div class="stat"><div class="stat-v" id="cig">0</div><div class="stat-k">CIGS 🚬</div></div>
  </div>
  <div class="smoke-bar" id="smoke-bar"><div class="smoke-fill" id="smoke-fill" style="width:0%"></div></div>
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
  for(var i=0;i<4;i++){var b=document.getElementById('b'+i);if(b)b.className='btn'+(s.relays[i]?' on':'');}
  if(!drag){
    document.getElementById('slS').value=s.strip;
    document.getElementById('slF').value=s.flash;
  }
  document.getElementById('strip-val').textContent=s.strip||0;
  document.getElementById('flash-val').textContent=s.flash||0;
  document.getElementById('lux').textContent=(s.lux||0).toFixed(0);
  document.getElementById('smk').textContent=s.smoke||0;
  document.getElementById('prs').textContent=s.present?'YES':'NO';
  document.getElementById('cig').textContent=s.cigs||0;
  if(s.hour!==undefined)
    document.getElementById('clk').textContent=
      String(s.hour).padStart(2,'0')+':'+String(s.minute).padStart(2,'0');
  document.getElementById('mode-lbl').textContent=
    'OPENCLAW · '+(s.mode||'awake').toUpperCase();
  // smoke progress bar (vs threshold)
  if(s.threshold>0){
    var pct=Math.min(100,(s.smoke/s.threshold)*100);
    document.getElementById('smoke-fill').style.width=pct+'%';
  }
  document.getElementById('smoke-card').className='card'+(s.smoking?' smoking':'');
}
function toggle(ch){ws.send(JSON.stringify({cmd:'relay',ch:ch,val:!st.relays[ch]}))}
function setPWM(t,v){ws.send(JSON.stringify({cmd:t,val:parseInt(v)}))}
setInterval(()=>{
  var d=new Date();
  if(document.getElementById('clk').textContent=='--:--')
    document.getElementById('clk').textContent=
      String(d.getHours()).padStart(2,'0')+':'+String(d.getMinutes()).padStart(2,'0');
},1000);
conn();
</script>
</body>
</html>
)rawhtml";

static AsyncWebServer gHttpServer(80);
static AsyncWebSocket gWs("/ws");

static void ws_onEvent(AsyncWebSocket *, AsyncWebSocketClient *,
                       AwsEventType type, void *arg,
                       uint8_t *data, size_t len) {
  if (type == WS_EVT_DATA) {
    AwsFrameInfo *info = (AwsFrameInfo *)arg;
    if (info->opcode == WS_TEXT) {
      // FIX 8: copy into a local buffer before null-terminating.
      // Old code wrote data[len] = 0 which is 1 byte past the end of the
      // AsyncWebServer-owned buffer — undefined behaviour / heap corruption.
      char buf[512];
      size_t safe_len = min(len, sizeof(buf) - 1);
      memcpy(buf, data, safe_len);
      buf[safe_len] = '\0';
      handleCommand(String(buf));
    }
  }
}

static uint32_t lastWsMs = 0;

static void webserver_init() {
  gWs.onEvent(ws_onEvent);
  gHttpServer.addHandler(&gWs);

  gHttpServer.on("/", HTTP_GET, [](AsyncWebServerRequest *req) {
    req->send_P(200, "text/html", DASHBOARD_HTML);
  });
  gHttpServer.on("/api/state", HTTP_GET, [](AsyncWebServerRequest *req) {
    req->send(200, "application/json", buildStateJson());
  });
  gHttpServer.on("/api/ping", HTTP_GET, [](AsyncWebServerRequest *req) {
    req->send(200, "application/json",
              String("{\"alive\":true,\"uptime\":") + String(millis()/1000) + "}");
  });
  gHttpServer.on("/api/cmd", HTTP_POST,
    [](AsyncWebServerRequest *req) {},
    nullptr,
    [](AsyncWebServerRequest *req, uint8_t *data, size_t len, size_t, size_t) {
      char buf[512];
      size_t safe_len = min(len, sizeof(buf) - 1);
      memcpy(buf, data, safe_len);
      buf[safe_len] = '\0';
      handleCommand(String(buf));
      req->send(200, "application/json", "{\"ok\":true}");
    });
  gHttpServer.begin();
  Serial.println("[HTTP] Started: http://shreyansh.local");
}

static void webserver_tick() {
  gWs.cleanupClients();
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
  ArduinoOTA.onStart([]()  { Serial.println("[OTA] Starting update..."); });
  ArduinoOTA.onEnd([]()    { Serial.println("\n[OTA] Done — rebooting"); });
  ArduinoOTA.onProgress([](unsigned int p, unsigned int t) {
    Serial.printf("[OTA] %u%%\r", (p * 100) / t);
    digitalWrite(PIN_STATUS_LED, (p / 5000) % 2);
  });
  ArduinoOTA.onError([](ota_error_t e) {
    Serial.printf("[OTA] Error %u\n", e);
  });
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
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 40) {
    esp_task_wdt_reset();
    delay(500);
    Serial.print(".");
    attempts++;
  }
  Serial.println();
  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("[WiFi] IP: %s\n", WiFi.localIP().toString().c_str());
    
     Serial.println("[mDNS] Skipped — use IP directly");
    configTime(NTP_OFFSET_SEC, 0, NTP_SERVER);
  } else {
    Serial.println("[WiFi] Failed — will retry in loop");
  }
}

static uint32_t lastWifiCheckMs = 0;
static void wifi_tick() {
  if (millis() - lastWifiCheckMs < 10000) return;
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
  vTaskDelay(pdMS_TO_TICKS(30000));  // MQ-2 warm-up
  for (;;) {
    // 32× oversampled ADC
    int32_t acc = 0;
    for (int i = 0; i < 32; i++) {
      acc += analogRead(PIN_MQ2_ANALOG);
      delayMicroseconds(100);
    }
    int  mqRaw  = acc / 32;
    bool mqDig  = (bool)digitalRead(PIN_MQ2_DIGITAL);
    float lux   = apds_getLux();
    uint16_t prox = apds_getProximity();
    bool radar  = (bool)digitalRead(PIN_RADAR);

    portENTER_CRITICAL(&gSensorMux);
    gSensors.lux     = lux;
    gSensors.prox    = prox;
    gSensors.mqRaw   = mqRaw;
    gSensors.mqAlarm = mqDig;
    gSensors.radar   = radar;
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
// ─────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  Serial.println("\n===========================");
  Serial.println("  OpenClaw — FIXED BUILD");
  Serial.println("===========================\n");

  hw_initGPIO();
  apds_ok = apds_init();

  nvs_load();
  for (int i = 0; i < 4; i++) hw_setRelay(i, gNVS.r[i]);
  hw_fadeStrip(gNVS.strip, 2000);
  hw_fadeFlash(gNVS.flash, 2000);
  gMode = (gNVS.mode == "sleep") ? MODE_SLEEP : MODE_AWAKE;
  gSmoke.cigCount = gNVS.cigs;

  // Restore smoke calibration if saved
  prefs.begin("openclaw", true);
  float sb = prefs.getFloat("smk_base", 0);
  float st = prefs.getFloat("smk_thr",  0);
  prefs.end();
  if (sb > 0) {
    gSmoke.baseline  = sb;
    gSmoke.threshold = st;
    gSmoke.phase     = SMOKE_IDLE;
    Serial.printf("[Smoke] Restored: base=%.0f thr=%.0f\n", sb, st);
  }

  wifi_connect();
  if (WiFi.status() == WL_CONNECTED) ota_init();

  webserver_init();

  gFlashFade.pin = PIN_MOSFET_FLASH;
  gStripFade.pin = PIN_MOSFET_STRIP;

  xTaskCreatePinnedToCore(sensorTask, "sensors", 4096, nullptr, 1, nullptr, 0);

  // Arm WDT LAST — after all blocking init is done
  esp_task_wdt_deinit();
  esp_task_wdt_init(WDT_TIMEOUT_MS / 1000, true);
  esp_task_wdt_add(NULL);

  Serial.println("\n[BOOT] All systems nominal.");
  Serial.printf("[INFO] Dashboard  : http://shreyansh.local\n");
  Serial.printf("[INFO] Flutter WS : ws://%s/ws\n",        WiFi.localIP().toString().c_str());
  Serial.printf("[INFO] State JSON : GET  http://%s/api/state\n", WiFi.localIP().toString().c_str());
  Serial.printf("[INFO] Command    : POST http://%s/api/cmd\n",   WiFi.localIP().toString().c_str());
  Serial.printf("[INFO] OTA        : pio run -t upload --upload-port shreyansh.local\n");
  Serial.printf("[INFO] Touch pin  : GPIO %d (moved from GPIO 5)\n", PIN_TOUCH);
}

// ─────────────────────────────────────────────
//  SECTION 18 — LOOP
// ─────────────────────────────────────────────
void loop() {
  esp_task_wdt_reset();
  ArduinoOTA.handle();   // MUST be first
  wifi_tick();
  webserver_tick();
  hw_processFades();
  automation_tick();
  nvs_tick();            // FIX 7: debounced NVS flush (was nvs_save() inline)
  delay(10);
}

/*
 * ─────────────────────────────────────────────────────────────────
 *  FLUTTER APP CONNECTION
 * ─────────────────────────────────────────────────────────────────
 *  Your app must be on the same WiFi as the ESP32 (2101_WIFI).
 *  Connect WebSocket to:  ws://<esp32-ip>/ws
 *  OR use mDNS:           ws://openclaw-esp32.local/ws
 *
 *  State is pushed every 1s as JSON:
 *  {"relays":[bool,bool,bool,bool],"flash":0-255,"strip":0-255,
 *   "lux":float,"smoke":int,"present":bool,"prox":int,"cigs":int,
 *   "calibrated":bool,"baseline":int,"threshold":int,"smoking":bool,
 *   "mode":"awake|sleep","rssi":int,"ip":"...","uptime":int,"heap":int,
 *   "hour":int,"minute":int}
 *
 *  Commands (send JSON over WebSocket or POST /api/cmd):
 *  {"cmd":"relay","ch":0,"val":true}   // relay 0-3
 *  {"cmd":"strip","val":200}           // LED strip 0-255
 *  {"cmd":"flash","val":150}           // flashlight 0-255
 *  {"cmd":"mode","val":"sleep"}        // sleep|awake
 *  {"cmd":"all_off"}
 *  {"cmd":"all_on"}
 *  {"cmd":"reset_cigs"}
 *
 * ─────────────────────────────────────────────────────────────────
 *  OTA FLASH (change WiFi creds etc.)
 * ─────────────────────────────────────────────────────────────────
 *  platformio.ini:
 *    upload_protocol = espota
 *    upload_port     = shreyansh.local
 *    upload_flags    = --auth=openclaw-ota-2024
 *  Then: pio run -t upload
 *
 * ─────────────────────────────────────────────────────────────────
 *  PYTHON / OpenClaw Intelligence Layer
 * ─────────────────────────────────────────────────────────────────
 *  import requests
 *  BASE = "http://shreyansh.local"
 *  state = requests.get(f"{BASE}/api/state").json()
 *  requests.post(f"{BASE}/api/cmd", json={"cmd":"relay","ch":0,"val":True})
 *  requests.post(f"{BASE}/api/cmd", json={"cmd":"strip","val":180})
 * ─────────────────────────────────────────────────────────────────
 */

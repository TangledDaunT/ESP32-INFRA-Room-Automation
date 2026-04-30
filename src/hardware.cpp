#include "hardware.h"
#include "config.h"
#include <Wire.h>

// ═══════════════════════════════════════════════════
//  APDS-9930 Register Definitions
// ═══════════════════════════════════════════════════
#define APDS_CMD            0x80   // Command bit (repeated byte)
#define APDS_CMD_AUTO       0xA0   // Command + auto-increment
#define APDS_REG_ENABLE     0x00
#define APDS_REG_ATIME      0x01
#define APDS_REG_PTIME      0x02
#define APDS_REG_WTIME      0x03
#define APDS_REG_PPULSE     0x0E
#define APDS_REG_CONTROL    0x0F
#define APDS_REG_ID         0x12
#define APDS_REG_STATUS     0x13
#define APDS_REG_CH0DATAL   0x14
#define APDS_REG_CH1DATAL   0x16
#define APDS_REG_PDATAL     0x18
// Enable register bits
#define APDS_PON            0x01
#define APDS_AEN            0x02
#define APDS_PEN            0x04
#define APDS_WEN            0x08

// ═══════════════════════════════════════════════════
//  Module-level state
// ═══════════════════════════════════════════════════
static bool     _relayState[RELAY_COUNT] = {false, false, false, false};
static uint8_t  _flashBrightness = 0;
static uint8_t  _stripBrightness = 0;
static bool     _apdsOK = false;

// Fade animations
static FadeState _flashFade;
static FadeState _stripFade;

// Debounce state
static bool          _lastRadarRaw   = false;
static bool          _radarStable    = false;
static unsigned long _radarChangeMs  = 0;

static bool          _lastTouchRaw   = false;
static bool          _touchEdge      = false;
static unsigned long _touchChangeMs  = 0;
static unsigned long _touchHoldStart = 0;   // Track hold duration for AUTO-3

// Relay GPIO lookup
static const uint8_t _relayPins[RELAY_COUNT] = {
    PIN_RELAY_1, PIN_RELAY_2, PIN_RELAY_3, PIN_RELAY_4
};
static const char* _relayLabels[RELAY_COUNT] = {
    "Main Lights", "Fan", "220V RGB", "Charging"
};

// ═══════════════════════════════════════════════════
//  APDS-9930 low-level I2C helpers
// ═══════════════════════════════════════════════════

static bool apds_write(uint8_t reg, uint8_t val) {
    Wire.beginTransmission(APDS9930_I2C_ADDR);
    Wire.write(APDS_CMD | reg);
    Wire.write(val);
    return Wire.endTransmission() == 0;
}

static uint8_t apds_read8(uint8_t reg) {
    Wire.beginTransmission(APDS9930_I2C_ADDR);
    Wire.write(APDS_CMD | reg);
    Wire.endTransmission(false);
    Wire.requestFrom((uint8_t)APDS9930_I2C_ADDR, (uint8_t)1);
    return Wire.available() ? Wire.read() : 0;
}

static uint16_t apds_read16(uint8_t reg) {
    Wire.beginTransmission(APDS9930_I2C_ADDR);
    Wire.write(APDS_CMD_AUTO | reg);  // auto-increment for 2-byte read
    Wire.endTransmission(false);
    Wire.requestFrom((uint8_t)APDS9930_I2C_ADDR, (uint8_t)2);
    if (Wire.available() < 2) return 0;
    uint16_t lo = Wire.read();
    uint16_t hi = Wire.read();
    return (hi << 8) | lo;
}

static bool apds_init() {
    // Verify device ID (should be 0x39 for APDS-9930)
    uint8_t id = apds_read8(APDS_REG_ID);
    Serial.printf("[APDS] Device ID: 0x%02X\n", id);
    if (id != 0x39 && id != 0x12) {
        Serial.println("[APDS] WARNING: unexpected ID, attempting init anyway");
    }

    // ALS integration time: ~100 ms  (256 − 0xDB) × 2.73 ms ≈ 101 ms
    apds_write(APDS_REG_ATIME, 0xDB);
    // Proximity integration time: 2.73 ms
    apds_write(APDS_REG_PTIME, 0xFF);
    // Wait time: 2.73 ms
    apds_write(APDS_REG_WTIME, 0xFF);
    // 8 proximity pulses
    apds_write(APDS_REG_PPULSE, 8);
    // Control: PDRIVE=100mA, PDIODE=CH1, PGAIN=1x, AGAIN=1x → 0x20
    apds_write(APDS_REG_CONTROL, 0x20);
    // Enable: PON + AEN + PEN + WEN
    apds_write(APDS_REG_ENABLE, APDS_PON | APDS_AEN | APDS_PEN | APDS_WEN);

    delay(12);  // Allow power-on to stabilise

    // Verify enable register was written
    uint8_t en = apds_read8(APDS_REG_ENABLE);
    return (en & (APDS_PON | APDS_AEN | APDS_PEN)) != 0;
}

// Lux calculation from APDS-9930 datasheet coefficients (open air)
static float apds_calcLux(uint16_t ch0, uint16_t ch1) {
    if (ch0 == 0) return 0.0f;
    const float B  = 1.862f;
    const float C  = 0.746f;
    const float D  = 1.291f;
    const float GA = 0.49f;   // Glass attenuation factor (no cover)
    const float DF = 52.0f;   // Device factor

    float atimeMs  = (256.0f - 0xDB) * 2.73f;  // ~101 ms
    float again    = 1.0f;

    float iac1 = (float)ch0 - B * (float)ch1;
    float iac2 = C * (float)ch0 - D * (float)ch1;
    float iac  = max(max(iac1, iac2), 0.0f);

    float lpc  = GA * DF / (atimeMs * again);
    return iac * lpc;
}

// ═══════════════════════════════════════════════════
//  Ease-in-out for premium fade animation
// ═══════════════════════════════════════════════════
static float easeInOutQuad(float t) {
    return t < 0.5f ? 2.0f * t * t : 1.0f - powf(-2.0f * t + 2.0f, 2.0f) / 2.0f;
}

static void updateFade(FadeState *f, uint8_t channel, uint8_t *storedBrightness) {
    if (!f->active) return;

    unsigned long elapsed = millis() - f->startTime;
    if (elapsed >= f->duration) {
        ledcWrite(channel, f->endVal);
        *storedBrightness = f->endVal;
        f->active = false;
    } else {
        float progress = easeInOutQuad((float)elapsed / (float)f->duration);
        uint8_t val = (uint8_t)((float)f->startVal + ((float)f->endVal - (float)f->startVal) * progress);
        ledcWrite(channel, val);
        *storedBrightness = val;
    }
}

// ═══════════════════════════════════════════════════
//  PUBLIC: Initialisation
// ═══════════════════════════════════════════════════

void hw_init() {
    // --- Relay pins (active LOW: HIGH = relay OFF) ---
    for (int i = 0; i < RELAY_COUNT; i++) {
        pinMode(_relayPins[i], OUTPUT);
        digitalWrite(_relayPins[i], HIGH);  // All relays OFF at boot
    }

    // --- MOSFET PWM ---
    ledcSetup(PWM_CHANNEL_FLASH, PWM_FREQ_HZ, PWM_RESOLUTION_BITS);
    ledcAttachPin(PIN_MOSFET_FLASH, PWM_CHANNEL_FLASH);
    ledcWrite(PWM_CHANNEL_FLASH, 0);

    ledcSetup(PWM_CHANNEL_STRIP, PWM_FREQ_HZ, PWM_RESOLUTION_BITS);
    ledcAttachPin(PIN_MOSFET_STRIP, PWM_CHANNEL_STRIP);
    ledcWrite(PWM_CHANNEL_STRIP, 0);

    // --- MQ-2 ---
    pinMode(PIN_MQ2_AO, INPUT);
    pinMode(PIN_MQ2_DO, INPUT);

    // --- Radar ---
    pinMode(PIN_RADAR, INPUT);

    // --- Touch ---
    pinMode(PIN_TOUCH, INPUT);

    // --- Status LED ---
    pinMode(PIN_STATUS_LED, OUTPUT);
    digitalWrite(PIN_STATUS_LED, LOW);

    // --- I2C for APDS-9930 ---
    Wire.begin(PIN_I2C_SDA, PIN_I2C_SCL);
    Wire.setClock(100000);  // 100 kHz standard mode
    _apdsOK = apds_init();
    Serial.printf("[HW] APDS-9930: %s\n", _apdsOK ? "OK" : "NOT FOUND");
}

bool hw_apdsAvailable() {
    return _apdsOK;
}

// ═══════════════════════════════════════════════════
//  PUBLIC: Relay control
// ═══════════════════════════════════════════════════

void hw_setRelay(uint8_t ch, bool on) {
    if (ch >= RELAY_COUNT) return;
    _relayState[ch] = on;
    // Active LOW: LOW = relay ON, HIGH = relay OFF
    digitalWrite(_relayPins[ch], on ? LOW : HIGH);
}

bool hw_getRelay(uint8_t ch) {
    if (ch >= RELAY_COUNT) return false;
    return _relayState[ch];
}

const char* hw_relayLabel(uint8_t ch) {
    if (ch >= RELAY_COUNT) return "?";
    return _relayLabels[ch];
}

// ═══════════════════════════════════════════════════
//  PUBLIC: MOSFET brightness
// ═══════════════════════════════════════════════════

void hw_setFlashBrightness(uint8_t val) {
    _flashFade.active = false;  // Cancel ongoing fade
    _flashBrightness = val;
    ledcWrite(PWM_CHANNEL_FLASH, val);
}

void hw_setStripBrightness(uint8_t val) {
    _stripFade.active = false;
    _stripBrightness = val;
    ledcWrite(PWM_CHANNEL_STRIP, val);
}

uint8_t hw_getFlashBrightness() { return _flashBrightness; }
uint8_t hw_getStripBrightness() { return _stripBrightness; }

// ═══════════════════════════════════════════════════
//  PUBLIC: Smooth fade
// ═══════════════════════════════════════════════════

void hw_fadeFlash(uint8_t target, unsigned long durationMs) {
    _flashFade.startVal  = _flashBrightness;
    _flashFade.endVal    = target;
    _flashFade.startTime = millis();
    _flashFade.duration  = durationMs;
    _flashFade.active    = true;
}

void hw_fadeStrip(uint8_t target, unsigned long durationMs) {
    _stripFade.startVal  = _stripBrightness;
    _stripFade.endVal    = target;
    _stripFade.startTime = millis();
    _stripFade.duration  = durationMs;
    _stripFade.active    = true;
}

void hw_cancelFades() {
    _flashFade.active = false;
    _stripFade.active = false;
}

void hw_updateFades() {
    updateFade(&_flashFade, PWM_CHANNEL_FLASH, &_flashBrightness);
    updateFade(&_stripFade, PWM_CHANNEL_STRIP, &_stripBrightness);
}

bool hw_isFading() {
    return _flashFade.active || _stripFade.active;
}

// ═══════════════════════════════════════════════════
//  PUBLIC: MQ-2 Smoke Sensor
// ═══════════════════════════════════════════════════

uint16_t hw_readSmokeAnalog() {
    uint32_t sum = 0;
    for (int i = 0; i < MQ2_ADC_OVERSAMPLE; i++) {
        sum += analogRead(PIN_MQ2_AO);
        delayMicroseconds(100);
    }
    return (uint16_t)(sum / MQ2_ADC_OVERSAMPLE);
}

bool hw_readSmokeDigital() {
    return digitalRead(PIN_MQ2_DO) == HIGH;
}

// ═══════════════════════════════════════════════════
//  PUBLIC: APDS-9930
// ═══════════════════════════════════════════════════

bool hw_readLux(float &lux) {
    if (!_apdsOK) return false;
    uint16_t ch0 = apds_read16(APDS_REG_CH0DATAL);
    uint16_t ch1 = apds_read16(APDS_REG_CH1DATAL);
    lux = apds_calcLux(ch0, ch1);
    return true;
}

bool hw_readProximity(uint16_t &prox) {
    if (!_apdsOK) return false;
    prox = apds_read16(APDS_REG_PDATAL);
    return true;
}

// ═══════════════════════════════════════════════════
//  PUBLIC: RCWL-0516 Radar (software debounced)
// ═══════════════════════════════════════════════════

bool hw_readRadar() {
    bool raw = digitalRead(PIN_RADAR) == HIGH;
    unsigned long now = millis();

    if (raw != _lastRadarRaw) {
        _lastRadarRaw  = raw;
        _radarChangeMs = now;
    }

    // Only update stable state after debounce period
    if ((now - _radarChangeMs) >= RADAR_DEBOUNCE_MS) {
        _radarStable = _lastRadarRaw;
    }
    return _radarStable;
}

// ═══════════════════════════════════════════════════
//  PUBLIC: TTP223 Touch (edge detection)
// ═══════════════════════════════════════════════════

bool hw_readTouchPressed() {
    bool raw = digitalRead(PIN_TOUCH) == HIGH;
    unsigned long now = millis();
    bool pressed = false;

    // Detect rising edge with debounce
    if (raw && !_lastTouchRaw && (now - _touchChangeMs) >= TOUCH_DEBOUNCE_MS) {
        pressed = true;
        _touchChangeMs = now;
    }
    _lastTouchRaw = raw;
    return pressed;
}

uint32_t hw_getTouchHoldMs() {
    bool raw = digitalRead(PIN_TOUCH) == HIGH;
    if (raw) {
        if (_touchHoldStart == 0) _touchHoldStart = millis();
        return (uint32_t)(millis() - _touchHoldStart);
    } else {
        _touchHoldStart = 0;
        return 0;
    }
}

// ═══════════════════════════════════════════════════
//  PUBLIC: Status LED
// ═══════════════════════════════════════════════════

void hw_setStatusLED(bool on) {
    digitalWrite(PIN_STATUS_LED, on ? HIGH : LOW);
}

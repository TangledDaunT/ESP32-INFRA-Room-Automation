#pragma once
#include <Arduino.h>

// ═══════════════════════════════════════════════════
//  Fade animation state (non-blocking PWM ramp)
// ═══════════════════════════════════════════════════
struct FadeState {
    bool     active    = false;
    uint8_t  startVal  = 0;
    uint8_t  endVal    = 0;
    unsigned long startTime = 0;
    unsigned long duration  = 0;
};

// ═══════════════════════════════════════════════════
//  Initialisation
// ═══════════════════════════════════════════════════
void     hw_init();                       // Call once in setup()
bool     hw_apdsAvailable();              // True if APDS-9930 responded on I2C

// ═══════════════════════════════════════════════════
//  Relay control  (channel 0-3, state true=ON)
// ═══════════════════════════════════════════════════
void     hw_setRelay(uint8_t ch, bool on);
bool     hw_getRelay(uint8_t ch);
const char* hw_relayLabel(uint8_t ch);

// ═══════════════════════════════════════════════════
//  MOSFET PWM  (brightness 0-255)
// ═══════════════════════════════════════════════════
void     hw_setFlashBrightness(uint8_t val);
void     hw_setStripBrightness(uint8_t val);
uint8_t  hw_getFlashBrightness();
uint8_t  hw_getStripBrightness();

// Smooth fade (non-blocking, call hw_updateFades() in loop)
void     hw_fadeFlash(uint8_t target, unsigned long durationMs);
void     hw_fadeStrip(uint8_t target, unsigned long durationMs);
void     hw_cancelFades();    // Cancel any in-progress fade
void     hw_updateFades();    // Must be called every loop iteration
bool     hw_isFading();       // True if any fade is active

// ═══════════════════════════════════════════════════
//  MQ-2 Smoke Sensor
// ═══════════════════════════════════════════════════
uint16_t hw_readSmokeAnalog();   // 32-sample oversampled ADC (0-4095)
bool     hw_readSmokeDigital();  // DO pin state

// ═══════════════════════════════════════════════════
//  APDS-9930  (returns false if sensor unavailable)
// ═══════════════════════════════════════════════════
bool     hw_readLux(float &lux);
bool     hw_readProximity(uint16_t &prox);

// ═══════════════════════════════════════════════════
//  RCWL-0516 Radar  (debounced)
// ═══════════════════════════════════════════════════
bool     hw_readRadar();

// ═══════════════════════════════════════════════════
//  TTP223 Touch  (edge-detected: true only once per press)
// ═══════════════════════════════════════════════════
bool     hw_readTouchPressed();
uint32_t hw_getTouchHoldMs();           // Duration touch is held (0 if not held)

// ═══════════════════════════════════════════════════
//  Status LED  (GPIO 2)
// ═══════════════════════════════════════════════════
void     hw_setStatusLED(bool on);

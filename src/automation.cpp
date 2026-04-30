#include "automation.h"
#include "config.h"
#include "hardware.h"
#include "sensors.h"
#include "smoke_tracker.h"
#include "network.h"

// ═══════════════════════════════════════════════════
//  Internal state
// ═══════════════════════════════════════════════════
static RoomMode _mode = MODE_AWAKE;

// Presence tracking
static bool          _present         = false;
static unsigned long _lastMotionMs    = 0;     // Last time radar saw motion
static bool          _wasPresent      = false;  // For entry edge detection

// Proximity trigger state
static bool          _proxTriggered   = false;
static unsigned long _lastProxMs      = 0;

// Sleep-mode strip toggle (proximity toggles strip on/off in sleep)
static bool          _sleepStripOn    = false;

// Touch state
static bool          _stripOnByTouch  = false;

// AUTO-2: Smoke-triggered fan state
static bool          _smokeFanActive  = false;
static SmokePhase    _lastSmokePhase  = SMOKE_WARMUP;

// AUTO-5: Absence all-off tracking
static bool          _absenceAllOff   = false;

// AUTO-3: Touch long-press tracking
static bool          _longPressTriggered = false;

// AUTO-4: BLE wake tracking
static bool          _lastBleConnected = false;

// ═══════════════════════════════════════════════════
//  Helpers
// ═══════════════════════════════════════════════════

static void enterSleep() {
    _mode = MODE_SLEEP;
    _sleepStripOn = false;
    Serial.println("[AUTO] → SLEEP mode");

    // Turn off lights
    hw_setRelay(0, false);  // Main lights OFF
    hw_setRelay(2, false);  // 220V RGB OFF
    // Fan (ch 1) and Charging (ch 3) stay as-is

    // Fade out strip and flash
    hw_fadeStrip(0, FADE_OUT_DURATION);
    hw_fadeFlash(0, FADE_OUT_DURATION);
}

static void enterAwake() {
    _mode = MODE_AWAKE;
    _sleepStripOn = false;
    _absenceAllOff = false;
    Serial.println("[AUTO] → AWAKE mode");
}

// ═══════════════════════════════════════════════════
//  PUBLIC
// ═══════════════════════════════════════════════════

void auto_init() {
    _mode         = MODE_AWAKE;
    _present      = false;
    _wasPresent   = false;
    _lastMotionMs = millis();
    _sleepStripOn = false;
    _stripOnByTouch = false;
    _smokeFanActive = false;
    _lastSmokePhase = SMOKE_WARMUP;
    _absenceAllOff  = false;
    _longPressTriggered = false;
    _lastBleConnected = false;
}

void auto_update() {
    unsigned long now = millis();

    // ──────────────────────────────────────────────
    //  1. Radar presence tracking
    // ──────────────────────────────────────────────
    bool radarNow = hw_readRadar();
    if (radarNow) {
        _lastMotionMs = now;
    }

    // Present if motion was seen within the absence timeout window
    _present = (now - _lastMotionMs) < RADAR_ABSENCE_TIMEOUT;

    // ──────────────────────────────────────────────
    //  2. Proximity sensor (hand wave detection)
    //     BUG-06 fix: use cached sensor value instead
    //     of hw_readProximity() to avoid I2C race
    // ──────────────────────────────────────────────
    uint16_t prox = sensors_getProximity();
    bool proxTrigger = false;
    bool nearNow = prox > PROXIMITY_THRESHOLD;
    // Detect rising edge with cooldown
    if (nearNow && !_proxTriggered && (now - _lastProxMs) >= PROXIMITY_COOLDOWN_MS) {
        proxTrigger    = true;
        _lastProxMs    = now;
    }
    _proxTriggered = nearNow;

    // ──────────────────────────────────────────────
    //  3. TTP223 touch (works in both modes, offline)
    // ──────────────────────────────────────────────
    bool touchPressed = hw_readTouchPressed();

    // ──────────────────────────────────────────────
    //  3b. AUTO-3: Touch long-press (>2s) → all lights full
    // ──────────────────────────────────────────────
    uint32_t holdMs = hw_getTouchHoldMs();
    if (holdMs >= 2000 && !_longPressTriggered) {
        // Long press detected — turn everything ON full
        hw_setRelay(0, true);   // Main lights
        hw_setRelay(1, true);   // Fan
        hw_setRelay(2, true);   // 220V RGB
        hw_setRelay(3, true);   // Charging socket
        hw_setStripBrightness(255);
        hw_setFlashBrightness(255);
        if (_mode == MODE_SLEEP) enterAwake();
        _longPressTriggered = true;
        Serial.println("[AUTO] Long-press → ALL ON full brightness");
    }
    if (holdMs == 0) {
        _longPressTriggered = false;  // Reset when released
    }

    // ──────────────────────────────────────────────
    //  3c. AUTO-4: BLE connect → auto-wake from sleep
    // ──────────────────────────────────────────────
    bool bleNow = net_isBleConnected();
    if (bleNow && !_lastBleConnected && _mode == MODE_SLEEP) {
        // Phone just connected via BLE while in sleep → wake up
        enterAwake();
        Serial.println("[AUTO] BLE connect → auto-wake from sleep");
    }
    _lastBleConnected = bleNow;

    // ──────────────────────────────────────────────
    //  4. AUTO-2: Smoke alarm fan trigger
    //     When cigarette detected (transition to COOLDOWN),
    //     turn fan ON. Turn fan OFF when cooldown completes.
    // ──────────────────────────────────────────────
    SmokePhase curPhase = smoke_getPhase();
    if (curPhase == SMOKE_COOLDOWN && _lastSmokePhase != SMOKE_COOLDOWN) {
        // Transition into cooldown — cigarette just detected
        if (!hw_getRelay(1)) {  // Fan is relay ch1
            hw_setRelay(1, true);
            _smokeFanActive = true;
            Serial.println("[AUTO] Smoke detected — fan ON");
        }
    }
    if (_smokeFanActive && curPhase == SMOKE_IDLE && _lastSmokePhase == SMOKE_COOLDOWN) {
        // Cooldown just completed — turn fan off if we turned it on
        hw_setRelay(1, false);
        _smokeFanActive = false;
        Serial.println("[AUTO] Smoke cooldown done — fan OFF");
    }
    _lastSmokePhase = curPhase;

    // ──────────────────────────────────────────────
    //  5. Mode-specific automation
    // ──────────────────────────────────────────────

    if (_mode == MODE_AWAKE) {
        // ── Radar: entry fade-in ──
        if (_present && !_wasPresent) {
            // Someone just entered the room — premium fade-in
            // AUTO-1: gate by lux — don't turn on lights in bright room
            float lux = sensors_getLux();
            if (lux < 0 || lux < LUX_DAYLIGHT_THRESHOLD) {
                Serial.println("[AUTO] Presence detected — LED strip fade in");
                uint8_t target = (hw_getStripBrightness() > 0) ? hw_getStripBrightness() : STRIP_DEFAULT_BRIGHTNESS;
                hw_fadeStrip(target, FADE_IN_DURATION);
            } else {
                Serial.printf("[AUTO] Presence detected — lux %.0f ≥ %d, skip fade-in\n", lux, LUX_DAYLIGHT_THRESHOLD);
            }
            _absenceAllOff = false;  // Reset absence flag on re-entry
        }

        // ── Radar: absence fade-out ──
        if (!_present && _wasPresent) {
            Serial.println("[AUTO] Room empty — LED strip fade out");
            hw_fadeStrip(0, FADE_OUT_DURATION);
        }

        // ── AUTO-5: Extended absence all-off ──
        // If radar absence exceeds timeout AND mode is AWAKE,
        // turn off all relays in addition to faded strip
        if (!_present && !_absenceAllOff) {
            // Check if absence has persisted long enough
            // (RADAR_ABSENCE_TIMEOUT already defines the threshold)
            // At this point _present is false, meaning absence > 5 min
            hw_setRelay(0, false);  // Main lights
            hw_setRelay(1, false);  // Fan
            hw_setRelay(2, false);  // 220V RGB
            // Keep charging socket (ch3) as-is — intentional
            _absenceAllOff = true;
            Serial.println("[AUTO] Extended absence — all relays OFF");
        }

        // ── TTP223: toggle LED strip with slow fade ──
        if (touchPressed) {
            if (hw_getStripBrightness() > 0 || hw_isFading()) {
                // Strip is ON or fading in → fade out
                hw_fadeStrip(0, TOUCH_FADE_DURATION);
                _stripOnByTouch = false;
                Serial.println("[AUTO] Touch → strip fade out");
            } else {
                // Strip is OFF → fade in
                hw_fadeStrip(STRIP_DEFAULT_BRIGHTNESS, TOUCH_FADE_DURATION);
                _stripOnByTouch = true;
                Serial.println("[AUTO] Touch → strip fade in");
            }
        }

        // ── Proximity: enter sleep ──
        if (proxTrigger) {
            enterSleep();
        }

    } else {
        // ═══ MODE_SLEEP ═══

        // ── Proximity: toggle dim LED strip for nighttime ──
        if (proxTrigger) {
            if (_sleepStripOn) {
                hw_fadeStrip(0, TOUCH_FADE_DURATION);
                _sleepStripOn = false;
                Serial.println("[AUTO] Sleep prox → strip OFF");
            } else {
                hw_fadeStrip(STRIP_DIM_BRIGHTNESS, TOUCH_FADE_DURATION);
                _sleepStripOn = true;
                Serial.println("[AUTO] Sleep prox → strip dim ON");
            }
        }

        // ── Radar: if presence after long absence, wake up ──
        // (If you were sleeping and someone walks in, assume waking up)
        if (_present && !_wasPresent) {
            // Don't auto-wake immediately — only proximity wakes.
            // But we do update _wasPresent below.
        }

        // ── TTP223 still works in sleep: toggle strip ──
        if (touchPressed) {
            if (_sleepStripOn || hw_getStripBrightness() > 0) {
                hw_fadeStrip(0, TOUCH_FADE_DURATION);
                _sleepStripOn = false;
            } else {
                hw_fadeStrip(STRIP_DIM_BRIGHTNESS, TOUCH_FADE_DURATION);
                _sleepStripOn = true;
            }
        }
    }

    _wasPresent = _present;
}

RoomMode auto_getMode() {
    return _mode;
}

void auto_setMode(RoomMode m) {
    if (m == MODE_SLEEP && _mode != MODE_SLEEP) {
        enterSleep();
    } else if (m == MODE_AWAKE && _mode != MODE_AWAKE) {
        enterAwake();
    }
}

bool auto_isPresent() {
    return _present;
}

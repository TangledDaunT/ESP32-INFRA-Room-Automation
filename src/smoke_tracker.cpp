#include "smoke_tracker.h"
#include "config.h"
#include <math.h>

// ═══════════════════════════════════════════════════
//  Internal state
// ═══════════════════════════════════════════════════
static SmokePhase _phase = SMOKE_WARMUP;
static unsigned long _startTime = 0;

// Calibration accumulators
static double   _calSum      = 0.0;
static double   _calSumSq    = 0.0;
static uint32_t _calCount    = 0;

// Detection thresholds (set after calibration)
static uint16_t _baseline    = 0;
static uint16_t _threshold   = 0;

// Spike confirmation
static uint8_t  _spikeCount  = 0;   // Consecutive readings above threshold

// Cigarette counter
static int      _cigarettes  = 0;

// Cooldown tracking
static unsigned long _cooldownStart = 0;

// ═══════════════════════════════════════════════════
//  PUBLIC
// ═══════════════════════════════════════════════════

void smoke_init() {
    _phase        = SMOKE_WARMUP;
    _startTime    = millis();
    _calSum       = 0.0;
    _calSumSq     = 0.0;
    _calCount     = 0;
    _baseline     = 0;
    _threshold    = 0;
    _spikeCount   = 0;
    _cigarettes   = 0;
    _cooldownStart = 0;
    Serial.println("[SMOKE] Warmup started — 30 s sensor stabilisation");
}

void smoke_feed(uint16_t val) {
    unsigned long elapsed = millis() - _startTime;

    switch (_phase) {

    // ── WARMUP: discard first 30 s of noisy readings ──
    case SMOKE_WARMUP:
        if (elapsed >= MQ2_WARMUP_MS) {
            _phase = SMOKE_CALIBRATE;
            Serial.println("[SMOKE] Calibration started — collecting baseline");
        }
        break;

    // ── CALIBRATE: accumulate readings for mean + σ ──
    case SMOKE_CALIBRATE:
        _calSum   += (double)val;
        _calSumSq += (double)val * (double)val;
        _calCount++;

        if (elapsed >= MQ2_CALIBRATION_MS) {
            // Compute baseline and noise floor
            double mean   = _calSum / _calCount;
            double var    = (_calSumSq / _calCount) - (mean * mean);
            double sigma  = sqrt(max(var, 0.0));

            if (_calCount < 20 || var > 500.0) {
                _baseline  = 800;
                _threshold = _baseline + 20;
                Serial.println("smoke_tracker: calibration invalid, using conservative baseline");
            } else {
                _baseline  = (uint16_t)mean;
                _threshold = (uint16_t)(mean + MQ2_SPIKE_SIGMA * sigma);

                // Safety floor: threshold must be at least baseline + 20
                if (_threshold < _baseline + 20) {
                    _threshold = _baseline + 20;
                }
                Serial.printf("[SMOKE] Calibrated — baseline: %u, σ: %.1f, threshold: %u  (%u samples)\n",
                              _baseline, (float)sigma, _threshold, _calCount);
            }

            _phase = SMOKE_IDLE;
        }
        break;

    // ── IDLE: watch for sustained spike ──
    case SMOKE_IDLE:
        if (val > _threshold) {
            _spikeCount++;
            if (_spikeCount >= MQ2_SPIKE_CONFIRM_SEC) {
                _cigarettes++;
                _phase = SMOKE_COOLDOWN;
                _cooldownStart = millis();
                _spikeCount = 0;
                Serial.printf("[SMOKE] Cigarette #%d detected (spike held %d s)\n",
                              _cigarettes, MQ2_SPIKE_CONFIRM_SEC);
            }
        } else {
            _spikeCount = 0;  // Reset counter if reading drops below threshold
        }
        break;

    // ── COOLDOWN: ignore spikes for 3 minutes to prevent double-counting ──
    case SMOKE_COOLDOWN:
        if ((millis() - _cooldownStart) >= MQ2_COOLDOWN_MS) {
            _spikeCount = 0;
            _phase = SMOKE_IDLE;
            Serial.println("[SMOKE] Cooldown complete — monitoring resumed");
        }
        break;
    }
}

SmokePhase smoke_getPhase()          { return _phase; }
bool       smoke_isCalibrated()      { return _phase >= SMOKE_IDLE; }
bool       smoke_isInCooldown()      { return _phase == SMOKE_COOLDOWN; }
int        smoke_getCigaretteCount() { return _cigarettes; }
uint16_t   smoke_getBaseline()       { return _baseline; }
uint16_t   smoke_getThreshold()      { return _threshold; }

void smoke_resetDaily() {
    _cigarettes = 0;
    Serial.println("[SMOKE] Daily counter reset to 0");
}

void smoke_restoreCount(int count) {
    _cigarettes = count;
    Serial.printf("[SMOKE] Restored count from NVS: %d\n", count);
}

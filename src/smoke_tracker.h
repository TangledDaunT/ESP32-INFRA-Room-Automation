#pragma once
#include <Arduino.h>

// ═══════════════════════════════════════════════════
//  MQ-2 Cigarette Smoke Tracker
//
//  Phase 1 — WARMUP   (0–30 s):  ignore noisy startup readings
//  Phase 2 — CALIBRATE (30–120 s): build baseline mean + σ
//  Phase 3 — IDLE / COOLDOWN: detect spikes, count cigarettes
//
//  BUG-05 fix: removed unreachable SMOKE_SMOKING state
// ═══════════════════════════════════════════════════

enum SmokePhase {
    SMOKE_WARMUP,
    SMOKE_CALIBRATE,
    SMOKE_IDLE,
    SMOKE_COOLDOWN
};

void         smoke_init();
void         smoke_feed(uint16_t analogVal);   // Call at 1 Hz with oversampled value
SmokePhase   smoke_getPhase();
bool         smoke_isCalibrated();
bool         smoke_isInCooldown();             // BUG-05 fix: renamed from smoke_isSmoking()
int          smoke_getCigaretteCount();
uint16_t     smoke_getBaseline();
uint16_t     smoke_getThreshold();
void         smoke_resetDaily();               // Call at midnight
void         smoke_restoreCount(int count);    // Restore from NVS after reboot

#pragma once
#include <Arduino.h>

// ═══════════════════════════════════════════════════
//  Room mode (global state machine)
// ═══════════════════════════════════════════════════
enum RoomMode {
    MODE_AWAKE,
    MODE_SLEEP
};

void       auto_init();                     // Call in setup()
void       auto_update();                   // Call every loop iteration
RoomMode   auto_getMode();
void       auto_setMode(RoomMode m);        // Manual mode override (from dashboard)
bool       auto_isPresent();                // Room occupancy state

#pragma once
#include <Arduino.h>

// ═══════════════════════════════════════════════════
//  Thread-safe sensor getters
//  These read from mutex-protected globals in main.cpp
//  Use these instead of calling hw_read*() directly outside
//  the sensor task to avoid I2C race conditions.
// ═══════════════════════════════════════════════════

float    sensors_getLux();         // Returns -1 if mutex timeout
uint16_t sensors_getSmoke();      // Returns 0 if mutex timeout
bool     sensors_getSmokeDO();    // Returns false if mutex timeout
uint16_t sensors_getProximity();  // Returns 0 if mutex timeout
int      sensors_getCigarettes(); // Thread-safe cigarette count

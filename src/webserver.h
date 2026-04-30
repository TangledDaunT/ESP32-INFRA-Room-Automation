#pragma once
#include <Arduino.h>

// Forward-declare the command handler type (used by BLE too)
typedef void (*CommandHandler)(const String &json);

void ws_init(CommandHandler cmdHandler);   // Call in setup() after net_init()
void ws_broadcastState();                  // Call periodically (every 500 ms)
void ws_setCommandHandler(CommandHandler h);

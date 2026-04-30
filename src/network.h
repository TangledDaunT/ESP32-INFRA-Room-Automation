#pragma once
#include <Arduino.h>

// Forward-declare the command handler type (shared with webserver.h)
typedef void (*CommandHandler)(const String &json);

void     net_init(CommandHandler cmdHandler);  // WiFi + mDNS + OTA + BLE — call in setup()
void     net_loop();              // OTA handle + WiFi reconnect — call in loop()
bool     net_isWifiConnected();
int      net_getWifiRSSI();
String   net_getIP();

// BLE sensor push — call every 2 s from main loop (GAP-3)
void     net_blePushSensors(uint16_t smoke, float lux, bool present);

// BLE state push — call after state changes for immediate phone app UI update
void     net_blePushState(const String &stateJson);

// BLE connection status
bool     net_isBleConnected();

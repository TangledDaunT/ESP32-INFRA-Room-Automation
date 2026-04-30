#pragma once
#include <Arduino.h>
#include "webserver.h"  // For CommandHandler typedef

// ═══════════════════════════════════════════════════
//  MQTT Client for OpenClaw integration
//  Uses PubSubClient over WiFiClientSecure (TLS)
//  for HiveMQ Cloud on port 8883
// ═══════════════════════════════════════════════════

void mqtt_init(CommandHandler cmdHandler);  // Call after ws_init()
void mqtt_loop();                           // Call in main loop
void mqtt_publishSensors(uint16_t smoke, float lux, bool present);
void mqtt_publishState();                   // Full openclaw/state JSON
bool mqtt_isConnected();

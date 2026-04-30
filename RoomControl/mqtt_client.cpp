#include "mqtt_client.h"
#include "config.h"
#include "hardware.h"
#include "automation.h"
#include "sensors.h"
#include "smoke_tracker.h"

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <esp_task_wdt.h>

// ═══════════════════════════════════════════════════
//  Internal state
// ═══════════════════════════════════════════════════
static WiFiClientSecure _tlsClient;
static PubSubClient     _mqtt(_tlsClient);
static CommandHandler   _mqttCmdHandler = nullptr;
static unsigned long    _lastReconnectAttempt = 0;
static const unsigned long RECONNECT_INTERVAL = 5000;  // 5 s backoff

// ═══════════════════════════════════════════════════
//  MQTT message callback
//  Translates phone app topic-based commands into
//  the JSON format handleCommand() understands
// ═══════════════════════════════════════════════════
static void mqttCallback(char *topic, byte *payload, unsigned int length) {
    // Null-terminate payload
    char msg[256];
    unsigned int copyLen = min(length, (unsigned int)(sizeof(msg) - 1));
    memcpy(msg, payload, copyLen);
    msg[copyLen] = '\0';

    Serial.printf("[MQTT] Received %s: %s\n", topic, msg);

    if (!_mqttCmdHandler) return;

    // Build a command JSON in phone app format that handleCommand() understands
    StaticJsonDocument<256> doc;

    // Translation: topic → device/state
    if (strcmp(topic, MQTT_T_FAN) == 0) {
        doc["device"] = "fan";
        doc["state"]  = msg;  // "ON" or "OFF"
    } else if (strcmp(topic, MQTT_T_LIGHT) == 0) {
        doc["device"] = "light";
        doc["state"]  = msg;
    } else if (strcmp(topic, MQTT_T_SOCKET) == 0) {
        doc["device"] = "socket";
        doc["state"]  = msg;
    } else if (strcmp(topic, MQTT_T_RGB) == 0) {
        doc["device"] = "rgb";
        doc["state"]  = msg;
    } else if (strcmp(topic, MQTT_T_RGB_BRIGHT) == 0) {
        doc["device"] = "rgb";
        doc["brightness"] = atoi(msg);
    } else if (strcmp(topic, MQTT_T_BACKUP_BRIGHT) == 0) {
        doc["device"] = "backup";
        doc["brightness"] = atoi(msg);
    } else {
        // Unknown topic — try passing raw payload as JSON command
        _mqttCmdHandler(String(msg));
        return;
    }

    String cmdJson;
    serializeJson(doc, cmdJson);
    _mqttCmdHandler(cmdJson);
}

// ═══════════════════════════════════════════════════
//  Subscribe to all control topics
// ═══════════════════════════════════════════════════
static void mqttSubscribe() {
    _mqtt.subscribe(MQTT_T_FAN);
    _mqtt.subscribe(MQTT_T_LIGHT);
    _mqtt.subscribe(MQTT_T_SOCKET);
    _mqtt.subscribe(MQTT_T_RGB);
    _mqtt.subscribe(MQTT_T_RGB_BRIGHT);
    _mqtt.subscribe(MQTT_T_BACKUP_BRIGHT);
    Serial.println("[MQTT] Subscribed to control topics");
}

// ═══════════════════════════════════════════════════
//  Non-blocking reconnect
// ═══════════════════════════════════════════════════
static bool mqttReconnect() {
    if (WiFi.status() != WL_CONNECTED) return false;

    Serial.println("[MQTT] Connecting to broker...");
    esp_task_wdt_reset();  // Feed watchdog during reconnect

    bool connected = false;
    if (strlen(MQTT_USER) > 0) {
        connected = _mqtt.connect(MQTT_CLIENT_ID, MQTT_USER, MQTT_PASS);
    } else {
        connected = _mqtt.connect(MQTT_CLIENT_ID);
    }

    if (connected) {
        Serial.println("[MQTT] Connected!");
        mqttSubscribe();
        return true;
    } else {
        Serial.printf("[MQTT] Connect failed, rc=%d — will retry\n", _mqtt.state());
        return false;
    }
}

// ═══════════════════════════════════════════════════
//  PUBLIC
// ═══════════════════════════════════════════════════

void mqtt_init(CommandHandler cmdHandler) {
    _mqttCmdHandler = cmdHandler;

    // TLS: skip certificate verification for simplicity
    // (HiveMQ Cloud uses Let's Encrypt; for production, pin the CA cert)
    _tlsClient.setInsecure();

    _mqtt.setServer(MQTT_BROKER, MQTT_PORT);
    _mqtt.setCallback(mqttCallback);
    _mqtt.setBufferSize(512);  // Larger buffer for state JSON

    Serial.printf("[MQTT] Configured for %s:%d\n", MQTT_BROKER, MQTT_PORT);
}

void mqtt_loop() {
    if (!_mqtt.connected()) {
        unsigned long now = millis();
        if ((now - _lastReconnectAttempt) >= RECONNECT_INTERVAL) {
            _lastReconnectAttempt = now;
            mqttReconnect();
        }
        return;
    }
    _mqtt.loop();
}

void mqtt_publishSensors(uint16_t smoke, float lux, bool present) {
    if (!_mqtt.connected()) return;

    char buf[16];

    snprintf(buf, sizeof(buf), "%u", smoke);
    _mqtt.publish(MQTT_T_SMOKE, buf);

    snprintf(buf, sizeof(buf), "%.1f", lux);
    _mqtt.publish(MQTT_T_LUX, buf);

    _mqtt.publish(MQTT_T_PRESENCE, present ? "true" : "false");
}

void mqtt_publishState() {
    if (!_mqtt.connected()) return;

    // Build state JSON matching phone app _parseFullState() expectations:
    // Keys: fan, light, socket, rgb, rgb_brightness, backup_brightness,
    //       smoke, lux, presence, mode
    StaticJsonDocument<384> doc;

    doc["fan"]              = hw_getRelay(1) ? "ON" : "OFF";
    doc["light"]            = hw_getRelay(0) ? "ON" : "OFF";
    doc["socket"]           = hw_getRelay(3) ? "ON" : "OFF";
    doc["rgb"]              = hw_getRelay(2) ? "ON" : "OFF";
    doc["rgb_brightness"]   = hw_getStripBrightness();
    doc["backup_brightness"]= hw_getFlashBrightness();
    doc["smoke"]            = sensors_getSmoke();
    doc["lux"]              = (double)sensors_getLux();
    doc["presence"]         = auto_isPresent();
    doc["mode"]             = (auto_getMode() == MODE_SLEEP) ? "sleep" : "awake";
    doc["cigs"]             = sensors_getCigarettes();
    doc["smoking"]          = smoke_isInCooldown();

    char buf[384];
    serializeJson(doc, buf, sizeof(buf));
    _mqtt.publish(MQTT_T_STATE, buf);
}

bool mqtt_isConnected() {
    return _mqtt.connected();
}

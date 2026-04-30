#include "webserver.h"
#include "config.h"
#include "hardware.h"
#include "smoke_tracker.h"
#include "automation.h"
#include "network.h"
#include "sensors.h"
#include "dashboard.h"

#include <ESPAsyncWebServer.h>
#include <ArduinoJson.h>

// ═══════════════════════════════════════════════════
//  Server & socket instances
// ═══════════════════════════════════════════════════
static AsyncWebServer  _server(80);
static AsyncWebSocket  _ws("/ws");
static CommandHandler  _cmdHandler = nullptr;

// ═══════════════════════════════════════════════════
//  Build current state JSON into a String
//  BUG-01/02/03 fix: uses thread-safe sensor getters
//  instead of calling hw_read*() directly
// ═══════════════════════════════════════════════════
static String buildStateJson() {
    StaticJsonDocument<512> doc;

    // Sensors — read from mutex-protected cache (no I2C race)
    float lux = sensors_getLux();
    bool luxOK = (lux >= 0);

    doc["lux"]       = luxOK ? (double)lux : (double)-1;
    doc["smoke"]     = sensors_getSmoke();
    doc["smokeDO"]   = sensors_getSmokeDO();
    doc["present"]   = auto_isPresent();
    doc["prox"]      = sensors_getProximity();
    doc["cigs"]      = sensors_getCigarettes();
    doc["calibrated"]= smoke_isCalibrated();
    doc["baseline"]  = smoke_getBaseline();
    doc["threshold"] = smoke_getThreshold();
    doc["smoking"]   = smoke_isInCooldown();

    // Relays
    JsonArray relays = doc.createNestedArray("relays");
    for (int i = 0; i < RELAY_COUNT; i++) relays.add(hw_getRelay(i));

    // Brightness
    doc["flash"] = hw_getFlashBrightness();
    doc["strip"] = hw_getStripBrightness();

    // Mode
    doc["mode"] = (auto_getMode() == MODE_SLEEP) ? "sleep" : "awake";

    // System
    doc["rssi"]   = net_getWifiRSSI();
    doc["ip"]     = net_getIP();
    doc["uptime"] = (unsigned long)(millis() / 1000);
    doc["heap"]   = ESP.getFreeHeap();

    String out;
    serializeJson(doc, out);
    return out;
}

// ═══════════════════════════════════════════════════
//  WebSocket event handler
// ═══════════════════════════════════════════════════
static void onWsEvent(AsyncWebSocket *server, AsyncWebSocketClient *client,
                      AwsEventType type, void *arg, uint8_t *data, size_t len) {
    switch (type) {
    case WS_EVT_CONNECT:
        Serial.printf("[WS] Client #%u connected from %s\n", client->id(),
                      client->remoteIP().toString().c_str());
        // Send initial state immediately
        client->text(buildStateJson());
        break;

    case WS_EVT_DISCONNECT:
        Serial.printf("[WS] Client #%u disconnected\n", client->id());
        break;

    case WS_EVT_DATA: {
        AwsFrameInfo *info = (AwsFrameInfo *)arg;
        if (info->final && info->index == 0 && info->len == len && info->opcode == WS_TEXT) {
            String msg;
            msg.reserve(len);
            for (size_t i = 0; i < len; ++i) {
                msg += (char)data[i];
            }
            if (_cmdHandler) _cmdHandler(msg);
        }
        break;
    }

    case WS_EVT_ERROR:
        Serial.printf("[WS] Client #%u error\n", client->id());
        break;

    case WS_EVT_PONG:
        break;
    }
}

// ═══════════════════════════════════════════════════
//  PUBLIC
// ═══════════════════════════════════════════════════

void ws_init(CommandHandler cmdHandler) {
    _cmdHandler = cmdHandler;

    // WebSocket
    _ws.onEvent(onWsEvent);
    _server.addHandler(&_ws);

    // Dashboard (serve embedded HTML)
    _server.on("/", HTTP_GET, [](AsyncWebServerRequest *request) {
        request->send_P(200, "text/html", DASHBOARD_HTML);
    });

    // REST API: full state
    _server.on("/api/state", HTTP_GET, [](AsyncWebServerRequest *request) {
        request->send(200, "application/json", buildStateJson());
    });

    // 404
    _server.onNotFound([](AsyncWebServerRequest *request) {
        request->send(404, "text/plain", "Not Found");
    });

    _server.begin();
    Serial.println("[WEB] HTTP server started on port 80");
}

void ws_broadcastState() {
    // Clean up stale connections
    _ws.cleanupClients(WS_MAX_CLIENTS);

    if (_ws.count() > 0) {
        String state = buildStateJson();
        _ws.textAll(state);
    }
}

void ws_setCommandHandler(CommandHandler h) {
    _cmdHandler = h;
}

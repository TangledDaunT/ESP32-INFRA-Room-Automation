#include "network.h"
#include "config.h"
#include "hardware.h"

#include <WiFi.h>
#include <ESPmDNS.h>
#include <ArduinoOTA.h>
#include <esp_task_wdt.h>
#include <ArduinoJson.h>

#if ENABLE_BLE
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#endif

// ═══════════════════════════════════════════════════
//  Internal state
// ═══════════════════════════════════════════════════
static unsigned long _lastReconnectAttempt = 0;
static bool          _wifiWasConnected     = false;

#if ENABLE_BLE
static BLEServer         *_bleServer    = nullptr;
static BLECharacteristic *_charState    = nullptr;
static BLECharacteristic *_charCmd      = nullptr;
static bool               _bleDeviceConnected = false;

// BLE command callback — wired via net_init(cmdHandler) (BUG-10 fix)
static CommandHandler _bleCmdCb = nullptr;

class ServerCallbacks : public BLEServerCallbacks {
    void onConnect(BLEServer *s)    override { _bleDeviceConnected = true;  Serial.println("[BLE] Client connected"); }
    void onDisconnect(BLEServer *s) override { _bleDeviceConnected = false; Serial.println("[BLE] Client disconnected"); s->startAdvertising(); }
};

class CmdCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *c) override {
        std::string val = c->getValue();
        if (val.length() > 0 && _bleCmdCb) {
            _bleCmdCb(String(val.c_str()));
        }
    }
};
#endif

// ═══════════════════════════════════════════════════
//  WiFi connection (non-blocking)
// ═══════════════════════════════════════════════════

static void wifi_connect() {
    Serial.printf("[NET] Connecting to WiFi: %s\n", WIFI_SSID);
    WiFi.mode(WIFI_STA);
    WiFi.setHostname(WIFI_HOSTNAME);
    WiFi.setAutoReconnect(true);
    WiFi.begin(WIFI_SSID, WIFI_PASS);
}

// ═══════════════════════════════════════════════════
//  PUBLIC
// ═══════════════════════════════════════════════════

void net_init(CommandHandler cmdHandler) {
    // ── WiFi ──
    wifi_connect();

    // Wait up to 10 s for initial connection (non-blocking afterwards)
    unsigned long start = millis();
    while (WiFi.status() != WL_CONNECTED && (millis() - start) < 10000) {
        delay(250);
        Serial.print(".");
        hw_setStatusLED((millis() / 250) % 2);  // Blink while connecting
    }
    Serial.println();

    if (WiFi.status() == WL_CONNECTED) {
        _wifiWasConnected = true;
        hw_setStatusLED(true);
        Serial.printf("[NET] WiFi connected — IP: %s\n", WiFi.localIP().toString().c_str());
    } else {
        Serial.println("[NET] WiFi connection timed out — will retry in background");
    }

    // ── mDNS ──
    if (MDNS.begin(WIFI_HOSTNAME)) {
        MDNS.addService("http", "tcp", 80);
        Serial.printf("[NET] mDNS started: http://%s.local\n", WIFI_HOSTNAME);
    }

    // ── OTA ──
    ArduinoOTA.setHostname(WIFI_HOSTNAME);
    ArduinoOTA.onStart([]() {
        String type = (ArduinoOTA.getCommand() == U_FLASH) ? "firmware" : "filesystem";
        Serial.printf("[OTA] Updating %s...\n", type.c_str());
    });
    ArduinoOTA.onEnd([]() {
        Serial.println("\n[OTA] Update complete — rebooting");
    });
    ArduinoOTA.onProgress([](unsigned int progress, unsigned int total) {
        Serial.printf("[OTA] %u%%\r", progress * 100 / total);
        esp_task_wdt_reset();
    });
    ArduinoOTA.onError([](ota_error_t error) {
        Serial.printf("[OTA] Error[%u]: ", error);
        if      (error == OTA_AUTH_ERROR)    Serial.println("Auth failed");
        else if (error == OTA_BEGIN_ERROR)   Serial.println("Begin failed");
        else if (error == OTA_CONNECT_ERROR) Serial.println("Connect failed");
        else if (error == OTA_RECEIVE_ERROR) Serial.println("Receive failed");
        else if (error == OTA_END_ERROR)     Serial.println("End failed");
    });
    ArduinoOTA.begin();

    // ── BLE ──
#if ENABLE_BLE
    // Wire the command callback (BUG-10 fix)
    _bleCmdCb = cmdHandler;

    BLEDevice::init(BLE_DEVICE_NAME);
    _bleServer = BLEDevice::createServer();
    _bleServer->setCallbacks(new ServerCallbacks());

    BLEService *service = _bleServer->createService(BLE_SERVICE_UUID);

    // State characteristic (read + notify)
    _charState = service->createCharacteristic(
        BLE_CHAR_STATE_UUID,
        BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
    );
    _charState->addDescriptor(new BLE2902());

    // Command characteristic (write)
    _charCmd = service->createCharacteristic(
        BLE_CHAR_CMD_UUID,
        BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR
    );
    _charCmd->setCallbacks(new CmdCallbacks());

    service->start();

    BLEAdvertising *adv = BLEDevice::getAdvertising();
    adv->addServiceUUID(BLE_SERVICE_UUID);
    adv->setScanResponse(true);
    adv->setMinPreferred(0x06);   // 7.5ms min connection interval (BUG-08 fix)
    adv->setMaxPreferred(0x12);   // 22.5ms max connection interval (BUG-08 fix)
    BLEDevice::startAdvertising();
    Serial.println("[BLE] Advertising started");
#else
    (void)cmdHandler;  // Suppress unused parameter warning when BLE disabled
#endif
}

void net_loop() {
    // ── OTA ──
    ArduinoOTA.handle();

    // ── WiFi reconnect ──
    unsigned long now = millis();
    if (WiFi.status() != WL_CONNECTED) {
        if ((now - _lastReconnectAttempt) >= WIFI_RECONNECT_MS) {
            _lastReconnectAttempt = now;
            Serial.println("[NET] WiFi lost — reconnecting...");
            WiFi.disconnect();
            WiFi.begin(WIFI_SSID, WIFI_PASS);
        }
        if (_wifiWasConnected) {
            hw_setStatusLED((now / 250) % 2);  // Blink when disconnected
        }
    } else {
        if (!_wifiWasConnected) {
            _wifiWasConnected = true;
            hw_setStatusLED(true);
            Serial.printf("[NET] WiFi reconnected — IP: %s\n", WiFi.localIP().toString().c_str());
        }
    }
}

bool   net_isWifiConnected() { return WiFi.status() == WL_CONNECTED; }
int    net_getWifiRSSI()     { return WiFi.RSSI(); }
String net_getIP()           { return WiFi.localIP().toString(); }

// ═══════════════════════════════════════════════════
//  BLE sensor push (GAP-3 fix)
//  Called from main loop every 2 s to notify phone app
// ═══════════════════════════════════════════════════
void net_blePushSensors(uint16_t smoke, float lux, bool present) {
#if ENABLE_BLE
    if (!_bleDeviceConnected || !_charState) return;

    StaticJsonDocument<128> doc;
    doc["smoke"]    = smoke;
    doc["lux"]      = (double)lux;
    doc["presence"] = present;

    char buf[128];
    serializeJson(doc, buf, sizeof(buf));
    _charState->setValue(buf);
    _charState->notify();
#else
    (void)smoke; (void)lux; (void)present;
#endif
}

// ═══════════════════════════════════════════════════
//  BLE state push — for immediate relay/brightness
//  change feedback to phone app
// ═══════════════════════════════════════════════════
void net_blePushState(const String &stateJson) {
#if ENABLE_BLE
    if (!_bleDeviceConnected || !_charState) return;
    _charState->setValue(stateJson.c_str());
    _charState->notify();
#else
    (void)stateJson;
#endif
}

bool net_isBleConnected() {
#if ENABLE_BLE
    return _bleDeviceConnected;
#else
    return false;
#endif
}

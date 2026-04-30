#include <Arduino.h>
#include <Preferences.h>
#include <ArduinoJson.h>
#include <esp_task_wdt.h>
#include <time.h>

#include "config.h"
#include "hardware.h"
#include "smoke_tracker.h"
#include "network.h"
#include "automation.h"
#include "webserver.h"
#include "sensors.h"
#include "mqtt_client.h"

// ═══════════════════════════════════════════════════
//  NVS persistent storage
// ═══════════════════════════════════════════════════
static Preferences prefs;
static bool        nvsDirty       = false;
static unsigned long lastNvsWrite = 0;

static void persistState() {
    prefs.putBool("r0", hw_getRelay(0));
    prefs.putBool("r1", hw_getRelay(1));
    prefs.putBool("r2", hw_getRelay(2));
    prefs.putBool("r3", hw_getRelay(3));
    prefs.putUChar("flash", hw_getFlashBrightness());
    prefs.putUChar("strip", hw_getStripBrightness());
    prefs.putInt("cigs", smoke_getCigaretteCount());
    prefs.putUChar("mode", (uint8_t)auto_getMode());
    Serial.println("[NVS] State persisted");
}

static void restoreState() {
    // Relays
    for (int i = 0; i < RELAY_COUNT; i++) {
        char key[4];
        snprintf(key, sizeof(key), "r%d", i);
        bool val = prefs.getBool(key, false);
        hw_setRelay(i, val);
    }
    // Brightness
    hw_setFlashBrightness(prefs.getUChar("flash", 0));
    hw_setStripBrightness(prefs.getUChar("strip", 0));
    // Cigarette count
    smoke_restoreCount(prefs.getInt("cigs", 0));
    // Mode
    uint8_t m = prefs.getUChar("mode", 0);
    if (m == MODE_SLEEP) auto_setMode(MODE_SLEEP);
    Serial.println("[NVS] State restored");
}

static void markDirty() {
    nvsDirty = true;
}

// ═══════════════════════════════════════════════════
//  Command handler (shared by WebSocket + BLE + MQTT)
// ═══════════════════════════════════════════════════
static void handleCommand(const String &json) {
    StaticJsonDocument<256> doc;
    DeserializationError err = deserializeJson(doc, json);
    if (err) {
        Serial.printf("[CMD] JSON parse error: %s\n", err.c_str());
        return;
    }

    // ── Original firmware format: {"cmd":"relay","ch":0,"val":true} ──
    const char *cmd = doc["cmd"];
    if (cmd) {
        if (strcmp(cmd, "relay") == 0) {
            int ch = doc["ch"] | -1;
            if (ch >= 0 && ch < RELAY_COUNT) {
                bool val = doc["val"] | false;
                hw_setRelay(ch, val);
                markDirty();
                Serial.printf("[CMD] Relay %d → %s\n", ch, val ? "ON" : "OFF");
            }
        } else if (strcmp(cmd, "flash") == 0) {
            int val = doc["val"] | 0;
            hw_setFlashBrightness(constrain(val, 0, 255));
            markDirty();
        } else if (strcmp(cmd, "strip") == 0) {
            int val = doc["val"] | 0;
            hw_setStripBrightness(constrain(val, 0, 255));
            markDirty();
        } else if (strcmp(cmd, "mode") == 0) {
            const char *m = doc["val"];
            if (m) {
                if (strcmp(m, "sleep") == 0)      auto_setMode(MODE_SLEEP);
                else if (strcmp(m, "awake") == 0)  auto_setMode(MODE_AWAKE);
                markDirty();
            }
        }
        return;  // Handled firmware format
    }

    // ── Phone app format (GAP-2): {"device":"fan","state":"ON"} ──
    //    or: {"device":"rgb","brightness":128}
    const char *device = doc["device"];
    if (device) {
        // Device → channel mapping:
        //   fan    → relay ch1
        //   light  → relay ch0
        //   socket → relay ch3
        //   rgb    → strip PWM (relay ch2 for 220V RGB power)
        //   backup → flash PWM

        if (strcmp(device, "fan") == 0) {
            const char *state = doc["state"];
            if (state) {
                hw_setRelay(1, strcmp(state, "ON") == 0);
                markDirty();
                Serial.printf("[CMD] Phone: fan → %s\n", state);
            }
        } else if (strcmp(device, "light") == 0) {
            const char *state = doc["state"];
            if (state) {
                hw_setRelay(0, strcmp(state, "ON") == 0);
                markDirty();
                Serial.printf("[CMD] Phone: light → %s\n", state);
            }
        } else if (strcmp(device, "socket") == 0) {
            const char *state = doc["state"];
            if (state) {
                hw_setRelay(3, strcmp(state, "ON") == 0);
                markDirty();
                Serial.printf("[CMD] Phone: socket → %s\n", state);
            }
        } else if (strcmp(device, "rgb") == 0) {
            // Can be state ON/OFF (relay ch2) or brightness
            if (doc.containsKey("brightness")) {
                int val = doc["brightness"] | 0;
                hw_setStripBrightness(constrain(val, 0, 255));
                markDirty();
                Serial.printf("[CMD] Phone: rgb brightness → %d\n", val);
            }
            if (doc.containsKey("state")) {
                const char *state = doc["state"];
                if (state) {
                    hw_setRelay(2, strcmp(state, "ON") == 0);
                    markDirty();
                    Serial.printf("[CMD] Phone: rgb relay → %s\n", state);
                }
            }
        } else if (strcmp(device, "backup") == 0) {
            if (doc.containsKey("brightness")) {
                int val = doc["brightness"] | 0;
                hw_setFlashBrightness(constrain(val, 0, 255));
                markDirty();
                Serial.printf("[CMD] Phone: backup brightness → %d\n", val);
            }
        } else if (strcmp(device, "mode") == 0) {
            const char *state = doc["state"];
            if (state) {
                if (strcmp(state, "sleep") == 0 || strcmp(state, "SLEEP") == 0)
                    auto_setMode(MODE_SLEEP);
                else if (strcmp(state, "awake") == 0 || strcmp(state, "AWAKE") == 0)
                    auto_setMode(MODE_AWAKE);
                markDirty();
            }
        }
        return;  // Handled phone app format
    }

    Serial.println("[CMD] Unknown command format");
}

// ═══════════════════════════════════════════════════
//  FreeRTOS sensor task (runs on Core 0)
// ═══════════════════════════════════════════════════
static SemaphoreHandle_t sensorMutex;

// Shared sensor cache (written by sensor task, read by main loop / webserver)
static volatile uint16_t g_smokeAnalog   = 0;
static volatile bool     g_smokeDigital  = false;
static volatile float    g_lux           = 0;
static volatile uint16_t g_proximity     = 0;
// BUG-09: cigarette count cached here under mutex for thread safety
static volatile int      g_cigaretteCount = 0;

// ═══════════════════════════════════════════════════
//  Thread-safe sensor getters (BUG-01/02/03/06 fix)
//  Used by webserver.cpp, automation.cpp, mqtt_client.cpp
// ═══════════════════════════════════════════════════
float sensors_getLux() {
    float v = -1;
    if (xSemaphoreTake(sensorMutex, pdMS_TO_TICKS(5))) {
        v = g_lux;
        xSemaphoreGive(sensorMutex);
    }
    return v;
}

uint16_t sensors_getSmoke() {
    uint16_t v = 0;
    if (xSemaphoreTake(sensorMutex, pdMS_TO_TICKS(5))) {
        v = g_smokeAnalog;
        xSemaphoreGive(sensorMutex);
    }
    return v;
}

bool sensors_getSmokeDO() {
    bool v = false;
    if (xSemaphoreTake(sensorMutex, pdMS_TO_TICKS(5))) {
        v = g_smokeDigital;
        xSemaphoreGive(sensorMutex);
    }
    return v;
}

uint16_t sensors_getProximity() {
    uint16_t v = 0;
    if (xSemaphoreTake(sensorMutex, pdMS_TO_TICKS(5))) {
        v = g_proximity;
        xSemaphoreGive(sensorMutex);
    }
    return v;
}

int sensors_getCigarettes() {
    int v = 0;
    if (xSemaphoreTake(sensorMutex, pdMS_TO_TICKS(5))) {
        v = g_cigaretteCount;
        xSemaphoreGive(sensorMutex);
    }
    return v;
}

// ═══════════════════════════════════════════════════
//  Sensor task function (Core 0)
// ═══════════════════════════════════════════════════
static void sensorTaskFn(void *param) {
    unsigned long lastMq2   = 0;
    unsigned long lastApds  = 0;

    for (;;) {
        unsigned long now = millis();

        // ── MQ2 at 1 Hz ──
        if (now - lastMq2 >= SENSOR_READ_INTERVAL) {
            uint16_t smoke = hw_readSmokeAnalog();
            bool     smokeDO = hw_readSmokeDigital();

            if (xSemaphoreTake(sensorMutex, pdMS_TO_TICKS(10))) {
                g_smokeAnalog  = smoke;
                g_smokeDigital = smokeDO;
                xSemaphoreGive(sensorMutex);
            }

            // Feed the smoke tracker
            smoke_feed(smoke);

            // Update cached cigarette count under mutex (BUG-09 fix)
            if (xSemaphoreTake(sensorMutex, pdMS_TO_TICKS(10))) {
                g_cigaretteCount = smoke_getCigaretteCount();
                xSemaphoreGive(sensorMutex);
            }

            lastMq2 = now;
        }

        // ── APDS-9930 at 2 Hz ──
        if (now - lastApds >= APDS_READ_INTERVAL) {
            float lux = 0;
            uint16_t prox = 0;
            hw_readLux(lux);
            hw_readProximity(prox);

            if (xSemaphoreTake(sensorMutex, pdMS_TO_TICKS(10))) {
                g_lux       = lux;
                g_proximity = prox;
                xSemaphoreGive(sensorMutex);
            }

            lastApds = now;
        }

        vTaskDelay(pdMS_TO_TICKS(50));  // Yield to system tasks
    }
}

// ═══════════════════════════════════════════════════
//  NTP midnight reset for cigarette counter
// ═══════════════════════════════════════════════════
static int _lastResetDay = -1;

static void checkMidnightReset() {
    struct tm ti;
    if (!getLocalTime(&ti, 0)) return;  // NTP not synced yet

    if (_lastResetDay < 0) {
        _lastResetDay = ti.tm_yday;  // First sync — record current day
        return;
    }

    if (ti.tm_yday != _lastResetDay) {
        smoke_resetDaily();
        _lastResetDay = ti.tm_yday;
        markDirty();
        Serial.println("[NTP] Midnight — daily counter reset");
    }
}

// ═══════════════════════════════════════════════════
//  Arduino entry points
// ═══════════════════════════════════════════════════

void setup() {
    Serial.begin(115200);
    delay(500);
    Serial.println("\n═══════════════════════════════════════");
    Serial.println("  Room Control — ESP32 Firmware v2.0");
    Serial.println("═══════════════════════════════════════");

    // ── NVS ──
    prefs.begin("room", false);

    // ── Hardware ──
    hw_init();

    // ── Smoke tracker ──
    smoke_init();

    // ── Restore saved state ──
    restoreState();

    // ── Automation ──
    auto_init();

    // ── Network (WiFi + mDNS + OTA + BLE) ──
    // BUG-10 fix: pass handleCommand so BLE commands are routed
    net_init(handleCommand);

    // ── NTP ──
    configTime(NTP_GMT_OFFSET_SEC, NTP_DST_OFFSET_SEC, NTP_SERVER);
    Serial.println("[NTP] Time sync started");

    // ── Web server + WebSocket ──
    ws_init(handleCommand);

    // ── MQTT ──
    mqtt_init(handleCommand);

    // ── Sensor task on Core 0 ──
    sensorMutex = xSemaphoreCreateMutex();
    xTaskCreatePinnedToCore(
        sensorTaskFn,
        "sensors",
        4096,       // Stack size (bytes)
        NULL,       // Parameter
        1,          // Priority
        NULL,       // Task handle
        0           // Core 0 (network stack also here but OK at low priority)
    );

    // ── Watchdog ──
    esp_task_wdt_init(WDT_TIMEOUT_SEC, true);
    esp_task_wdt_add(NULL);

    // BUG-07 fix: initialise lastNvsWrite to current time to prevent
    // spurious NVS write in the first 5 seconds of boot
    lastNvsWrite = millis();

    Serial.println("[BOOT] Setup complete\n");
}

void loop() {
    unsigned long now = millis();

    // ── Feed watchdog ──
    esp_task_wdt_reset();

    // ── Fade animations (must run every iteration for smoothness) ──
    hw_updateFades();

    // ── Automation engine ──
    auto_update();

    // ── Network housekeeping (OTA + WiFi reconnect) ──
    net_loop();

    // ── MQTT loop ──
    mqtt_loop();

    // ── WebSocket broadcast (every 500 ms) ──
    static unsigned long lastBroadcast = 0;
    if (now - lastBroadcast >= WS_BROADCAST_INTERVAL) {
        ws_broadcastState();
        lastBroadcast = now;
    }

    // ── BLE sensor push (every 2 s — GAP-3) ──
    static unsigned long lastBlePush = 0;
    if (now - lastBlePush >= 2000) {
        if (net_isBleConnected()) {
            net_blePushSensors(sensors_getSmoke(), sensors_getLux(), auto_isPresent());
        }
        lastBlePush = now;
    }

    // ── MQTT sensor + state publish (every 2 s) ──
    static unsigned long lastMqttPub = 0;
    if (now - lastMqttPub >= MQTT_PUBLISH_MS) {
        if (mqtt_isConnected()) {
            mqtt_publishSensors(sensors_getSmoke(), sensors_getLux(), auto_isPresent());
            mqtt_publishState();
        }
        lastMqttPub = now;
    }

    // ── NVS persist (debounced — only after 5 s of no changes) ──
    if (nvsDirty && (now - lastNvsWrite) >= NVS_PERSIST_DEBOUNCE) {
        persistState();
        nvsDirty     = false;
        lastNvsWrite = now;
    }

    // ── Midnight cigarette counter reset ──
    static unsigned long lastMidnightCheck = 0;
    if (now - lastMidnightCheck >= 60000) {  // Check every minute
        checkMidnightReset();
        lastMidnightCheck = now;
    }

    // ── Yield to RTOS (1 ms tick — keeps fade smooth at ~1000 fps) ──
    delay(1);
}

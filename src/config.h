#pragma once

// ═══════════════════════════════════════════════════
//  WiFi & Network
// ═══════════════════════════════════════════════════
#define WIFI_SSID               "1706-2.4G"
#define WIFI_PASS               "12345678@"
#define WIFI_HOSTNAME           "shreyansh"    // http://shreyansh.local
#define WIFI_RECONNECT_MS       30000          // 30 s

// ═══════════════════════════════════════════════════
//  BLE
// ═══════════════════════════════════════════════════
#define ENABLE_BLE              true
#define BLE_DEVICE_NAME         "OpenClaw_ESP32"
#define BLE_SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define BLE_CHAR_CMD_UUID       "beb5483e-36e1-4688-b7f5-ea07361b26a8"  // WRITE  (phone app writes here)
#define BLE_CHAR_STATE_UUID     "beb5483e-36e1-4688-b7f5-ea07361b26a9"  // READ+NOTIFY (phone app listens here)

// ═══════════════════════════════════════════════════
//  Pin Definitions
// ═══════════════════════════════════════════════════

// MQ-2 Smoke Sensor
#define PIN_MQ2_AO              34   // ADC1_CH6 — input-only, works with WiFi
#define PIN_MQ2_DO              35   // Digital threshold output — input-only

// 4-Channel Relay Module (Active LOW)
#define PIN_RELAY_1             26   // Main Lights
#define PIN_RELAY_2             27   // Fan
#define PIN_RELAY_3             14   // 220 V RGB Light
#define PIN_RELAY_4             25   // Charging Socket
#define RELAY_COUNT             4

// D4184 MOSFET PWM
#define PIN_MOSFET_FLASH        32   // Flashlight
#define PIN_MOSFET_STRIP        33   // LED Strip

// RCWL-0516 Microwave Radar
#define PIN_RADAR               4

// TTP223 Capacitive Touch
#define PIN_TOUCH               5

// APDS-9930 (I2C)
#define PIN_I2C_SDA             21
#define PIN_I2C_SCL             22
#define APDS9930_I2C_ADDR       0x39

// Onboard Status LED
#define PIN_STATUS_LED          2

// ═══════════════════════════════════════════════════
//  PWM (LEDC)
// ═══════════════════════════════════════════════════
#define PWM_FREQ_HZ             5000  // 5 kHz — safe for D4184 optocoupler
#define PWM_RESOLUTION_BITS     8     // 0-255
#define PWM_CHANNEL_FLASH       0
#define PWM_CHANNEL_STRIP       1

// ═══════════════════════════════════════════════════
//  Timing (milliseconds unless noted)
// ═══════════════════════════════════════════════════
#define SENSOR_READ_INTERVAL    1000   // MQ2 sample rate
#define APDS_READ_INTERVAL      500    // Lux + proximity
#define WS_BROADCAST_INTERVAL   500    // WebSocket push rate
#define RADAR_DEBOUNCE_MS       500    // Reject sub-500 ms blips
#define TOUCH_DEBOUNCE_MS       300
#define PROXIMITY_COOLDOWN_MS   1500   // Min time between prox triggers
#define NVS_PERSIST_DEBOUNCE    5000   // Batch NVS writes

// ═══════════════════════════════════════════════════
//  Automation
// ═══════════════════════════════════════════════════
#define RADAR_ABSENCE_TIMEOUT   300000 // 5 min → mark room empty
#define FADE_IN_DURATION        2000   // Premium entry fade (ms)
#define FADE_OUT_DURATION       3000   // Exit fade (ms)
#define TOUCH_FADE_DURATION     1500   // TTP223 slow PWM ramp
#define PROXIMITY_THRESHOLD     200    // 0-1023, tune empirically
#define STRIP_DIM_BRIGHTNESS    50     // Night / sleep brightness
#define STRIP_DEFAULT_BRIGHTNESS 200   // Default full brightness

// ═══════════════════════════════════════════════════
//  MQ-2 Smoke Tracker
// ═══════════════════════════════════════════════════
#define MQ2_CALIBRATION_MS      120000 // 2-minute calibration window
#define MQ2_WARMUP_MS           30000  // First 30 s discarded
#define MQ2_SAMPLE_INTERVAL     1000   // 1 Hz sampling
#define MQ2_ADC_OVERSAMPLE      32     // Samples per reading
#define MQ2_SPIKE_SIGMA         3.0f   // Threshold = baseline + 3σ
#define MQ2_SPIKE_CONFIRM_SEC   10     // Sustained spike → cigarette
#define MQ2_COOLDOWN_MS         180000 // 3 min between counts

// ═══════════════════════════════════════════════════
//  NTP (IST — UTC+5:30)
// ═══════════════════════════════════════════════════
#define NTP_SERVER              "pool.ntp.org"
#define NTP_GMT_OFFSET_SEC      19800
#define NTP_DST_OFFSET_SEC      0

// ═══════════════════════════════════════════════════
//  WebSocket
// ═══════════════════════════════════════════════════
#define WS_MAX_CLIENTS          4

// ═══════════════════════════════════════════════════
//  Watchdog
// ═══════════════════════════════════════════════════
#define WDT_TIMEOUT_SEC         30

// ═══════════════════════════════════════════════════
//  MQTT (HiveMQ Cloud — TLS on port 8883)
// ═══════════════════════════════════════════════════
#define MQTT_BROKER         "7c7d7ed342c14133aa64550393a6e17e.s1.eu.hivemq.cloud"
#define MQTT_PORT           8883
#define MQTT_USER           "shreyanshesp"
#define MQTT_PASS           "Shreyanshesp32"
#define MQTT_CLIENT_ID      "openclaw_esp32"

// MQTT Topics (matching phone app defaults)
#define MQTT_T_FAN              "openclaw/control/fan"
#define MQTT_T_LIGHT            "openclaw/control/light"
#define MQTT_T_SOCKET           "openclaw/control/socket"
#define MQTT_T_RGB              "openclaw/control/rgb"
#define MQTT_T_RGB_BRIGHT       "openclaw/control/rgb/brightness"
#define MQTT_T_BACKUP_BRIGHT    "openclaw/control/backup/brightness"
#define MQTT_T_SMOKE            "openclaw/sensors/smoke"
#define MQTT_T_LUX              "openclaw/sensors/lux"
#define MQTT_T_PRESENCE         "openclaw/sensors/presence"
#define MQTT_T_STATE            "openclaw/state"
#define MQTT_PUBLISH_MS         2000

// ═══════════════════════════════════════════════════
//  NVS Schema
// ═══════════════════════════════════════════════════
#define NVS_SCHEMA_VERSION      2

// ═══════════════════════════════════════════════════
//  Automation — Lux daylight gate
// ═══════════════════════════════════════════════════
#define LUX_DAYLIGHT_THRESHOLD  150

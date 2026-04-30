/*
 * OpenClaw ESP32 Firmware Reference
 * ─────────────────────────────────
 * Add this BLE layer on top of your existing MQTT code.
 * 
 * Required libraries:
 *   - ArduinoJson
 *   - PubSubClient (already in your project)
 *   - ESP32 BLE Arduino (built-in with esp32 board package)
 * 
 * Board: ESP32 Dev Module
 */

#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <ArduinoJson.h>

// ── WiFi / MQTT (fill in your values) ────────────────────
const char* WIFI_SSID = "YOUR_WIFI_SSID";
const char* WIFI_PASS = "YOUR_WIFI_PASSWORD";
const char* MQTT_BROKER = "192.168.1.100";  // Your broker IP
const int   MQTT_PORT   = 1883;

// ── MQTT Topics (must match app settings) ────────────────
const char* T_FAN             = "openclaw/control/fan";
const char* T_LIGHT           = "openclaw/control/light";
const char* T_SOCKET          = "openclaw/control/socket";
const char* T_RGB             = "openclaw/control/rgb";
const char* T_RGB_BRIGHTNESS  = "openclaw/control/rgb/brightness";
const char* T_BACKUP_BRIGHT   = "openclaw/control/backup/brightness";
const char* T_SMOKE           = "openclaw/sensors/smoke";
const char* T_LUX             = "openclaw/sensors/lux";
const char* T_PRESENCE        = "openclaw/sensors/presence";
const char* T_STATE           = "openclaw/state";

// ── GPIO Pins (match your existing wiring) ────────────────
#define PIN_RELAY_FAN     21
#define PIN_RELAY_LIGHT   13
#define PIN_RELAY_SOCKET  14
#define PIN_MOSFET_RGB    12    // PWM capable
#define PIN_MOSFET_BACKUP 26    // PWM capable
#define PIN_MQ2_ANALOG    34
#define PIN_LUX_ANALOG    35    // Or I2C if you use BH1750
#define PIN_RADAR         27    // HIGH = presence detected

// ── LEDC PWM Channels ─────────────────────────────────────
#define PWM_CH_RGB    0
#define PWM_CH_BACKUP 1
#define PWM_FREQ      1000
#define PWM_RES       8    // 8-bit = 0-255

// ── BLE UUIDs (must match ble_service.dart) ───────────────
#define SERVICE_UUID     "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CMD_CHAR_UUID    "beb5483e-36e1-4688-b7f5-ea07361b26a8"   // WRITE
#define SENSOR_CHAR_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a9"   // NOTIFY

// ── State ─────────────────────────────────────────────────
bool fanState    = false;
bool lightState  = false;
bool socketState = false;
bool rgbState    = false;
int  rgbBrightness    = 128;
int  backupBrightness = 0;

WiFiClient wifiClient;
PubSubClient mqttClient(wifiClient);

BLEServer*         pServer      = nullptr;
BLECharacteristic* cmdChar      = nullptr;
BLECharacteristic* sensorChar   = nullptr;
bool bleConnected = false;

unsigned long lastSensorPublish = 0;
const unsigned long SENSOR_INTERVAL_MS = 2000;

// ── BLE Connection callbacks ───────────────────────────────
class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* s)    { bleConnected = true; }
  void onDisconnect(BLEServer* s) {
    bleConnected = false;
    // Restart advertising so app can reconnect
    BLEDevice::getAdvertising()->start();
  }
};

// ── BLE Command received from app ─────────────────────────
class CmdCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) {
    std::string value = c->getValue();
    if (value.empty()) return;

    StaticJsonDocument<128> doc;
    DeserializationError err = deserializeJson(doc, value.c_str());
    if (err) return;

    const char* device = doc["device"];
    if (!device) return;

    String dev = String(device);

    if (dev == "fan") {
      fanState = String(doc["state"].as<const char*>()) == "ON";
      digitalWrite(PIN_RELAY_FAN, fanState ? LOW : HIGH); // Active LOW
      mqttClient.publish(T_FAN, fanState ? "ON" : "OFF", true);
    }
    else if (dev == "light") {
      lightState = String(doc["state"].as<const char*>()) == "ON";
      digitalWrite(PIN_RELAY_LIGHT, lightState ? LOW : HIGH);
      mqttClient.publish(T_LIGHT, lightState ? "ON" : "OFF", true);
    }
    else if (dev == "socket") {
      socketState = String(doc["state"].as<const char*>()) == "ON";
      digitalWrite(PIN_RELAY_SOCKET, socketState ? LOW : HIGH);
      mqttClient.publish(T_SOCKET, socketState ? "ON" : "OFF", true);
    }
    else if (dev == "rgb") {
      if (doc.containsKey("state")) {
        rgbState = String(doc["state"].as<const char*>()) == "ON";
        if (!rgbState) ledcWrite(PWM_CH_RGB, 255); // Active-LOW MOSFET, 255 = off
      }
      if (doc.containsKey("brightness")) {
        rgbBrightness = doc["brightness"].as<int>();
        // Active-LOW: invert PWM value
        ledcWrite(PWM_CH_RGB, rgbState ? (255 - rgbBrightness) : 255);
        char buf[8]; itoa(rgbBrightness, buf, 10);
        mqttClient.publish(T_RGB_BRIGHTNESS, buf, true);
      }
    }
    else if (dev == "backup") {
      if (doc.containsKey("brightness")) {
        backupBrightness = doc["brightness"].as<int>();
        ledcWrite(PWM_CH_BACKUP, 255 - backupBrightness); // Active-LOW
        char buf[8]; itoa(backupBrightness, buf, 10);
        mqttClient.publish(T_BACKUP_BRIGHT, buf, true);
      }
    }
  }
};

// ── MQTT Callback ──────────────────────────────────────────
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String msg;
  for (unsigned int i = 0; i < length; i++) msg += (char)payload[i];
  String t = String(topic);

  if (t == T_FAN) {
    fanState = msg == "ON";
    digitalWrite(PIN_RELAY_FAN, fanState ? LOW : HIGH);
  }
  else if (t == T_LIGHT) {
    lightState = msg == "ON";
    digitalWrite(PIN_RELAY_LIGHT, lightState ? LOW : HIGH);
  }
  else if (t == T_SOCKET) {
    socketState = msg == "ON";
    digitalWrite(PIN_RELAY_SOCKET, socketState ? LOW : HIGH);
  }
  else if (t == T_RGB) {
    rgbState = msg == "ON";
    ledcWrite(PWM_CH_RGB, rgbState ? (255 - rgbBrightness) : 255);
  }
  else if (t == T_RGB_BRIGHTNESS) {
    rgbBrightness = msg.toInt();
    if (rgbState) ledcWrite(PWM_CH_RGB, 255 - rgbBrightness);
  }
  else if (t == T_BACKUP_BRIGHT) {
    backupBrightness = msg.toInt();
    ledcWrite(PWM_CH_BACKUP, 255 - backupBrightness);
  }
}

// ── Sensor reading ─────────────────────────────────────────
void publishSensors() {
  int smokeRaw  = analogRead(PIN_MQ2_ANALOG);
  int luxRaw    = analogRead(PIN_LUX_ANALOG);
  bool presence = digitalRead(PIN_RADAR) == HIGH;

  // Map raw ADC (0-4095) to reasonable ranges
  float smokeVal = smokeRaw * (1000.0 / 4095.0);
  float luxVal   = luxRaw   * (1000.0 / 4095.0);

  // Publish to MQTT
  char buf[16];
  dtostrf(smokeVal, 4, 1, buf);
  mqttClient.publish(T_SMOKE, buf);

  dtostrf(luxVal, 4, 1, buf);
  mqttClient.publish(T_LUX, buf);

  mqttClient.publish(T_PRESENCE, presence ? "PRESENT" : "AWAY");

  // Also notify via BLE if connected
  if (bleConnected && sensorChar != nullptr) {
    StaticJsonDocument<128> doc;
    doc["smoke"]    = smokeVal;
    doc["lux"]      = luxVal;
    doc["presence"] = presence;

    char json[128];
    serializeJson(doc, json);
    sensorChar->setValue(json);
    sensorChar->notify();
  }

  // Publish full state JSON for app sync
  StaticJsonDocument<256> state;
  state["fan"]               = fanState ? "ON" : "OFF";
  state["light"]             = lightState ? "ON" : "OFF";
  state["socket"]            = socketState ? "ON" : "OFF";
  state["rgb"]               = rgbState ? "ON" : "OFF";
  state["rgb_brightness"]    = rgbBrightness;
  state["backup_brightness"] = backupBrightness;
  state["smoke"]             = smokeVal;
  state["lux"]               = luxVal;
  state["presence"]          = presence;

  char stateJson[256];
  serializeJson(state, stateJson);
  mqttClient.publish(T_STATE, stateJson, true);
}

void connectWifi() {
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  while (WiFi.status() != WL_CONNECTED) delay(500);
}

void connectMqtt() {
  while (!mqttClient.connected()) {
    if (mqttClient.connect("openclaw_esp32")) {
      mqttClient.subscribe(T_FAN);
      mqttClient.subscribe(T_LIGHT);
      mqttClient.subscribe(T_SOCKET);
      mqttClient.subscribe(T_RGB);
      mqttClient.subscribe(T_RGB_BRIGHTNESS);
      mqttClient.subscribe(T_BACKUP_BRIGHT);
    } else {
      delay(3000);
    }
  }
}

void setupBLE() {
  BLEDevice::init("OpenClaw_ESP32");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService* pService = pServer->createService(SERVICE_UUID);

  cmdChar = pService->createCharacteristic(
      CMD_CHAR_UUID, BLECharacteristic::PROPERTY_WRITE);
  cmdChar->setCallbacks(new CmdCallbacks());

  sensorChar = pService->createCharacteristic(
      SENSOR_CHAR_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  sensorChar->addDescriptor(new BLE2902());

  pService->start();

  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->start();
}

void setup() {
  Serial.begin(115200);

  // Relay pins (active LOW)
  pinMode(PIN_RELAY_FAN,    OUTPUT); digitalWrite(PIN_RELAY_FAN,    HIGH);
  pinMode(PIN_RELAY_LIGHT,  OUTPUT); digitalWrite(PIN_RELAY_LIGHT,  HIGH);
  pinMode(PIN_RELAY_SOCKET, OUTPUT); digitalWrite(PIN_RELAY_SOCKET, HIGH);

  // PWM (active-LOW MOSFET — start at 255 = off)
  ledcSetup(PWM_CH_RGB,    PWM_FREQ, PWM_RES);
  ledcSetup(PWM_CH_BACKUP, PWM_FREQ, PWM_RES);
  ledcAttachPin(PIN_MOSFET_RGB,    PWM_CH_RGB);
  ledcAttachPin(PIN_MOSFET_BACKUP, PWM_CH_BACKUP);
  ledcWrite(PWM_CH_RGB,    255);
  ledcWrite(PWM_CH_BACKUP, 255);

  // Radar
  pinMode(PIN_RADAR, INPUT);

  connectWifi();
  mqttClient.setServer(MQTT_BROKER, MQTT_PORT);
  mqttClient.setCallback(mqttCallback);
  connectMqtt();

  setupBLE();
}

void loop() {
  if (!mqttClient.connected()) connectMqtt();
  mqttClient.loop();

  unsigned long now = millis();
  if (now - lastSensorPublish >= SENSOR_INTERVAL_MS) {
    lastSensorPublish = now;
    publishSensors();
  }
}

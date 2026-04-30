# OpenClaw Remote — Flutter Android App

A full JARVIS-style room control panel for Samsung Galaxy J6 (Android 8+).

---

## Features

| Feature | Details |
|---|---|
| Device Control | Fan, Main Light, Socket, RGB Strip — tap to toggle |
| Brightness Sliders | RGB Strip + Backup Light (PWM 0–255) |
| Sensors | Real-time Smoke (MQ-2), Lux, Presence (Microwave Radar) |
| Idle Screen | Clock, date, sensors — tap to wake |
| Always-On Display | Screen never sleeps |
| Double Clap | Day: toggle RGB; Night: toggle all lights (slowly) |
| Intimacy Mode | RGB brightness reacts to mic volume peaks |
| Night Mode | Auto-dims at set time or low lux |
| Sleep Detection | Lux + MQ-2 + presence + lights-off timer |
| Wake-Up Routine | PWM ramp before alarm, notifies OpenClaw when done |
| Absence Detection | Turns off all devices when room is empty |
| MQTT | Full bidirectional sync with ESP32 and OpenClaw |
| BLE | Direct ESP32 connection for low-latency sensor streaming |
| HTTP | REST API sync with OpenClaw backend |
| Settings | Every parameter configurable in-app |

---

## Project Structure

```
lib/
  main.dart                   ← App entry, wakelock, nav shell, idle timer
  theme.dart                  ← Black sci-fi color palette
  models/
    app_settings.dart         ← All configurable parameters
    device_state.dart         ← Full device + sensor state model
  providers/
    device_provider.dart      ← Central brain: automation, MQTT, BLE, HTTP
    settings_provider.dart    ← Persists settings to SharedPreferences
  services/
    mqtt_service.dart         ← MQTT connect, subscribe, publish, reconnect
    ble_service.dart          ← BLE scan, connect, send commands, receive sensors
    openclaw_service.dart     ← HTTP REST client for OpenClaw backend
    clap_service.dart         ← Mic-based double clap detection (always on)
    sleep_service.dart        ← Sleep state machine (lux + MQ2 + presence + time)
    wakeup_service.dart       ← Scheduled PWM ramp + wake routine
  screens/
    idle_screen.dart          ← Sci-fi clock/sensor HUD
    control_screen.dart       ← Main control panel
    settings_screen.dart      ← All settings, time pickers
  widgets/
    device_button.dart        ← Glowing toggle buttons
    sensor_card.dart          ← Sensor display, presence indicator, connection dots
esp32_firmware.ino            ← ESP32 BLE + MQTT firmware reference
```

---

## Setup

### 1. Flutter Setup

```bash
flutter pub get
flutter run
```

Target SDK: Android 8.0+ (API 26+) — Galaxy J6 runs Android 8/9.

### 2. First Launch

Open the app → tap **SETTINGS** → configure:

- **MQTT Broker**: Your broker IP (HiveMQ or local Mosquitto)
- **OpenClaw Base URL**: `http://YOUR_LAPTOP_IP:PORT`
- **ESP32 BLE Device Name**: `OpenClaw_ESP32` (or whatever you named it)
- **Wake-up Time**, Night Mode hours, thresholds

Tap **SAVE SETTINGS**.

### 3. ESP32 Firmware

Open `esp32_firmware.ino` in Arduino IDE.

Fill in:
```cpp
const char* WIFI_SSID = "your_ssid";
const char* WIFI_PASS = "your_password";
const char* MQTT_BROKER = "192.168.x.x";
```

Verify GPIO pins match your wiring, then upload.

The ESP32 will:
- Connect to WiFi + MQTT
- Advertise BLE as `OpenClaw_ESP32`
- Publish sensor JSON every 2 seconds via BLE notify + MQTT
- Accept commands from both MQTT and BLE

---

## OpenClaw Backend API Contract

The app expects these endpoints on your FastAPI backend:

| Method | Path | Description |
|---|---|---|
| GET | `/health` | Returns 200 if alive |
| GET | `/state` | Returns full device state JSON |
| POST | `/control/{device}` | `{"state": "ON"\|"OFF"}` |
| POST | `/control/{device}/brightness` | `{"brightness": 0-255}` |
| POST | `/wakeup/done` | Wake-up routine complete notification |
| POST | `/sleep/state` | `{"state": "sleeping"\|"nightMode"\|"awake"}` |
| POST | `/settings/wakeup` | `{"hour": 7, "minute": 0}` |

State JSON response format:
```json
{
  "fan": "ON",
  "light": "OFF",
  "socket": "OFF",
  "rgb": "ON",
  "rgb_brightness": 128,
  "backup_brightness": 0,
  "smoke": 245.5,
  "lux": 12.3,
  "presence": true
}
```

---

## MQTT Topics (defaults, all configurable)

| Topic | Direction | Payload |
|---|---|---|
| `openclaw/control/fan` | Pub/Sub | `ON` \| `OFF` |
| `openclaw/control/light` | Pub/Sub | `ON` \| `OFF` |
| `openclaw/control/socket` | Pub/Sub | `ON` \| `OFF` |
| `openclaw/control/rgb` | Pub/Sub | `ON` \| `OFF` |
| `openclaw/control/rgb/brightness` | Pub/Sub | `0`–`255` |
| `openclaw/control/backup/brightness` | Pub/Sub | `0`–`255` |
| `openclaw/sensors/smoke` | Subscribe | float ppm |
| `openclaw/sensors/lux` | Subscribe | float lux |
| `openclaw/sensors/presence` | Subscribe | `PRESENT` \| `AWAY` |
| `openclaw/state` | Subscribe | Full state JSON |
| `openclaw/wakeup/done` | Publish | JSON notification |

---

## Clap Automation Logic

| Situation | Double Clap Result |
|---|---|
| **Day**, RGB off | Slowly ramp RGB 0→255 over 3 seconds |
| **Day**, RGB on | Slowly fade RGB 255→0 over 2 seconds |
| **Night**, lights on | Fade RGB off, then turn off main light |
| **Night**, lights off | Slowly ramp RGB to 50% (128) over 3 seconds |

Night is determined by **both** time window AND lux threshold (whichever triggers first).

---

## Sleep Detection Logic

The app transitions through these states:

```
awake → nightMode → possiblySleeping → sleeping → wakingUp → awake
```

**Sleeping** is detected when ALL of:
- It's night time (or lux < threshold)
- Lights have been off for `sleepDetectionMinutes`
- Either MQ-2 elevated (CO2 from breathing) OR lux is very low

**Away** is detected when:
- No presence for `presenceAbsenceMinutes` → all devices off
- When presence returns → main light turns on automatically

---

## Permissions Required

- `RECORD_AUDIO` — clap detection + intimacy mode
- `BLUETOOTH` / `BLUETOOTH_SCAN` / `BLUETOOTH_CONNECT` — BLE to ESP32
- `ACCESS_FINE_LOCATION` — required for BLE scan on Android < 12
- `FOREGROUND_SERVICE` — clap detection runs even when app is in background
- `WAKE_LOCK` — keep screen on
- `INTERNET` — MQTT + HTTP

All permissions are requested at runtime on first launch.

# OpenClaw Remote — Flutter Android App

A full-featured, always-on smart-room control panel for Android (optimised for Samsung Galaxy J6 in landscape mode).  
The app connects to an ESP32 running the OpenClaw firmware over **WebSocket / HTTP REST** and orchestrates lights, fans, RGB, sensors, sleep detection, wake-up routines, and real-time mic-driven music mode — all from a single dashboard.

---

## Features

| Feature | Details |
|---|---|
| **Device Control** | Fan, Main Light, Socket, RGB Strip — tap to toggle |
| **Brightness Sliders** | RGB Strip + Backup/Flash Light (PWM 0–255) |
| **Sensors** | Real-time Smoke (MQ-2 ppm), Lux, Presence (Microwave Radar) |
| **Idle / Clock Screen** | OLED-optimised clock, date, sensor HUD — tap anywhere to wake |
| **Always-On Display** | Screen never sleeps (`WakelockPlus`) |
| **Double-Clap Automation** | Double clap turns on all devices and ramps RGB to full brightness |
| **Smoke Alarm** | When MQ-2 crosses the threshold, the app plays an alarm sound, flashes the RGB strip, and exposes a dismiss action |
| **Activity Log** | Shows commands, sensor events, alarms, and automations inside the app |
| **Laptop History Sync** | Can POST activity history wirelessly to a receiver running on your Ubuntu laptop |
| **Music Mode** | RGB brightness reacts live to mic volume (exponential smoothing, 15+ fps via WebSocket) |
| **Night Mode** | Auto-dims at a configurable time or low-lux threshold |
| **Sleep Detection** | Lux + MQ-2 + presence + lights-off timer drive a 5-state machine |
| **Wake-Up Routine** | Scheduled PWM ramp before alarm; notifies firmware when complete |
| **Absence Detection** | Turns off all devices when room is empty for configurable duration |
| **WebSocket** | Low-latency bidirectional sync with ESP32 firmware (`/ws`) |
| **HTTP REST** | Command dispatch (`POST /api/cmd`) with WebSocket fallback |
| **Settings** | Every parameter configurable in-app and persisted via SharedPreferences |

---

## Communication Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    Flutter App (Android)                  │
│                                                          │
│   DeviceProvider ──► OpenClawService                     │
│                        │                                 │
│                        ├── WebSocket  ws://<ip>/ws       │
│                        │   (state push, music-mode cmd)  │
│                        │                                 │
│                        └── HTTP POST  /api/cmd           │
│                            (relay toggle, brightness,    │
│                             mode changes)                │
└──────────────────────────────────────────────────────────┘
                          │  ▲
                     cmd  │  │  state JSON
                          ▼  │
                    ┌──────────────┐
                    │  ESP32       │
                    │  OpenClaw    │
                    │  Firmware    │
                    └──────────────┘
```

**Transport decision:**
- Normal commands → `HTTP POST /api/cmd` (3-second timeout, WebSocket fallback)
- High-frequency updates (music mode) → `WebSocket` (`sendWsCommand`) — no UI rebuild on each tick
- State reception → always WebSocket push from firmware, auto-reconnects every 2 seconds

---

## Project Structure

```
Phone App/
├── pubspec.yaml
└── lib/
    ├── main.dart                    ← App entry: wakelock, landscape lock, foreground task, routing
    ├── theme.dart                   ← Dark sci-fi palette (Manrope font, glassmorphism tokens)
    │
    ├── models/
    │   ├── app_settings.dart        ← All configurable parameters (wake-up time, thresholds, URL, …)
    │   └── device_state.dart        ← Full device + sensor state model (DeviceState, SleepState, ConnectionStatus)
    │
    ├── providers/
    │   ├── device_provider.dart     ← Central brain: automation, clap, sleep, wake-up, music mode
    │   └── settings_provider.dart   ← Persists AppSettings to SharedPreferences
    │
    ├── services/
    │   ├── openclaw_service.dart    ← WebSocket connect/reconnect, HTTP POST /api/cmd
    │   ├── clap_detector.dart       ← Mic-based double-clap detection (always on, foreground service)
    │   ├── audio_service.dart       ← Raw microphone capture + FFT (used by clap + music mode)
    │   ├── sleep_service.dart       ← Sleep state machine (awake → nightMode → possiblySleeping → sleeping → wakingUp)
    │   └── wakeup_service.dart      ← Scheduled PWM ramp + wake routine
    │
    ├── screens/
    │   ├── idle_screen.dart         ← OLED clock/sensor HUD (tap to return to control)
    │   ├── control_screen.dart      ← Main control panel
    │   └── settings_screen.dart     ← All settings, time pickers, URL config
    │
    └── widgets/
        ├── device_button.dart       ← Glowing toggle buttons with animation
        ├── brightness_slider.dart   ← Full-height vertical PWM sliders
        ├── sensor_card.dart         ← Sensor display with connection status dots
        ├── speedometer_dial.dart    ← Animated gauge for lux / sensor visualisation
        ├── lux_dial.dart            ← Dedicated lux gauge widget
        ├── glass_container.dart     ← Reusable glassmorphism container
        ├── settings_row.dart        ← Labelled settings row scaffold
        └── time_picker_sheet.dart   ← Bottom-sheet time picker
```

---

## Setup

### 1. Install Dependencies

```bash
cd "Phone App"
flutter pub get
```

Target SDK: **Android 8.0+ (API 26+)**.  
The app is optimised for landscape-only display (Galaxy J6 / similar desk-mount tablets).

### 2. First Launch — Configure Settings

Open the app → tap **SETTINGS** and fill in:

| Setting | Description |
|---|---|
| **ESP32 Base URL** | `http://192.168.1.30` — IP of your ESP32 on the LAN |
| **Wake-Up Time** | Hour + minute for the morning PWM ramp |
| **Night Mode Hours** | Start / end hours for automatic night mode |
| **Lux Threshold** | Below this → night mode activates |
| **Smoke Alarm Threshold** | MQ-2 ppm value that triggers alarm |
| **Presence Absence Minutes** | Idle time before "away" mode kicks in |
| **Sleep Detection Minutes** | Lights-off duration before app declares "sleeping" |
| **Clap Window (ms)** | Time window for a double-clap to be recognised |
| **History Sync URL** | Optional Ubuntu receiver URL for saving logs wirelessly, e.g. `http://<laptop-ip>:8765/log` |

Tap **SAVE** — settings are persisted across restarts.

### 3. ESP32 Firmware

The app expects the ESP32 running the **OpenClaw PlatformIO firmware** (`src/` in the repo root).

Key firmware requirements:
- Exposes `ws://<ip>/ws` — pushes full state JSON on every change
- Exposes `POST /api/cmd` — accepts JSON command objects
- Relay channel mapping: `r0=Light`, `r1=Fan`, `r2=RGB`, `r3=Socket`

Build and flash:
```bash
# From repo root
pio run -t upload
```

---

## API / Command Protocol

### HTTP `POST /api/cmd`

All commands are JSON objects sent to the firmware:

| Command | Payload |
|---|---|
| Toggle relay | `{"cmd": "relay", "ch": 0, "val": true}` |
| Set strip brightness | `{"cmd": "strip", "val": 200}` |
| Set flash (backup) brightness | `{"cmd": "flash", "val": 128}` |
| Set mode | `{"cmd": "mode", "val": "normal"}` |
| All off | `{"cmd": "all_off"}` |
| All on | `{"cmd": "all_on"}` |

Relay channel mapping:

| ch | Device |
|---|---|
| 0 | Main Light |
| 1 | Fan |
| 2 | RGB Strip |
| 3 | Socket |

### WebSocket State Push (`ws://<ip>/ws`)

The firmware pushes a JSON state object after every change:

```json
{
  "relays": [true, false, true, false],
  "strip": 200,
  "flash": 0,
  "present": true,
  "smoke": 142.5,
  "lux": 38.2
}
```

Field mapping (firmware → app):

| Firmware key | App field | Notes |
|---|---|---|
| `relays[0]` | `lightOn` | |
| `relays[1]` | `fanOn` | |
| `relays[2]` | `rgbOn` | |
| `relays[3]` | `socketOn` | |
| `strip` | `rgbBrightness` | 0–255 |
| `flash` | `backupBrightness` | 0–255 |
| `present` | `presenceDetected` | |
| `smoke` | `smokeValue` | ppm (float) |
| `lux` | `luxValue` | lux (float) |

---

## Automation Logic

### Double-Clap

A double clap detected by the mic triggers:
- Fan **ON**, Light **ON**, Socket **ON**, RGB **ON**
- RGB brightness slowly ramps from current value → 255 over 1.5 seconds (30-step PWM ramp)

Single clap shows a brief visual indicator on-screen only.

### Music Mode

When Music Mode is active:
1. `AudioService` captures mic input continuously.
2. dB level is smoothed with an exponential moving average (`α = 0.3`).
3. 40 dB (quiet) → brightness 20; 90 dB (loud) → brightness 255.
4. Brightness is sent via **WebSocket** (`sendWsCommand`) at the native audio callback rate — **no UI rebuild on each tick**.
5. The ESP32 hardware fade engine interpolates each step over 100 ms for smooth transitions.

### Sleep State Machine

```
awake ──► nightMode ──► possiblySleeping ──► sleeping ──► wakingUp ──► awake
```

| Transition | Condition |
|---|---|
| awake → nightMode | Time in night window OR lux < threshold |
| nightMode → possiblySleeping | Lights off for `sleepDetectionMinutes` |
| possiblySleeping → sleeping | Elevated MQ-2 (CO₂ from breathing) OR very low lux |
| sleeping → wakingUp | Scheduled wake-up time reached |
| wakingUp → awake | PWM ramp complete |

**Night mode side effect:** Main light turns off, RGB dims to 50% (brightness 128).

### Absence Detection

- Presence sensor reports `AWAY` for `presenceAbsenceMinutes` → all devices turn off.
- Presence returns → main light turns on automatically.

### Wake-Up Routine

- At the configured wake-up time, RGB turns on and brightness ramps from 0 → 255 smoothly.
- Main light turns on at the end of the ramp.
- Sleep service is forced back to `awake`.

---

## Android Permissions

| Permission | Reason |
|---|---|
| `RECORD_AUDIO` | Clap detection + Music Mode mic input |
| `FOREGROUND_SERVICE` | Clap detection runs when app is backgrounded |
| `WAKE_LOCK` | Screen always on |
| `INTERNET` | WebSocket + HTTP to ESP32 |

## Wireless History Receiver

Run the lightweight receiver on Ubuntu if you want the app's activity log and remote command history saved on your laptop:

```bash
python3 tools/history_receiver.py
```

Then set the app's **History Sync URL** to:

```text
http://<your-ubuntu-ip>:8765/log
```

All permissions are requested at runtime on first launch.

---

## Key Dependencies

| Package | Purpose |
|---|---|
| `provider` | State management (`DeviceProvider`, `SettingsProvider`) |
| `web_socket_channel` | WebSocket client (`OpenClawService`) |
| `http` | HTTP REST commands |
| `record` | Microphone capture |
| `fftea` | FFT for audio analysis (Music Mode / clap) |
| `flutter_foreground_task` | Always-on foreground service for clap detection |
| `wakelock_plus` | Prevent screen sleep |
| `shared_preferences` | Persist settings |
| `google_fonts` | Typography (Manrope + Google Fonts) |
| `material_symbols_icons` | Icon set |
| `intl` | Date/time formatting |
| `permission_handler` | Runtime permission requests |

---

## Build & Run

```bash
# Development
cd "Phone App"
flutter pub get
flutter run

# Release APK
flutter build apk --release
```

The APK targets `arm64-v8a` and `armeabi-v7a` by default (covers Galaxy J6 and most modern Android devices).

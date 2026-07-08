# ESP32-INFRA — Room Automation

A full-stack IoT room automation system built around an **ESP32 hub**, a **Flutter Android app**, and a set of **Python helper services**. It controls mains-voltage relays and DC lighting, reacts to motion/touch/gas/light sensors, and syncs state in real time across Wi-Fi (HTTP/WebSocket), Bluetooth LE, and MQTT (HiveMQ Cloud) — so the room can be controlled locally, from the app, or from anywhere over LTE.

---

## ✨ Features

- **4-channel relay control** — main lights, ceiling fan, 220V RGB light, charging socket (all active-LOW).
- **Dual PWM dimming** — backup flashlight and a 12/24V LED strip, 8-bit resolution at 5 kHz.
- **Sensor fusion** — RCWL-0516 radar (presence), APDS-9930 (ambient light + proximity), MQ-2 (smoke/gas), TTP223 touch keys.
- **Smoke/cigarette detection** — custom DSP tracker (`smoke_tracker.cpp`) using calibrated baselines, sigma-spike detection, and cooldowns.
- **Clap-to-toggle** — mic-based clap detector in the Flutter app using RMS gating + FFT (2–4 kHz signature), run inside a Dart Isolate so the UI never lags.
- **Sleep/wake automation** — presence-aware routines (e.g. fading up the RGB strip on wake).
- **"Intimacy mode"** — ambient dB sensing to trigger a dimmed, pulsing atmosphere.
- **Triple transport sync** — WebSocket (local dashboard), BLE (offline/local control), and MQTT (remote control), all speaking the same JSON command dialect.
- **Persistent state** — relay/PWM/mode state survives reboots via ESP32 NVS.

---

## 🗂 Repository Layout

```
.
├── src/               # ESP32 firmware (PlatformIO / Arduino framework) — entry: src/main.cpp
├── Phone_App/         # Flutter Android app — entry: Phone_App/lib/main.dart
├── server/            # Python helper services (voice, alarm sync, integrations)
├── docs/              # Design notes and architecture docs
├── tools/             # Misc dev tooling
├── platformio.ini     # PlatformIO build config
├── merge_ino.py       # Firmware source merge helper
├── AGENTS.md          # Agent/change playbooks
├── PROJECT_CONTEXT.md # Full hardware + firmware + app context (source of truth)
└── CLAUDE.md          # AI coding assistant guidance
```

---

## 🔧 Hardware

| Component | Role |
|---|---|
| ESP32 DEV Module | Central hub — Wi-Fi, BLE, MQTT, HTTP server, GPIO |
| 5V 4-Channel Relay Board (Active LOW) | Switches mains-voltage appliances |
| TTP223 Touch Key Module ×2 | Capacitive touch input |
| CJMCU APDS-9930 (I2C) | Ambient light (lux) + proximity |
| RCWL-0516 Microwave Radar | Motion/presence detection (through obstacles) |
| MQ-2 Gas Sensor | Smoke / combustible gas detection |
| D4184 MOSFET Boards ×2 | High-current PWM dimming for 12/24V DC lighting |
| LM2596 2A Buck Converter | Steps down to safe logic voltages, has LED voltmeter |

### Pin Assignments

| Pin / Interface | Function | Notes |
|---|---|---|
| `GPIO 26` | Relay 1 — Main Lights | Active LOW |
| `GPIO 27` | Relay 2 — Ceiling Fan | Active LOW |
| `GPIO 14` | Relay 3 — 220V RGB Light | Active LOW |
| `GPIO 25` | Relay 4 — Charging Socket | Active LOW |
| `GPIO 32` | MOSFET 1 — Backup Flashlight | 5 kHz PWM (LEDC ch. 0), 8-bit |
| `GPIO 33` | MOSFET 2 — LED Strip | 5 kHz PWM (LEDC ch. 1), 8-bit |
| `GPIO 4`  | RCWL-0516 Radar | Digital in, HIGH on motion |
| `GPIO 5`  | TTP223 Touch Sensor | Digital in |
| `GPIO 21` | I2C SDA (APDS-9930) | — |
| `GPIO 22` | I2C SCL (APDS-9930) | — |
| `GPIO 34` | MQ-2 Analog Out | ADC1_CH6 (input only) |
| `GPIO 35` | MQ-2 Digital Out | Digital threshold interrupt |
| `GPIO 2`  | Onboard Status LED | — |

> ⚠️ **Relays and PWM are safety-critical.** Relays are wired **active LOW** — pulling a pin low turns mains voltage **ON**. Never invert this logic without deliberately re-wiring. PWM is capped at **5 kHz**; going higher will overheat the D4184 MOSFET boards.

---

## 🧠 Firmware Architecture (`src/`, C++ / PlatformIO)

| File | Responsibility |
|---|---|
| `main.cpp` | Startup sequence (hardware init → NVS restore → automation → network → WebSocket), main non-blocking loop, unified command entry via `handleCommand(String json)` |
| `hardware.cpp/.h` | GPIO reads/writes, PWM init, sensor polling |
| `network.cpp` / `mqtt_client.cpp` | Wi-Fi reconnects, mDNS (`shreyansh.local`), AsyncWebServer, HiveMQ TLS MQTT |
| `automation.cpp` | Local state machine — radar-absence timeout, touch fading, sleep transitions |
| `smoke_tracker.cpp` | DSP-based cigarette/smoke detection via MQ-2 |

**Invariants:**
- Persistent NVS keys: `r0`, `r1`, `r2`, `r3`, `flash`, `strip`, `cigs`, `mode` — don't rename without a migration path.
- `src/config.h` currently holds Wi-Fi credentials — don't commit further secrets alongside it.

---

## 📱 Flutter App (`Phone_App/`)

The mobile app is the system's **state authority**, reconciling events from MQTT, BLE, WebSocket, and the on-device clap detector.

- **State management**: `lib/providers/device_provider.dart` (`DeviceProvider`) is the single source of truth, coordinating `MqttService`, `OpenClawService`, `BleService`, and `ClapDetector`.
- **Models**: `DeviceState` (relay booleans, PWM ints, sensor floats, connectivity status), `AppSettings` (broker config, sleep/wake hours, clap sensitivity).
- **Clap detection**: 16 kHz PCM mic stream → RMS spike gate → FFT (via `fftea`) on 2–4 kHz band, run in a Dart Isolate. Double clap toggles main lights; single clap shows an animated overlay.
- **Foreground service**: `flutter_foreground_task` + WakeLocks keep mic processing alive when the screen is off/locked.

---

## 🌐 Communication Protocols

All three transports share one JSON command dialect:

```json
{ "command": "toggle_relay", "pin": 26, "state": 1 }
```
```json
{ "command": "set_pwm", "channel": 1, "value": 150 }
```

| Transport | Use case |
|---|---|
| HTTP / WebSocket | Local dashboard at `http://shreyansh.local`, state pushed every ~500ms |
| BLE | Custom GATT service, one write characteristic (commands), one notify characteristic (state) |
| MQTT (HiveMQ Cloud) | Remote control over LTE — subscribes `openclaw/control/#`, publishes `openclaw/state` and `openclaw/sensors/#` |

---

## 🚀 Quick Start

### Firmware (from repo root)
```bash
pio run                        # build
pio run -t upload              # flash (OTA by default — see platformio.ini)
pio device monitor -b 115200   # serial monitor
```

### Flutter app
```bash
cd Phone_App
flutter pub get
flutter run
flutter test
```

### Server
```bash
cd server
bash setup.sh                          # one-time setup
python3 friday_integration_server.py
```

---

## 📍 Where to Edit

- Firmware command handling / main loop → [`src/main.cpp`](src/main.cpp)
- Build config → [`platformio.ini`](platformio.ini)
- Flutter state authority → [`Phone_App/lib/providers/device_provider.dart`](Phone_App/lib/providers/device_provider.dart)
- Flutter transport service → [`Phone_App/lib/services/openclaw_service.dart`](Phone_App/lib/services/openclaw_service.dart)

## 📚 Further Reading

- [`PROJECT_CONTEXT.md`](PROJECT_CONTEXT.md) — full hardware, firmware, and protocol reference (source of truth for this doc)
- [`AGENTS.md`](AGENTS.md) — playbooks for AI coding agents working on this repo
- [`Phone_App/README.md`](Phone_App/README.md) — app-specific setup and notes

---

## 🤝 Contributing

Keep changes small and focused, and verify builds before opening a PR:
- **Firmware**: `pio run` from the repo root
- **App**: `cd Phone_App && flutter test`

When adding or changing a command/state field, update the firmware's `handleCommand(...)`, the WebSocket state broadcast, and the Flutter provider/models together.

### Agent rules (see `PROJECT_CONTEXT.md` §5 for full detail)
1. Never alter relay-inversion logic unless explicitly instructed.
2. Don't refactor architecture unless asked — keep the `handleCommand` boundary intact.
3. Never raise PWM frequency above 5 kHz.
4. Keep the phone app's scrollable layout — no rigid fixed widths.
5. Don't block the clap-detector isolate; FFT only runs after a cheap RMS spike.

---

## 📄 License

No license currently specified. Add a `LICENSE` file to set terms for reuse.

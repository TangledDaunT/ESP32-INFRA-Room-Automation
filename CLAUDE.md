# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Authoritative references

Read these before non-trivial changes — do not duplicate them here:

- `AGENTS.md` — primary agent playbook: where to edit, change playbooks, validation checklist, NVS/relay invariants.
- `PROJECT_CONTEXT.md` — full hardware pinout, sensor list, MQTT topics, JSON payload examples.
- `Phone App/README.md` — Flutter app feature list, sleep state machine, *current* HTTP/WS command shape, dependency list.
- `docs/architecture_voice_commands.md` — phone ↔ laptop Friday voice/Spotify integration diagram.

## Three components, one repo

This is **not** a single application. Three deployables sit side by side and share a JSON command dialect:

1. **ESP32 firmware** — `src/` (PlatformIO, Arduino framework). Hub: relays, PWM, sensors, MQTT/WS/HTTP/BLE. Entry: `src/main.cpp` (`setup()` ordering and `handleCommand(...)` are load-bearing).
2. **Flutter Android app** — `Phone App/` (always-on landscape dashboard for a Galaxy J6). State authority is `Phone App/lib/providers/device_provider.dart`; transport in `Phone App/lib/services/openclaw_service.dart`.
3. **Laptop "Friday" server** — `server/` (Python, runs on the Ubuntu laptop). HTTP endpoints for voice hooks, Spotify, alarm sync, sleep/wakeup brightness. Entry: `server/friday_integration_server.py`; install via `server/setup.sh` (writes a hook token to `~/.friday/.hook_token`).

A small history sink also lives in `tools/history_receiver.py` (port 8765) — the app POSTs activity logs there when configured.

## Build & run

The repo root path contains a space (`ESP 32 INFRA`) — always quote it.

```bash
# Firmware (from repo root)
pio run                        # build
pio run -t upload              # flash — see OTA note below
pio device monitor -b 115200   # serial monitor

# Flutter app (from "Phone App/")
flutter pub get
flutter run
flutter test
flutter test test/<file>_test.dart    # single test file

# Friday laptop server (from server/)
bash setup.sh                  # one-time
python3 friday_integration_server.py   # default port 41263
```

**OTA is the default upload path.** `platformio.ini` pins `upload_protocol = espota` to `192.168.1.15` with auth flag `--auth=openclaw-ota-2024`. `pio run -t upload` will **not** touch USB unless you override these; if the ESP32 is unreachable on that IP, the upload will hang/fail rather than fall back. Switch to USB by passing `--upload-port /dev/...` or temporarily editing `platformio.ini`.

## Command JSON — current shape

`Phone App/README.md` is canonical and supersedes the older `{"command": "toggle_relay", ...}` form documented in `PROJECT_CONTEXT.md` §4.2. The shape in use today is the short form:

```json
{"cmd": "relay",  "ch": 0, "val": true}     // ch: 0=light 1=fan 2=rgb 3=socket
{"cmd": "strip",  "val": 200}                // RGB strip PWM 0–255
{"cmd": "flash",  "val": 128}                // backup flashlight PWM
{"cmd": "mode",   "val": "normal"}
{"cmd": "all_off"} | {"cmd": "all_on"}
```

All transports (HTTP `POST /api/cmd`, WebSocket `/ws`, BLE, MQTT) speak this same dialect. When changing a command, update firmware `handleCommand(...)`, the WS state broadcast, and the Flutter `DeviceProvider` + models together.

## Hard invariants (don't break silently)

- **Relays are active LOW.** Writing `0` to a relay GPIO turns mains ON.
- **PWM ceiling is 5 kHz** (D4184 MOSFET optocoupler limit). Don't raise it.
- **NVS keys** `r0..r3`, `flash`, `strip`, `cigs`, `mode` are persisted — renaming requires a migration in firmware.
- **Brightness range is 0–255 everywhere** (firmware, WS payload, app models, UI sliders).
- **Clap detector runs in a Dart isolate** and FFT only fires after a cheap RMS spike — don't move FFT to the hot path or block the isolate.
- **`src/config.h` contains real WiFi credentials.** Don't commit additional secrets; prefer local-only overrides.

## Repo state notes

- `OpenClawFirmware/`, `RoomControl/`, and `Phone App/esp32_firmware/` were emptied in commit `451b364` (June 2026). Treat these as deleted; the live firmware is `src/`. `AGENTS.md` still calls them "legacy trees" — that's now outdated but harmless.
- There is no root `README.md`; the closest is `Phone App/README.md`.
- A second instruction file `agent.md` (lowercase) exists alongside `AGENTS.md`. If they disagree, `AGENTS.md` is newer.

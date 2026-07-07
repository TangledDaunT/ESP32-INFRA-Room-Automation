# Project Initialization Status

## Repository Overview
- **Firmware**: PlatformIO (ESP32) in `src/`
- **Mobile App**: Flutter (Android) in `Phone App/`
- **Key Files Analyzed**:
  - `src/main.cpp`: Main firmware loop and command handling.
  - `src/config.h`: Hardware pins and network settings.
  - `Phone App/lib/providers/device_provider.dart`: App state and service orchestration.
  - `Phone App/README.md`: App documentation and API contracts.

## Current State
- [x] Analyze codebase structure.
- [x] Read primary firmware logic.
- [x] Read primary app logic.
- [x] Run `flutter pub get` in `Phone App/`.
- [ ] Verify firmware build (`pio run`).
- [ ] Run app tests.

## Identified Components
- **Sensors**: MQ2 (Smoke), APDS-9930 (Lux/Prox), RCWL-0516 (Radar), TTP223 (Touch).
- **Actuators**: 4-Channel Relay (Fan, Light, Socket, RGB Power), PWM MOSFETs (Flash, Strip).
- **Communication**: MQTT (HiveMQ Cloud), BLE (OpenClaw_ESP32), WebSockets, mDNS (`shreyansh.local`).
- **App Features**: Idle screen, Clap automation, Intimacy mode, Sleep/Away detection.

## Notes
- Relays are active LOW.
- NVS keys: `r0-r3`, `flash`, `strip`, `cigs`, `mode`.
- App-side command format: `{"device": "...", "state": "...", "brightness": ...}`.

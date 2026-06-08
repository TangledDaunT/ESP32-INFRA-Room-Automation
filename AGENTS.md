# AGENTS.md

Agent instructions for this workspace (ESP32 PlatformIO firmware + Flutter Android control app).

## Scope
- Firmware lives in `src/` and is built with PlatformIO.
- Mobile app lives in `Phone App/` and is built with Flutter.

## Read First
- App feature and protocol details: [Phone App/README.md](Phone%20App/README.md)
- Firmware runtime orchestration: [src/main.cpp](src/main.cpp)
- Hardware and timing constants: [src/config.h](src/config.h)
- App orchestration and lifecycle: [Phone App/lib/main.dart](Phone%20App/lib/main.dart)
- App integration hub (MQTT/BLE/HTTP/automation): [Phone App/lib/providers/device_provider.dart](Phone%20App/lib/providers/device_provider.dart)

## Phone App Connection Path
- The Android app resolves the ESP32 base URL from `AppSettings` and uses [Phone App/lib/services/openclaw_service.dart](Phone%20App/lib/services/openclaw_service.dart) as the transport layer.
- `DeviceProvider` is the app-side control hub: UI actions, clap automation, sleep/wakeup routines, and music mode all funnel into it before they reach the ESP32.
- Normal control uses HTTP `POST /api/cmd`; state sync uses WebSocket `ws://<host>/ws`.
- High-frequency brightness updates can go over WebSocket, while normal relay and mode changes prefer HTTP with WebSocket fallback.
- Keep relay channel mapping consistent with the firmware and app docs: `0=light`, `1=fan`, `2=rgb`, `3=socket`.
- When changing command payloads or state fields, update the app provider/service and the firmware together; the JSON contract is shared.
- For protocol details, prefer linking to [Phone App/README.md](Phone%20App/README.md) instead of repeating payload tables here.

## Build and Run Commands
Run from workspace root unless noted.

### ESP32 (PlatformIO)
- `pio run`
- `pio run -t upload`
- `pio device monitor -b 115200`

### Flutter App
Run inside `Phone App/`.
- `flutter pub get`
- `flutter run`
- `flutter test`

## Architecture Boundaries
- Firmware startup order is coordinated in `setup()` in [src/main.cpp](src/main.cpp): hardware -> restore persisted state -> automation -> network -> websocket -> sensor task.
- Firmware main loop responsibilities in [src/main.cpp](src/main.cpp): watchdog reset, fade updates, automation tick, network housekeeping, websocket state broadcast, debounced NVS persistence, midnight reset.
- Command ingestion on firmware is unified through `handleCommand(...)` in [src/main.cpp](src/main.cpp). Keep JSON command shape compatible when changing app-side command payloads.
- Flutter app state authority is `DeviceProvider` in [Phone App/lib/providers/device_provider.dart](Phone%20App/lib/providers/device_provider.dart). MQTT, BLE, OpenClaw HTTP, clap automation, sleep/wakeup flows are coordinated there.

## Conventions and Expectations
- Keep relay semantics consistent: relay module is active LOW (see comments in [src/config.h](src/config.h)).
- Keep brightness range in 0-255 across firmware and Flutter payloads.
- Preserve topic-driven behavior; topic names come from app settings, not hardcoded in multiple places.
- Prefer additive changes to `DeviceState` and `AppSettings` models before wiring UI and services.
- Maintain debounce/interval semantics in firmware timing constants unless explicitly retuning behavior.

## Common Pitfalls
- Do not break persisted keys in firmware NVS (`r0..r3`, `flash`, `strip`, `cigs`, `mode`) in [src/main.cpp](src/main.cpp) unless a migration is added.
- `src/config.h` currently contains real WiFi credentials; avoid committing additional secrets and prefer local overrides for sensitive values.
- BLE and MQTT can both update state; avoid feedback loops when adding new command pathways in `DeviceProvider`.
- Android permissions are extensive for BLE + microphone foreground service; preserve required entries in [Phone App/android/app/src/main/AndroidManifest.xml](Phone%20App/android/app/src/main/AndroidManifest.xml) when refactoring mobile features.

## Change Playbooks
- New firmware command:
  1. Extend command handling in [src/main.cpp](src/main.cpp) `handleCommand(...)`.
  2. Apply hardware/automation logic in relevant `src/*.cpp` module.
  3. Ensure websocket state includes the new state field.
  4. Update app provider/service payload producers and consumers.

- New app control/sensor field:
  1. Add field to models in `Phone App/lib/models/`.
  2. Update parse/update logic in [Phone App/lib/providers/device_provider.dart](Phone%20App/lib/providers/device_provider.dart).
  3. Update UI screen/widgets under `Phone App/lib/screens/` and `Phone App/lib/widgets/`.
  4. Verify MQTT topic mapping and BLE/OpenClaw sync behavior.

## Validation Checklist
- Firmware builds with `pio run`.
- App resolves dependencies (`flutter pub get`) and launches (`flutter run`).
- For protocol changes: verify command roundtrip over both MQTT and BLE paths.
- For timing changes: verify no watchdog issues and no excessive NVS writes.

## For AI coding agents
- **Goal:** Make minimal, well-tested changes; prefer linking to existing docs rather than copying them.
- **Build & test:** Use the commands in the **Build and Run Commands** section. Firmware: run `pio run` from the workspace root. App: `cd Phone App && flutter pub get && flutter test`.
- **Where to edit:** Firmware source in `src/` (see [src/main.cpp](src/main.cpp)); app code in `Phone App/lib/` (see [Phone App/lib/providers/device_provider.dart](Phone%20App/lib/providers/device_provider.dart)).
- **Key invariants:** Do NOT change persisted NVS keys (`r0..r3`, `flash`, `strip`, `cigs`, `mode`) without adding a migration. Keep relay semantics (active LOW) and brightness range (0–255) consistent.
- **Secrets:** `src/config.h` currently contains real WiFi credentials — never commit additional secrets. Prefer local overrides and .env-like mechanisms.
- **Cross-path effects:** When adding commands or state fields: update firmware `handleCommand(...)`, include state in websocket broadcasts, and update the Flutter `DeviceProvider` and models (`Phone App/lib/models/`).
- **Communications:** Verify changes over all transport paths (MQTT, BLE, WebSocket, OpenClaw HTTP) to avoid feedback loops.
- **PRs & commits:** Keep changes small and focused. Include build verification steps in PR description (how to run `pio run`, where to run Flutter tests).
- **When unsure:** Link to relevant files in this document and ask for clarification before modifying hardware-related timing or NVS keys.

---

If you'd like, I can also create a compact `.github/copilot-instructions.md` or specialized skills for release tasks, CI checks, or firmware migration helpers.

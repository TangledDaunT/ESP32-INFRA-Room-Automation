# ESP32-INFRA — Room Automation

A compact repository containing the ESP32 firmware, a Flutter Android control app, and helper server components for a room automation system.

Repository layout
- `src/` — ESP32 firmware (PlatformIO / Arduino framework). Entry: `src/main.cpp`.
- `Phone_App/` — Flutter Android app (UI, providers, transport). App entry: `Phone_App/lib/main.dart`.
- `server/` — Python helper services (voice, alarm sync, integrations).
- `docs/` — design notes and architecture docs.
- `AGENTS.md`, `PROJECT_CONTEXT.md`, `CLAUDE.md` — agent and project guidance.

Quick start

Firmware (from repository root):
```bash
pio run
# flash (uses OTA by default; see `platformio.ini`)
pio run -t upload
pio device monitor -b 115200
```

Flutter app (inside `Phone_App/`):
```bash
cd Phone_App
flutter pub get
flutter run
flutter test
```

Server (inside `server/`):
```bash
cd server
bash setup.sh    # one-time
python3 friday_integration_server.py
```

Important invariants
- Relays are active LOW — writing GPIO low turns mains ON.
- Brightness / PWM ranges: 0–255 everywhere (firmware, app, WS payloads).
- PWM ceiling: 5 kHz (hardware limitation).
- Persistent NVS keys: `r0`, `r1`, `r2`, `r3`, `flash`, `strip`, `cigs`, `mode`. Do not rename without a migration.
- `src/config.h` currently contains Wi‑Fi credentials; do not commit additional secrets.

Where to edit
- Firmware command handling and main loop: [src/main.cpp](src/main.cpp)
- PlatformIO configuration: [platformio.ini](platformio.ini)
- Flutter state authority / provider: [Phone_App/lib/providers/device_provider.dart](Phone_App/lib/providers/device_provider.dart)
- Flutter transport service: [Phone_App/lib/services/openclaw_service.dart](Phone_App/lib/services/openclaw_service.dart)

Notes and references
- Read the agent playbook and change playbooks: [AGENTS.md](AGENTS.md)
- Hardware, pinout, and protocol details: [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md)
- App-specific README and mobile notes: [Phone_App/README.md](Phone_App/README.md)

Contributing
- Keep changes small and focused. Verify builds before opening a PR:
  - Firmware: run `pio run` from the repo root.
  - App: run `cd Phone_App && flutter test`.
- When adding or changing command/state fields, update firmware `handleCommand(...)`, the websocket state broadcast, and the Flutter provider/models together.

License
- No license specified. Add a `LICENSE` file if you want to set project licensing.

Questions or next steps
- Want me to run a firmware build, add a `LICENSE`, or prepare a minimal CI job? Reply with which one and I’ll proceed.

# Repository Guidelines

## Project Structure & Module Organization
This repository contains the OpenClaw Flutter control app and a local ESP32 firmware target. Flutter source lives in `lib/`, with screens in `lib/screens/`, providers in `lib/providers/`, services in `lib/services/`, models in `lib/models/`, and reusable UI in `lib/widgets/`. Tests live in `test/`. Android platform code and manifests are under `android/`. Static assets are in `assets/` and `web/`. Firmware code for this tree is in `src/` and is built through the local `platformio.ini`.

## Build, Test, and Development Commands
Run Flutter commands from the repository root:

- `flutter pub get` installs Dart and Flutter dependencies.
- `flutter test` runs the unit and widget test suite in `test/`.
- `flutter run` launches the app on a connected device or emulator.
- `flutter analyze` checks the project against `analysis_options.yaml`.
- `pio run` builds the ESP32 firmware in `src/`.
- `pio run -t upload` uploads firmware to the connected ESP32.

## Coding Style & Naming Conventions
Use Dart defaults: two-space indentation, `lowerCamelCase` for variables and methods, `UpperCamelCase` for classes, and `snake_case.dart` filenames. Keep state coordination in providers, transport logic in services, and UI composition in screens/widgets. Prefer small, focused files and reuse existing app models before adding new data shapes. For firmware, keep relay channels stable: `0=light`, `1=fan`, `2=rgb`, `3=socket`.

## Testing Guidelines
Use Flutter's standard `flutter_test` framework. Name test files with `_test.dart`, such as `settings_provider_test.dart` or `alarm_test.dart`. Add or update tests for provider logic, parsing, persistence, and service behavior when changing app state or protocols. For firmware or command payload changes, verify both the firmware build with `pio run` and app tests with `flutter test`.

## Commit & Pull Request Guidelines
Recent history uses concise prefixes like `feat:` and `fix:`; follow that style where possible, for example `feat: add alarm sync status` or `fix: handle websocket reconnect`. Keep commits focused. Pull requests should describe the user-visible change, list validation steps run, link related issues, and include screenshots or recordings for UI changes.

## Security & Configuration Tips
Do not add secrets, WiFi credentials, tokens, or API keys to tracked files. Preserve Android permissions required for BLE, microphone, and foreground services unless the feature is intentionally removed. When changing command payloads or device state fields, update both Flutter app code and ESP32 handling so HTTP, WebSocket, MQTT, and BLE paths stay compatible.

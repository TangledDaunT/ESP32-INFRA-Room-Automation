# Phone_App Guidelines

## Scope
- This file applies to the Flutter Android app in `Phone_App/`.
- For workspace-wide firmware and cross-component guidance, see [../AGENTS.md](../AGENTS.md).

## Read First
- App feature and protocol details: [README.md](README.md)
- App entry and startup wiring: [lib/main.dart](lib/main.dart)
- Runtime bootstrap helpers: [lib/app_runtime.dart](lib/app_runtime.dart)
- State authority and automation hub: [lib/providers/device_provider.dart](lib/providers/device_provider.dart)
- Device and settings models: [lib/models/device_state.dart](lib/models/device_state.dart) and [lib/models/app_settings.dart](lib/models/app_settings.dart)
- Transport layer: [lib/services/openclaw_service.dart](lib/services/openclaw_service.dart)
- Important tests: [test/app_runtime_test.dart](test/app_runtime_test.dart), [test/app_settings_test.dart](test/app_settings_test.dart), [test/settings_provider_test.dart](test/settings_provider_test.dart), [test/friday_service_test.dart](test/friday_service_test.dart), [test/alarm_test.dart](test/alarm_test.dart), [test/widget_test.dart](test/widget_test.dart)

## Build and Validation
- Run Flutter commands from `Phone_App/`.
- `flutter pub get` installs dependencies.
- `flutter test` is the primary validation step for app changes.
- `flutter analyze` is a useful follow-up when touching shared models, providers, or services.
- If a change affects firmware payloads or state fields, verify the matching firmware path in the repo root as well.

## App Conventions
- Keep state coordination in providers, transport logic in services, and UI composition in screens and widgets.
- Treat `DeviceProvider` as the app-side control hub; most behavior changes belong there before they reach the UI.
- Keep relay channels stable: `0=light`, `1=fan`, `2=rgb`, `3=socket`.
- Preserve the JSON command dialect used by the app and firmware. Update both sides together when changing `cmd`, `ch`, `val`, or state field names.
- Reuse existing models before introducing new shapes.

## Testing Focus
- Update or add tests for provider logic, parsing, persistence, service behavior, and widget formatting when app state changes.
- Favor narrow tests around `lib/providers/`, `lib/models/`, and `lib/services/` when behavior changes are localized.

## Platform Notes
- Preserve Android permissions required for BLE, microphone, foreground services, wake/lockscreen behavior, and cleartext networking unless the feature is intentionally removed.
- Avoid adding secrets, WiFi credentials, tokens, or API keys to tracked files.

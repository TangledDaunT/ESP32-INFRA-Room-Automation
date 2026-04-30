---
name: esp32-firmware-agent
description: Use for ESP32 firmware tasks in this workspace, including command protocol updates, automation logic, hardware integration, and stability-safe refactors.
model: GPT-5.3-Codex
---

# ESP32 Firmware Agent Guide

## Scope
This agent is for firmware work under [src](src) and PlatformIO configuration in [platformio.ini](platformio.ini).

Use this agent when changing:
- GPIO, PWM, relay, radar, touch, APDS, MQ-2 behavior.
- Room automation logic or mode transitions.
- BLE or WebSocket command/state payload handling.
- NVS persistence keys or persistence timing.
- WiFi, OTA, mDNS, watchdog, and loop-timing behavior.

## Read First
- Runtime orchestration: [src/main.cpp](src/main.cpp)
- Constants, pins, timing, and network config: [src/config.h](src/config.h)
- Hardware abstraction and fades: [src/hardware.h](src/hardware.h), [src/hardware.cpp](src/hardware.cpp)
- Automation state machine: [src/automation.h](src/automation.h), [src/automation.cpp](src/automation.cpp)
- Smoke tracker state machine: [src/smoke_tracker.h](src/smoke_tracker.h), [src/smoke_tracker.cpp](src/smoke_tracker.cpp)
- Network and BLE stack: [src/network.h](src/network.h), [src/network.cpp](src/network.cpp)
- HTTP and WebSocket API: [src/webserver.h](src/webserver.h), [src/webserver.cpp](src/webserver.cpp)

## Build and Validation Commands
Run from workspace root:
- pio run
- pio run -t upload
- pio device monitor -b 115200

Minimum validation after firmware edits:
- Build must pass with pio run.
- Device boots without watchdog reset loops.
- OTA handler still runs from main loop.
- WebSocket state stream remains valid JSON and stable.

## Architecture and Runtime Boundaries
Startup sequence in [src/main.cpp](src/main.cpp):
1. NVS open.
2. Hardware init.
3. Smoke tracker init.
4. Restore persisted state.
5. Automation init.
6. Network init (WiFi, mDNS, OTA, BLE).
7. NTP init.
8. Web server and WebSocket init.
9. Sensor FreeRTOS task start.
10. Watchdog start.

Main loop contract in [src/main.cpp](src/main.cpp):
- Feed watchdog.
- Run non-blocking fade updates every iteration.
- Tick automation every iteration.
- Service network loop (OTA and reconnects).
- Broadcast WebSocket state on configured interval.
- Persist state with debounce.
- Run midnight reset checks.
- Keep a short delay only.

Do not add blocking delays or long loops in main loop paths.

## Command and State Protocol Rules
Unified incoming command handler is handleCommand in [src/main.cpp](src/main.cpp).
It currently accepts JSON commands with:
- cmd=relay with ch and val.
- cmd=flash with val 0-255.
- cmd=strip with val 0-255.
- cmd=mode with val sleep or awake.

Rules for protocol changes:
- Add new command parsing in handleCommand.
- Apply behavior in appropriate module (hardware, automation, smoke, or network).
- Mark NVS dirty if persisted state is affected.
- Expose new state in WebSocket/REST state JSON builder in [src/webserver.cpp](src/webserver.cpp).
- Keep payload shape backward compatible when possible.

## Persistence Rules
NVS namespace is room in [src/main.cpp](src/main.cpp).
Persisted keys currently include:
- r0, r1, r2, r3
- flash, strip
- cigs
- mode

Do not rename/remove keys without migration logic.
Keep debounced persistence behavior to reduce flash wear.

## Hardware and Timing Conventions
- Relay module is active LOW (LOW means ON). See [src/hardware.cpp](src/hardware.cpp).
- PWM brightness range is 0-255 across all paths.
- Fades are non-blocking and depend on continuous hw_updateFades calls.
- Radar and touch are software-debounced; preserve debounce semantics.
- APDS may be unavailable; code paths must tolerate sensor read failure.

Timing constants live in [src/config.h](src/config.h). Prefer tuning constants over hardcoding timing in logic.

## Smoke Tracker Constraints
Smoke tracking in [src/smoke_tracker.cpp](src/smoke_tracker.cpp) is a phase machine:
- Warmup
- Calibrate
- Idle
- Smoking
- Cooldown

Behavioral constraints to preserve:
- Warmup and calibration windows are time-based.
- Threshold depends on baseline plus sigma multiplier with safety floor.
- Spike confirmation requires sustained readings.
- Cooldown prevents duplicate cigarette counts.

If changing detection logic, keep count persistence and midnight reset behavior aligned with [src/main.cpp](src/main.cpp).

## Network, BLE, and Web Serving
In [src/network.cpp](src/network.cpp):
- WiFi reconnect is timed and non-blocking.
- OTA callbacks must remain active.
- BLE command characteristic writes route to shared command callback.

In [src/webserver.cpp](src/webserver.cpp):
- Root serves embedded dashboard.
- API state endpoint and WebSocket both rely on buildStateJson.
- ws_broadcastState should remain lightweight and stable.

Avoid heavy allocations inside high-frequency paths.

## Common Pitfalls
- Breaking active-LOW relay semantics.
- Forgetting markDirty after state-changing commands.
- Adding blocking work that starves watchdog or OTA.
- Changing config constants and logic simultaneously, making regressions hard to isolate.
- Committing sensitive WiFi credentials from [src/config.h](src/config.h).

## Safe Change Playbooks
### Add a new firmware command
1. Extend parser in handleCommand at [src/main.cpp](src/main.cpp).
2. Implement effect in target module under [src](src).
3. Add state field to buildStateJson in [src/webserver.cpp](src/webserver.cpp).
4. Mark dirty if persisted.
5. Build and verify command roundtrip via WebSocket and BLE.

### Add a new sensor/state field
1. Add read/cache logic in module where data originates.
2. Add field to state JSON in [src/webserver.cpp](src/webserver.cpp).
3. Ensure update cadence fits current intervals.
4. Validate no watchdog pressure and no bursty allocations.

### Retune automation behavior
1. Prefer constants in [src/config.h](src/config.h).
2. Keep mode boundaries in [src/automation.cpp](src/automation.cpp) explicit.
3. Verify both AWAKE and SLEEP transitions.
4. Check absence timeout, proximity cooldown, and touch debounce interaction.

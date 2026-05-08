# ESP32 IoT Room Automation System - Comprehensive Context Document

This document serves as the master instruction and context file for the entire ESP32 Room Automation Codebase. It provides exhaustive details about the hardware configuration, ESP32 firmware architecture, Flutter companion app, and communication protocols.

**Intended Use:** Context provisioning for LLMs and AI coding assistants working on the `ESP 32 INFRA` repository.

---

## 1. Hardware Architecture & Pinout

The core of the system is an **ESP32 DEV Module** acting as the central IoT hub, coordinating various sensors and actuators.

### 1.1 Devices & Sensors connected to ESP32
- **ESP32 DEV Module**: The brain of the operation, handling Wi-Fi, BLE, MQTT, HTTP server, and hardware I/O.
- **5V 4-Channel Relay Board (Active LOW)**: Used for switching high-voltage AC appliances.
- **TTP223 Touch Key Module (x2)**: Capacitive touch sensors for physical interactions.
- **CJMCU APDS-9930**: I2C sensor measuring Proximity and Ambient Light (Lux).
- **RCWL-0516 Microwave Radar**: Detects human motion/presence, even through obstacles.
- **MQ-2 Gas Sensor**: Detects smoke and combustible gases.
- **D4184 MOSFET Boards (x2)**: Handles high-current PWM dimming for 12V/24V DC lighting (Backup flashlight & RGB strip).
- **LM2596 2A Buck Step-down Converter**: Regulates power down to safe voltages for the ESP32 and logic modules, featuring an LED Voltmeter.

### 1.2 Pin Assignments
| Pin / Interface | Component / Function | Notes |
| :--- | :--- | :--- |
| `GPIO 26` | Relay 1: Main Lights | Active LOW |
| `GPIO 27` | Relay 2: Ceiling Fan | Active LOW |
| `GPIO 14` | Relay 3: 220V RGB Light | Active LOW |
| `GPIO 25` | Relay 4: Charging Socket | Active LOW |
| `GPIO 32` | MOSFET 1: Backup Flashlight | 5kHz PWM (LEDC Channel 0), 8-bit res. |
| `GPIO 33` | MOSFET 2: LED Strip | 5kHz PWM (LEDC Channel 1), 8-bit res. |
| `GPIO 4` | RCWL-0516 Radar Sensor | Digital Input (HIGH on motion) |
| `GPIO 5` | TTP223 Touch Sensor | Digital Input |
| `GPIO 21` | I2C SDA (APDS-9930) | Ambient light and proximity |
| `GPIO 22` | I2C SCL (APDS-9930) | Ambient light and proximity |
| `GPIO 34` | MQ-2 Analog Out (A0) | ADC1_CH6 (Input only) |
| `GPIO 35` | MQ-2 Digital Out (D0) | Digital threshold interrupt |
| `GPIO 2` | Onboard Status LED | |

---

## 2. ESP32 Firmware Architecture (C++ / PlatformIO)

The firmware is located in the `src/` directory and utilizes the `Arduino` framework.

### 2.1 Core Responsibilities
- **`main.cpp`**: Orchestrates startup sequence (Hardware initialization -> NVS restore -> Automation -> Network -> WebSocket). Manages the main non-blocking loop (watchdog, fading, networking). Unified command ingestion via `handleCommand(String json)`.
- **`hardware.cpp` / `hardware.h`**: Encapsulates GPIO reads/writes, PWM initialization, and sensor polling. 
- **`network.cpp` / `mqtt_client.cpp`**: Manages Wi-Fi reconnects, mDNS (`shreyansh.local`), AsyncWebServer, and HiveMQ TLS MQTT connectivity.
- **`automation.cpp`**: Handles local state-machine logic (e.g., Radar absence timeout, touch-based fading, sleep mode transitions).
- **`smoke_tracker.cpp`**: Advanced DSP algorithm to track cigarette smoke via MQ-2. Uses calibration baselines, sigma spikes, and cooldowns.

### 2.2 Key Firmware Constants & Invariants
- **Relay Logic**: All relays are **Active LOW**.
- **PWM Logic**: 8-bit resolution (0-255). Driven at 5kHz to accommodate D4184 optocoupler limits.
- **Non-Volatile Storage (NVS)**: Device states (relay 0-3, mosfet brightness, mode) are persisted to NVS to survive reboots. Changing NVS keys requires migration.
- **MQTT Topics**: 
  - Subscriptions: `openclaw/control/#` (fan, light, socket, rgb, rgb/brightness, backup/brightness).
  - Publishing: `openclaw/state`, `openclaw/sensors/#` (smoke, lux, presence).

---

## 3. Flutter Mobile Application (`Phone App/`)

The mobile companion app serves as the ultimate "State Authority", providing local control (BLE/HTTP) and remote control (MQTT).

### 3.1 App Capabilities
1. **Real-time Control & Sync**: Controls all 4 relays and 2 MOSFET PWM channels. Keeps UI synchronized across WebSocket, BLE, and MQTT transports.
2. **Advanced Clap Detection (`ClapDetector`)**: 
   - Uses `record` package for raw 16-bit PCM mic streaming (16kHz).
   - Runs DSP in a Dart Isolate to prevent UI lag.
   - Computes RMS for adaptive noise floor.
   - Utilizes Fast Fourier Transform (FFT via `fftea`) to identify the 2kHz-4kHz frequency signature of human claps.
   - Rejects sustained noise. A double clap toggles the main lights. Single claps display an animated UI overlay.
3. **Sleep & Wake-up Automation**: 
   - Tracks user presence using the phone's state and OpenClaw metrics.
   - Waking up triggers smart routines (e.g., fading up RGB strips).
4. **Intimacy Mode**: Senses high ambient dB via the microphone and triggers a localized atmospheric mode (dims lights, pulses backup flashlight).
5. **Foreground Service**: Uses `flutter_foreground_task` with WakeLocks to keep the microphone processing alive even when the phone is locked or screen is off.

### 3.2 State Management (`lib/providers/device_provider.dart`)
- `DeviceProvider` is the single source of truth.
- Coordinates incoming events from `MqttService`, `OpenClawService`, `BleService`, and `ClapDetector`.
- Resolves conflicts between MQTT messages and local BLE/Clap events.

### 3.3 Models
- **`DeviceState`**: Contains boolean flags for relays (`fanOn`, `lightOn`), integers for PWM (`rgbBrightness`), floats for sensors (`smokeValue`, `luxValue`), and connectivity statuses.
- **`AppSettings`**: Manages user preferences, MQTT broker details, sleep/wake hours, and clap sensitivity.

---

## 4. System Communications & Protocols

### 4.1 Bidirectional Sync
- **Local Network (HTTP/WebSocket)**: Web dashboard on `http://shreyansh.local`. WebSockets push JSON state changes every 500ms.
- **Bluetooth Low Energy (BLE)**: Custom service `4fafc201...`. Uses one characteristic for Writes (Command JSON) and one for Reads/Notifies (State JSON).
- **MQTT (HiveMQ Cloud)**: Enables control from anywhere over LTE.

### 4.2 Data Payload Structure
All transports (BLE, MQTT, WebSocket) speak the same JSON dialect.
Example Control Payload:
```json
{
  "command": "toggle_relay",
  "pin": 26,
  "state": 1
}
```
Example PWM Payload:
```json
{
  "command": "set_pwm",
  "channel": 1,
  "value": 150
}
```

---

## 5. Coding Agent Playbook (Strict Rules)

If you are an AI agent analyzing or editing this codebase, adhere strictly to the following rules:

1. **Safety First (Relays)**: Never alter relay logic inversion unless directly instructed. Active LOW means pulling the pin `0` turns the high voltage ON.
2. **Minimal Changes**: Do not refactor architecture unless asked. Maintain the `handleCommand` boundary in firmware.
3. **Hardware Boundaries**: Do not increase PWM frequency above 5kHz; it will overheat the D4184 mosfets.
4. **App Layout**: The phone app uses a `SingleChildScrollView` to prevent pixel overflow on narrow screens. Do not revert to rigid fixed widths.
5. **Microphone Access**: The clap detector runs inside a Dart Isolate. Do not block the isolate loop with heavy calculations. FFT should only run *after* a cheap RMS spike is detected.

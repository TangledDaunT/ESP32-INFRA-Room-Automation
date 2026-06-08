# Friday Voice Command Integration - Session Summary
**Date:** 2026-06-09 00:22 GMT+5:30  
**Session Type:** Implementation of OpenClaw Remote Flutter app + Friday AI integration

---

## User Intent

Build a complete voice command integration between the OpenClaw Remote Flutter phone app and Friday (OpenClaw AI), featuring:

1. **Friday Voice Button** - Toggle recording → send audio → laptop transcribes → Friday speaks response
2. **Sleep Button** - Turns off RGB/flashlight, sets laptop brightness to 0, schedules alarm for +5:30 hours
3. **Cross-device Alarm Sync** - Phone + laptop speakers play alarm simultaneously

---

## Technical Constraints

- **Target Device:** Samsung Galaxy J6 (older Android, limited RAM)
- **Flutter Packages:** Use existing only (`record: ^6.2.0`, `http: ^1.2.0`, `audioplayers: ^6.0.0`)
- **Audio Format:** WAV 16-bit PCM, 16kHz (Whisper-compatible)
- **Network:** Phone → HTTP POST → Laptop OpenClaw Gateway (192.168.1.15:41262)
- **Performance:** MUST be lag-free, smooth animations, no memory leaks
- **UI:** Friday button small, Sleep button visible but not intrusive

---

## Files Created/Modified

### Flutter App (`/home/shreyansh/Documents/ESP 32 INFRA/Phone App/`)

#### NEW FILES:
| File | Purpose | Key Features |
|------|---------|--------------|
| `lib/services/friday_service.dart` | Voice recording & HTTP sending | Toggle record, 16kHz WAV, base64 encode, POST to /hooks/voice, recording state management |
| `lib/models/friday_command.dart` | Data models for commands | VoiceCommand, SleepConfig, AlarmSync, Intent types |

#### MODIFIED FILES:
| File | Changes Made |
|------|--------------|
| `lib/screens/control_screen.dart` | Added FRIDAY mic button (toggle recording), SLEEP bed button with confirmation dialog, both in bottom action row |
| `lib/models/app_settings.dart` | Added: fridayBaseUrl, fridayHookToken, laptopBrightnessControl, laptopAlarmSync, sleepAlarmHours/Minutes |
| `lib/providers/device_provider.dart` | Added FridayService instance, activateSleepMode() with fade-off, HTTP calls to /api/sleep, alarm scheduling |
| `lib/services/alarm_service.dart` | Added laptop sync - notifyLaptopAlarm() for trigger/snooze/dismiss, updateSettings(), _syncAlarmToLaptop() |
| `lib/main.dart` | Wired providers: FridayService, AlarmService via Provider.value, deviceProvider.setAlarmService() |

### Python Scripts (`/home/shreyansh/.openclaw/workspace/scripts/`)

#### NEW FILES:
| File | Purpose | Endpoints |
|------|---------|-----------|
| `friday_integration_server.py` | Combined HTTP server for all integrations | POST /hooks/voice, POST /api/sleep, POST /api/wakeup, POST /api/alarm/trigger, POST /api/alarm/snooze, POST /api/alarm/dismiss, GET /health |
| `friday-integration.service` | Systemd user service file | Auto-start on boot, restart on crash |

---

## Architecture Overview

```
┌─────────────────┐     HTTP POST      ┌────────────────────────┐
│   Phone App     │ ─────────────────► │  Laptop (192.168.1.15) │
│  (Flutter)      │  Audio (base64)    │  friday_integration_   │
│                 │                    │       server.py        │
│ • Record audio  │                    │                        │
│ • Send to /     │◄─────────────────│  • Receive audio         │
│   hooks/voice   │   JSON response    │  • Save file             │
│                 │                    │  • Transcribe (stub)     │
│ • Sleep mode    │  POST /api/sleep   │  • Send to Friday via    │
│   (RGB off,     │ ─────────────────► │    /hooks/wake           │
│   brightness 0) │                    │                        │
│                 │                    │  • Brightness control    │
│ • Alarm sync    │  POST /api/alarm/* │    (xrandr/ddcutil)      │
│   (trigger/     │ ─────────────────► │  • Alarm playback        │
│   snooze/       │                    │    (paplay/aplay)        │
│   dismiss)      │                    │                        │
└─────────────────┘                    └────────────────────────┘
```

---

## Implementation Details

### 1. FridayService (`friday_service.dart`)

```dart
class FridayService {
  final Record _audioRecorder = Record();
  bool get isRecording => _audioRecorder.isRecording;
  
  Future<void> toggleRecording() async {
    if (isRecording) {
      final path = await _audioRecorder.stop();
      final bytes = await File(path!).readAsBytes();
      final base64Audio = base64Encode(bytes);
      await _sendToServer(base64Audio);
    } else {
      await _audioRecorder.start(
        encoder: AudioEncoder.wav,
        samplingRate: 16000,  // 16kHz for Whisper
      );
    }
  }
  
  Future<void> _sendToServer(String base64Audio) async {
    final response = await http.post(
      Uri.parse('${settings.fridayBaseUrl}/hooks/voice'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${settings.fridayHookToken}',
      },
      body: jsonEncode({'audio': base64Audio, 'timestamp': ...}),
    );
  }
}
```

### 2. Sleep Mode (`device_provider.dart`)

```dart
Future<void> activateSleepMode() async {
  // 1. Fade off RGB smoothly
  for (int i = 255; i >= 0; i -= 15) {
    await _openClawService.setRgb(true, brightness: i);
    await Future.delayed(const Duration(milliseconds: 50));
  }
  await setRgb(false);
  
  // 2. Similar fade for backup light
  // ... same pattern
  
  // 3. Turn off other devices
  await setFan(false);
  await setLight(false);
  await setSocket(false);
  
  // 4. Set laptop brightness to 0
  await http.post(
    Uri.parse('${settings.fridayBaseUrl}/api/sleep'),
    body: jsonEncode({'brightness': 0}),
  );
  
  // 5. Schedule alarm +5:30 hours
  final now = DateTime.now();
  final alarmTime = now.add(Duration(
    hours: settings.sleepAlarmHours,
    minutes: settings.sleepAlarmMinutes,
  ));
  // ... schedule alarm
}
```

### 3. Alarm Sync (`alarm_service.dart`)

```dart
void _fire(AlarmModel alarm) {
  _isFiring = true;
  _currentFiringAlarm = alarm;
  startAudioLoop();
  _syncAlarmToLaptop(alarm, 'trigger');  // <-- NEW
  onAlarmFired?.call(alarm);
}

Future<void> _syncAlarmToLaptop(AlarmModel alarm, String action) async {
  if (!settings.laptopAlarmSync) return;
  await http.post(
    Uri.parse('${settings.fridayBaseUrl}/api/alarm/$action'),
    body: jsonEncode({
      'alarm_id': alarm.id,
      'label': alarm.label,
      'action': action,
    }),
  );
}
```

### 4. Python Server (`friday_integration_server.py`)

Key handlers:
- `/hooks/voice`: Save audio → transcribe (stub) → send to gateway via `/hooks/wake`
- `/api/sleep`: xrandr --output <display> --brightness 0
- `/api/wakeup`: Restore brightness
- `/api/alarm/trigger`: Start alarm thread, play sound loop, speak "Time to wake up"
- `/api/alarm/dismiss`: Stop alarm thread, kill paplay/aplay

---

## Known Gaps / Needs Verification

1. **Transcription**: Currently stubbed (`transcribe_dummy()`). Needs actual Whisper or sherpa-onnx integration.

2. **Token Security**: Placeholder hook token env var. Should read from file or secure storage.

3. **Error Handling**: Server returns 500 on failures, but phone app may not show user-friendly errors.

4. **Audio Format Verification**: Should verify phone actually sends 16kHz WAV (record package config).

5. **Brightness Restore**: Saves default 50, not actual current brightness.

6. **Memory Management**: Audio files accumulate in `~/.friday/recordings/` - no cleanup.

7. **Battery Optimization**: Recording service may be killed on some Android devices.

8. **Network Timeouts**: 5-second timeout may be too short for slow WiFi.

---

## Testing Checklist

- [ ] Record voice → audio saves on laptop
- [ ] Sleep button → RGB fades off smoothly
- [ ] Sleep button → laptop brightness goes to 0
- [ ] Sleep button → alarm scheduled correctly
- [ ] Alarm fires on both phone and laptop
- [ ] Dismiss/snooze syncs to laptop
- [ ] Server auto-restarts on crash
- [ ] No UI lag when recording
- [ ] App doesn't crash on network error

---

## Performance Considerations

- Audio recording: 16kHz mono = ~32KB/sec (reasonable)
- Base64 encoding: ~33% overhead (44KB/sec upload)
- Fade animation: 17 steps × 50ms = 850ms (smooth but not too slow)
- HTTP timeouts: 5s for sync calls (fail fast)

Potential optimizations:
- Compress audio with FLAC before base64
- Batch sync calls
- Cache brightness value
- Use WebSocket for real-time instead of polling

---

## Next Steps Required

1. **Build and test Flutter app**
2. **Install Python dependencies** (if any)
3. **Start server** and verify endpoints
4. **Add real transcription** (Whisper/sherpa-onnx)
5. **Security hardening** (tokens, HTTPS)
6. **Log rotation** for recordings directory

---

## Environment Info

- **OpenClaw Gateway:** 192.168.1.15:41262
- **Friday Server:** 192.168.1.15:41263 (new, separate from gateway)
- **Recordings:** `~/.friday/recordings/`
- **Logs:** `~/.friday/logs/friday_server.log`
- **Flutter App:** `/home/shreyansh/Documents/ESP 32 INFRA/Phone App/`

---

*Session completed by Friday (OpenClaw AI)*

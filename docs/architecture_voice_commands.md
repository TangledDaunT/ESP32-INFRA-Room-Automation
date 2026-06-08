# 🎙️ Voice Command Architecture - OpenClaw Remote + Friday Integration

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              PHONE (Android)                                │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        FLUTTER APP                                   │   │
│  │  ┌───────────────┐    ┌───────────────┐    ┌───────────────────┐   │   │
│  │  │ Friday Button │    │ Sleep Button  │    │   Alarm System    │   │   │
│  │  │  (mic toggle) │    │  (bed mode)   │    │                   │   │   │
│  │  └───────┬───────┘    └───────┬───────┘    └───────────────────┘   │   │
│  │          │                    │                                      │   │
│  │  ┌───────▼────────────────────▼──────────────────┐                  │   │
│  │  │         DeviceProvider (State Management)      │                 │   │
│  │  └───────┬────────────────────┬───────────────────┘                  │   │
│  │          │                    │                                      │   │
│  │  ┌───────▼──────┐    ┌────────▼────────┐    ┌───────────────┐      │   │
│  │  │FridayService │    │ OpenClawService │    │ AlarmService  │      │   │
│  │  │├ record()   │    │ ├ WebSocket     │    │ ├ Schedule    │      │   │
│  │  │├ sendAudio()│───▶│ ├ HTTP POST     │    │ ├ Play Sound  │      │   │
│  │  │└ stop()      │    │ └ Control ESP32 │    │ └ Cross-sync  │      │   │
│  │  └──────────────┘    └─────────────────┘    └───────────────┘      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                        │                                 │                  │
│                        │ HTTP POST                     │ HTTP POST         │
│                        │ /api/sleep                    │ /hooks/voice      │
│                        ▼                                 ▼                  │
└─────────────────────────────────────────────────────────────────────────────┘
                         │                                 │
                    ═════╧═════════════════════════════════╧═════
                                    LAN/WiFi
                    ═════╤═════════════════════════════════╤═════
                         │                                 │
                         ▼                                 ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           LAPTOP (Linux)                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    OPENCLAW GATEWAY                                  │   │
│  │  ┌───────────────┐    ┌───────────────┐    ┌───────────────────┐   │   │
│  │  │ /hooks/voice  │    │ /api/sleep    │    │   Audio Handler   │   │   │
│  │  │  (receiver)   │    │  (receiver)   │    │  (whisper TTS)    │   │   │
│  │  └───────┬───────┘    └───────┬───────┘    └───────────────────┘   │   │
│  │          │                    │                                      │   │
│  │          └────────────────────┘                                      │   │
│  │                      │                                               │   │
│  │                      ▼                                               │   │
│  │          ┌─────────────────────┐                                     │   │
│  │          │   Friday (Agent)    │                                     │   │
│  │          │  ├ Transcribe audio │                                     │   │
│  │          │  ├ Process command  │                                     │   │
│  │          │  ├ Control devices  │                                     │   │
│  │          │  └ Speak response   │───▶ Laptop Speaker                  │   │
│  │          │                     │                                     │   │
│  │          │  ├ Control Brightness (ddcutil/xrandr)                   │   │
│  │          │  └ Sync alarm time to phone                              │   │
│  │          └─────────────────────┘                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Feature 1: Friday Voice Button (Toggle Mic)

### User Flow:
1. **Tap Friday button once** → Mic starts recording, UI shows "Listening..."
2. **Speak command** (e.g., "Turn off the lights")
3. **Tap Friday button again** → Recording stops, audio sent to laptop
4. **Friday transcribes** (whisper/sherpa-onnx), processes command
5. **Friday speaks response** through laptop speakers

### Phone Implementation:

```dart
// lib/services/friday_service.dart
class FridayService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _audioPath;
  
  // Start recording to temp file
  Future<void> startRecording() async {
    _audioPath = '${(await getTemporaryDirectory()).path}/friday_cmd.wav';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav),
      path: _audioPath!,
    );
    _isRecording = true;
  }
  
  // Stop and send to OpenClaw
  Future<void> stopAndSend() async {
    await _recorder.stop();
    _isRecording = false;
    
    // Read audio file as bytes
    final bytes = await File(_audioPath!).readAsBytes();
    final base64Audio = base64Encode(bytes);
    
    // Send to OpenClaw webhook
    await http.post(
      Uri.parse('http://192.168.1.X:41262/hooks/voice'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer <token>',
      },
      body: jsonEncode({
        'audio': base64Audio,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
  }
}
```

### OpenClaw Implementation:

```javascript
// Inbound webhook handler for /hooks/voice
// Receives audio, transcribes with sherpa-onnx, sends to agent
```

---

## Feature 2: Sleep Button

### User Flow:
1. **Tap Sleep button** → Immediate actions:
   - Phone: Turn off RGB strip and flashlight (via ESP32)
   - Phone: Schedule alarm for current_time + 5:30 hours
   - Laptop: Set screen brightness to 0 (ddcutil or xrandr)
   - Both: Sync alarm state

2. **When alarm fires** (5:30 hours later):
   - Phone: Play alarm sound
   - Phone: Send HTTP command to laptop to also play alarm
   - Both: Show alarm UI with snooze/dismiss

### Phone Implementation:

```dart
// In DeviceProvider - Sleep mode
Future<void> activateSleepMode() async {
  // 1. Turn off RGB and Flashlight via ESP32
  await setRgb(false);
  await setBackupBrightness(0);
  
  // 2. Schedule alarm for +5:30
  final alarmTime = DateTime.now().add(const Duration(hours: 5, minutes: 30));
  await _alarmService.addAlarm(AlarmModel(
    id: 'sleep_wakeup_${DateTime.now().millisecondsSinceEpoch}',
    hour: alarmTime.hour,
    minute: alarmTime.minute,
    label: 'Sleep Wakeup',
    isEnabled: true,
    kind: AlarmKind.sleep,
  ));
  
  // 3. Notify laptop to set brightness to 0
  await http.post(
    Uri.parse('$fridayBaseUrl/api/sleep'),
    body: jsonEncode({'brightness': 0, 'action': 'sleep'}),
  );
}
```

### Laptop Implementation:

```bash
# Set brightness to 0 using ddcutil (for external monitors)
ddcutil setvcp 10 0

# Or using xrandr (for laptop screen)
xrandr --output eDP-1 --brightness 0
```

---

## Feature 3: Cross-Device Alarm

### Architecture:

```
Phone Alarm Fires
       │
       ▼
┌─────────────────┐
│  AlarmService   │──▶ Play local sound
│  (audioplayers) │──▶ Show AlarmOverlay UI
└────────┬────────┘
         │
         │ HTTP POST /api/alarm/fired
         │ (wake laptop if needed)
         ▼
┌─────────────────────┐
│   Laptop Gateway    │
│  /api/alarm/fired   │
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│  Friday / Script    │
│  ├ Play alarm mp3   │──▶ Laptop speakers
│  ├ Speak "Wake up"  │──▶ Laptop speakers
│  └ Sync ACK back    │──▶ Phone (optional)
└─────────────────────┘
```

### Phone → Laptop Alarm Sync:

```dart
// When alarm fires in AlarmService
void _fire(AlarmModel alarm) {
  _isFiring = true;
  startAudioLoop(); // Local phone sound
  onAlarmFired?.call(alarm);
  
  // Also notify laptop
  _notifyLaptopAlarm(alarm);
}

Future<void> _notifyLaptopAlarm(AlarmModel alarm) async {
  await http.post(
    Uri.parse('$fridayBaseUrl/api/alarm/trigger'),
    body: jsonEncode({
      'alarm_id': alarm.id,
      'label': alarm.label,
      'action': 'play',
    }),
  );
}
```

---

## API Endpoints to Create

### Phone App Exposes (for laptop to call):
- `POST /api/alarm/ack` - Laptop confirms it played alarm

### OpenClaw/Laptop Exposes (for phone to call):
- `POST /hooks/voice` - Receive audio from phone
- `POST /api/sleep` - Sleep mode (brightness 0)
- `POST /api/alarm/trigger` - Play alarm on laptop
- `POST /api/wakeup` - Wake mode (brightness restore)

---

## Files to Modify

### Phone App:
1. `lib/services/friday_service.dart` - NEW: Voice recording & sending
2. `lib/providers/device_provider.dart` - ADD: Sleep mode, Friday integration
3. `lib/screens/control_screen.dart` - ADD: Friday button, Sleep button
4. `lib/models/app_settings.dart` - ADD: Friday URL setting
5. `lib/services/alarm_service.dart` - MODIFY: Cross-device sync

### OpenClaw/Laptop:
1. Webhook handler for `/hooks/voice` - NEW
2. HTTP endpoint `/api/sleep` - NEW
3. HTTP endpoint `/api/alarm/trigger` - NEW
4. Brightness control script - NEW
5. Alarm playback script - NEW

---

## Technical Considerations

### Audio Format:
- **Recording**: WAV 16-bit PCM, 16kHz (compatible with Whisper)
- **Transmission**: Base64 encoded in JSON POST body
- **Size**: ~30 seconds = ~1MB (acceptable for LAN)

### Network:
- All communication over LAN (192.168.1.x)
- HTTP for one-shot commands
- WebSocket optional for real-time sync

### Security:
- Use OpenClaw hook token for authentication
- Phone stores Friday URL and token securely

### Error Handling:
- If laptop unreachable → Phone handles alone
- If audio transcription fails → "Didn't catch that, please try again"
- Graceful fallbacks for all cross-device features

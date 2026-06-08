# 📋 COMPREHENSIVE PROMPT FOR CLAUDE CODE

## 🎯 Mission

Review, debug, and optimize the **Friday Voice Command Integration** for the OpenClaw Remote Flutter app. This integration enables voice control from a Samsung Galaxy J6 phone to control ESP32 home automation devices and communicate with Friday (the OpenClaw AI assistant).

**Critical Requirements:**
- ZERO bugs in production code
- ZERO lag on Samsung Galaxy J6 (2GB RAM, 2018 device)
- Clean, maintainable code
- Secure token handling
- Graceful error handling

---

## 📚 STEP 1: READ DOCUMENTATION

**MANDATORY PREREQUISITE** - Read these files in order before touching any code:

1. **`/home/shreyansh/.openclaw/workspace/memory/2026-06-09-session-summary.md`**
   - Complete architecture overview
   - Implementation details and code snippets
   - Known gaps and concerns
   - Testing checklist

2. **Original project context (if needed):**
   - `/home/shreyansh/.openclaw/workspace/architecture_voice_commands.md` - Architecture document

---

## 📁 STEP 2: LOCATE AND VERIFY ALL FILES

### Flutter App Location
```
/home/shreyansh/Documents/ESP 32 INFRA/Phone App/
```

**List every file that should exist - verify each one:**

| # | File Path | Purpose | Status |
|---|-----------|---------|--------|
| 1 | `lib/services/friday_service.dart` | Voice recording, HTTP sending | ⬜ Verify |
| 2 | `lib/models/friday_command.dart` | Data models for commands | ⬜ Verify |
| 3 | `lib/models/app_settings.dart` | Settings with Friday config | ⬜ Verify |
| 4 | `lib/providers/device_provider.dart` | Sleep mode, device control | ⬜ Verify |
| 5 | `lib/services/alarm_service.dart` | Alarm sync with laptop | ⬜ Verify |
| 6 | `lib/screens/control_screen.dart` | UI with Friday/Sleep buttons | ⬜ Verify |
| 7 | `lib/main.dart` | Provider wiring | ⬜ Verify |
| 8 | `pubspec.yaml` | Dependencies check | ⬜ Verify |

### Python Server Location
```
/home/shreyansh/.openclaw/workspace/scripts/
```

| # | File Path | Purpose | Status |
|---|-----------|---------|--------|
| 1 | `friday_integration_server.py` | Combined HTTP server | ⬜ Verify |
| 2 | `friday-integration.service` | Systemd service file | ⬜ Verify |

**ACTION:** If any file is missing, create a BUG REPORT entry immediately.

---

## 🔍 STEP 3: SYSTEMATIC CODE REVIEW

### SECTION A: FLUTTER CODE - PERFORMANCE ANALYSIS

For each Flutter file, check these aspects:

#### A1. Memory Management (CRITICAL for J6)
```dart
// IN EACH FILE, CHECK:

// 1. Are streams properly closed?
_audioRecorder.dispose();  // Called in dispose()?

// 2. Are files deleted after use?
File(tempPath).deleteSync();  // After sending?

// 3. Are large objects nulled?
audioBytes = null;  // After base64 encoding?

// 4. Is base64 string cleared?
base64Audio = '';  // After HTTP send?

// 5. HTTP clients properly closed?
client.close();  // Or using http package correctly?
```

#### A2. UI Thread Blocking (CRITICAL for J6)
```dart
// CHECK: Any blocking operations on main thread?

// BAD - blocks UI:
final bytes = File(path).readAsBytesSync();  // Synchronous!
final encoded = base64Encode(bytes);  // CPU intensive on main thread!

// GOOD - async, doesn't block:
final bytes = await File(path).readAsBytes();  // Async
await compute(base64Encode, bytes);  // Offload to isolate

// CHECK ALL PLACES for:
// - File I/O (use async versions)
// - base64 encoding (use compute() or isolate)
// - Heavy JSON parsing
// - Image/audio processing
```

#### A3. Widget Rebuild Optimization
```dart
// CHECK: Is Consumer/Selector used efficiently?

// BAD - rebuilds entire screen:
Consumer<DeviceProvider>(
  builder: (context, provider, child) => Scaffold(...),
)

// GOOD - rebuilds only button:
Consumer<DeviceProvider>(
  builder: (context, provider, child) => IconButton(...),
)

// BETTER - use Selector for granular updates:
Selector<DeviceProvider, bool>(
  selector: (context, provider) => provider.isRecording,
  builder: (context, isRecording, child) => IconButton(
    icon: Icon(isRecording ? Icons.stop : Icons.mic),
  ),
)

// CHECK: Are const constructors used?
child: const Text('Friday'),  // Add const everywhere possible
```

#### A4. HTTP Timeout Configuration
```dart
// CHECK: Are timeouts aggressive enough?

// BAD - 30 seconds freeze:
await http.post(url, body: payload);  // Default timeout?

// GOOD - fast failure:
await http
  .post(url, body: payload)
  .timeout(const Duration(seconds: 5));

// CHECK: Is timeout user-configurable?
sleepTimeout = settings.httpTimeout ?? const Duration(seconds: 5);
```

### SECTION B: FLUTTER CODE - BUG HUNTING

#### B1. Null Safety Violations
```dart
// IN EVERY FILE, check these patterns:

// DANGEROUS - potential null crash:
final path = await _audioRecorder.stop();
final bytes = await File(path!).readAsBytes();  // path could be null!

// SAFE:
final path = await _audioRecorder.stop();
if (path == null) return;
final file = File(path);
if (!file.existsSync()) return;
final bytes = await file.readAsBytes();

// CHECK FOR:
// - path! (force unwrap)
// - value! (force unwrap)
// - .onValue (without null check)
// - List[index] (without bounds check)
```

#### B2. Unhandled Exceptions
```dart
// CHECK: Is every async call wrapped in try-catch?

try {
  await sendVoiceCommand();
} on TimeoutException {
  _showError('Network timeout');
} on SocketException {
  _showError('No connection');
} on FormatException {
  _showError('Invalid response');
} catch (e, stackTrace) {
  _logError(e, stackTrace);  // Log for debugging
  _showError('Something went wrong');
}

// CHECK: Are errors logged properly?
developer.log('Error: $e', error: e, stackTrace: stackTrace);
```

#### B3. State Management Consistency
```dart
// CHECK: Is state correct after errors?

// BAD - stuck in wrong state:
setState(() => _isRecording = true);
try {
  await recorder.start();
} catch (e) {
  // Missing: _isRecording = false!
  // User thinks still recording!
}

// GOOD - always reset state:
setState(() => _isRecording = true);
try {
  await recorder.start();
} catch (e) {
  setState(() => _isRecording = false);  // Reset on error
  rethrow;
}
```

#### B4. Permission Handling
```dart
// CHECK: Are permissions requested before use?

// REQUIRED for audio recording:
// Android: <uses-permission android:name="android.permission.RECORD_AUDIO" />
// iOS: NSMicrophoneUsageDescription in Info.plist

// CHECK CODE:
final status = await Permission.microphone.request();
if (status != PermissionStatus.granted) {
  _showPermissionDeniedDialog();
  return;
}
```

### SECTION C: PYTHON SERVER - SECURITY & STABILITY

#### C1. Input Validation
```python
# CHECK: Is request size limited?

MAX_AUDIO_SIZE = 10 * 1024 * 1024  # 10MB max

content_length = int(self.headers.get('Content-Length', 0))
if content_length > MAX_AUDIO_SIZE:
    self._json_response(413, {'error': 'Audio too large'})
    return

# CHECK: Is audio format validated?
def is_valid_wav(data: bytes) -> bool:
    return data[:4] == b'RIFF' and data[8:12] == b'WAVE'

# CHECK: Is filename safe from directory traversal?
import re
SAFE_FILENAME = re.compile(r'^[\w\-]+\.wav$')
if not SAFE_FILENAME.match(filename):
    self._json_response(400, {'error': 'Invalid filename'})
    return
```

#### C2. Resource Cleanup
```python
# CHECK: Are temp files cleaned up?

import tempfile
import atexit

temp_files = []

def cleanup_temp_files():
    for f in temp_files:
        try:
            os.unlink(f)
        except:
            pass

atexit.register(cleanup_temp_files)

# IN HANDLER:
temp_path = tempfile.mktemp(suffix='.wav')
temp_files.append(temp_path)
try:
    with open(temp_path, 'wb') as f:
        f.write(audio_data)
    process_audio(temp_path)
finally:
    try:
        os.unlink(temp_path)
        temp_files.remove(temp_path)
    except:
        pass
```

#### C3. Thread Safety
```python
# CHECK: Is shared state protected?

from threading import Lock

_current_alarm_lock = Lock()
_current_alarm = None

def start_alarm(alarm_id: str):
    global _current_alarm
    with _current_alarm_lock:
        if _current_alarm:
            stop_alarm()
        _current_alarm = {'id': alarm_id, ...}
        
def stop_alarm():
    global _current_alarm
    with _current_alarm_lock:
        if _current_alarm:
            _alarm_stop_event.set()
            _current_alarm = None
```

#### C4. Environment Variable Handling
```python
# CHECK: Is sensitive data loaded securely?

import os
from pathlib import Path

# Option 1: File-based (preferred)
def load_token():
    token_path = Path.home() / '.friday' / '.hook_token'
    if token_path.exists():
        return token_path.read_text().strip()
    return None

# Option 2: Env with fallback
HOOK_TOKEN = os.environ.get('OPENCLAW_HOOK_TOKEN') or load_token()

# BAD - hardcoded:
HOOK_TOKEN = "sk-abc123..."  # NEVER DO THIS
```

### SECTION D: CRITICAL BUGS - CHECKLIST

Go through this list and verify EACH item:

| # | Check | File |
|---|-------|------|
| 1 | FridayService properly disposes recorder? | friday_service.dart |
| 2 | Audio temp files deleted after sending? | friday_service.dart |
| 3 | HTTP timeouts < 5 seconds? | friday_service.dart, device_provider.dart |
| 4 | All network calls have try-catch? | friday_service.dart |
| 5 | IsRecording state resets on error? | friday_service.dart |
| 6 | Fade animation doesn't block UI? | device_provider.dart |
| 7 | Sleep mode handles HTTP failure gracefully? | device_provider.dart |
| 8 | Brightness calc is 0.0-1.0 not 0-100? | (Python) |
| 9 | Alarm sync timeout is short? | alarm_service.dart |
| 10 | _currentFiringAlarm cleared on dismiss? | alarm_service.dart |
| 11 | Server validates audio size limit? | (Python) |
| 12 | Server handles malformed JSON? | (Python) |
| 13 | Server cleans up temp files? | (Python) |
| 14 | Server thread-safe for alarm state? | (Python) |
| 15 | ControlScreen buttons have min tap target (48dp)? | control_screen.dart |
| 16 | Recording indicator shows immediately? | control_screen.dart |
| 17 | Settings save asynchronously? | app_settings.dart |
| 18 | Providers rebuild efficiently? | main.dart |

---

## 🛠️ STEP 4: FIX ISSUES IMMEDIATELY

**RULE:** Don't just report bugs - FIX THEM.

**Procedure:**
1. If bug is minor (typo, missing const): Fix immediately
2. If bug is major (crash, security): Fix immediately, document
3. If bug needs design decision: Note in report, ask user if unclear

**Documentation format for each fix:**
```
FILE: lib/services/friday_service.dart
LINE: 45-52
BUG: Memory leak - temp audio file never deleted
FIX: Added file.deleteSync() after successful upload
CODE:
```dart
// OLD:
await http.post(...);

// NEW:
try {
  await http.post(...);
} finally {
  await File(audioPath).delete().catchError((_) {});
}
```
```

---

## ⚡ STEP 5: OPTIMIZE FOR SAMSUNG GALAXY J6

**Device Specs:**
- RAM: 2GB (likely ~800MB free for app)
- CPU: Exynos 7870 (octa-core 1.6GHz)
- Storage: 32GB eMMC (slow I/O)
- Android: 8.0 (API 26)

**Optimization Targets:**

### O1. Reduce Memory Allocations
```dart
// BEFORE:
List<int> bytes = [];  // Dynamic list, reallocates
for (var chunk in stream) {
  bytes.addAll(chunk);  // Grows, copies
}

// AFTER:
final bytes = Uint8List(totalSize);  // Pre-allocate
var offset = 0;
for (var chunk in stream) {
  bytes.setRange(offset, offset + chunk.length, chunk);
  offset += chunk.length;
}
```

### O2. Minimize Widget Rebuilds
```dart
// BEFORE:
setState(() => _isRecording = true);  // Rebuilds entire widget

// AFTER:
// Use ValueNotifier for local state
final _recordingNotifier = ValueNotifier<bool>(false);

// In build:
ValueListenableBuilder<bool>(
  valueListenable: _recordingNotifier,
  builder: (context, isRecording, child) {
    return IconButton(...);
  },
)
```

### O3. Offload Heavy Work to Isolate
```dart
import 'package:flutter/foundation.dart';

// BEFORE:
final base64 = base64Encode(audioBytes);  // Blocks UI on J6

// AFTER:
final base64 = await compute(base64Encode, audioBytes);
// Runs in separate isolate, doesn't block UI
```

### O4. Optimize Fade Animation
```dart
// BEFORE: 50 steps (too many for J6)
for (int i = 255; i >= 0; i -= 5) {  // 51 HTTP calls!
  await setBrightness(i);
  await Future.delayed(Duration(milliseconds: 30));
}

// AFTER: 10 steps (smooth enough, fewer calls)
const steps = 10;
for (int i = 0; i <= steps; i++) {
  final brightness = 255 * (steps - i) ~/ steps;
  await setBrightness(brightness);
  await Future.delayed(Duration(milliseconds: 50));
}
```

### O5. Compress Audio Before Send
```dart
// BEFORE: Send raw WAV (320KB for 10 seconds)
final base64 = base64Encode(audioBytes);

// AFTER: Compress with FLAC first (~100KB)
import 'package:flutter_flac/flutter_flac.dart';

final flacBytes = await FlutterFlac.encode(audioBytes);
final base64 = base64Encode(flacBytes);
```

---

## ✅ STEP 6: VERIFY BUILD AND RUN

### 6.1 Flutter Analysis
```bash
cd "/home/shreyansh/Documents/ESP 32 INFRA/Phone App"

# Check dependencies
flutter pub get

# Static analysis
flutter analyze

# Expected: 0 errors, 0 warnings (treat warnings as errors)

# Build APK
flutter build apk --release

# Expected: SUCCESS with APK at build/app/outputs/flutter-apk/app-release.apk
```

### 6.2 Python Server Verification
```bash
cd /home/shreyansh/.openclaw/workspace/scripts

# Syntax check
python3 -m py_compile friday_integration_server.py
# Expected: No output (success)

# Start server
gnome-terminal -- python3 friday_integration_server.py --port 41263 &
sleep 2

# Test health endpoint
curl -v http://localhost:41263/health
# Expected: {"status": "ok", "service": "friday_integration", ...}

# Test voice endpoint (with dummy data)
curl -X POST http://localhost:41263/hooks/voice \
  -H "Content-Type: application/json" \
  -d '{"audio": "dGVzdA==", "timestamp": "2024-01-01T00:00:00Z"}'

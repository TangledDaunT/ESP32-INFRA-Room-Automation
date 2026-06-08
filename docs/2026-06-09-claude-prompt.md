# Prompt for Claude Code - Friday Voice Integration Review

## Your Task

Review and debug the Friday voice command integration that was just implemented in the OpenClaw Remote Flutter app. This is critical production code that controls home automation (RGB lights, fan, alarms) - it must be bug-free and lag-free.

## Required Actions

### 1. READ THE SESSION SUMMARY FIRST
```
/home/shreyansh/.openclaw/workspace/memory/2026-06-09-session-summary.md
```

### 2. VERIFY ALL FILES EXIST AND ARE CORRECT

**Flutter Phone App:** `/home/shreyansh/Documents/ESP 32 INFRA/Phone App/`
- [ ] `lib/services/friday_service.dart` - Voice recording service
- [ ] `lib/models/friday_command.dart` - Data models
- [ ] `lib/screens/control_screen.dart` - UI buttons (modified)
- [ ] `lib/models/app_settings.dart` - Settings (modified)
- [ ] `lib/providers/device_provider.dart` - Sleep mode (modified)
- [ ] `lib/services/alarm_service.dart` - Alarm sync (modified)
- [ ] `lib/main.dart` - Provider wiring (modified)

**Python Server:** `/home/shreyansh/.openclaw/workspace/scripts/`
- [ ] `friday_integration_server.py` - Combined HTTP server
- [ ] `friday-integration.service` - Systemd service

### 3. PERFORM DEEP CODE REVIEW

Check for these specific issues:

#### PERFORMANCE & LAG
- [ ] **Audio recording**: Does `friday_service.dart` properly release resources after recording?
- [ ] **Memory leaks**: Are audio files cleaned up? Is base64 string cleared from memory?
- [ ] **Animation smoothness**: Is the fade-off in `activateSleepMode()` smooth (no jank)?
- [ ] **HTTP timeouts**: Are timeouts appropriate (not too long causing UI freeze)?
- [ ] **Provider rebuilds**: Do buttons cause excessive widget rebuilds?

#### BUGS & CRASHES
- [ ] **Null safety**: All nullable types properly handled?
- [ ] **Async/await**: Are all futures awaited? No unhandled exceptions?
- [ ] **File I/O**: Audio file read errors handled? Path null check?
- [ ] **Network errors**: HTTP failures show user-friendly messages?
- [ ] **Permissions**: Audio recording permissions requested?
- [ ] **State consistency**: Recording state accurate if app backgrounded?

#### SECURITY
- [ ] **Token handling**: Hook token not hardcoded, properly loaded from env?
- [ ] **Input validation**: Server validates audio size/format limits?
- [ ] **Path traversal**: Server safe from path traversal in filenames?

#### CORRECTNESS
- [ ] **Audio format**: Confirmed 16kHz WAV output? Not MP3/m4a?
- [ ] **Base64 encoding**: Properly formatted for transmission?
- [ ] **JSON parsing**: Both sides handle malformed JSON gracefully?
- [ ] **Clock drift**: Alarm scheduling uses correct timezone?
- [ ] **Brightness calculation**: xrandr uses 0.0-1.0, not 0-100?

#### EDGE CASES
- [ ] **Double-tap**: Can user double-tap Friday button causing issues?
- [ ] **Recording too short**: Handle < 500ms recordings?
- [ ] **Network down**: App handles offline mode gracefully?
- [ ] **Server restart**: Phone reconnects automatically?
- [ ] **Large audio**: Size limits enforced? (max ~500KB?)

### 4. FIX ANY ISSUES FOUND

If you find bugs, fix them immediately. Don't just report - fix.

### 5. OPTIMIZE FOR BEST PERFORMANCE

For Samsung Galaxy J6 (low-end device):
- Keep allocations minimal in hot paths
- Use `const` constructors where possible
- Avoid unnecessary widget rebuilds
- Keep HTTP payload small
- Optimize fade animation steps

### 6. VERIFY INTEGRATION

Run these checks:
```bash
# 1. Check Flutter imports resolve
cd /home/shreyansh/Documents/ESP\ 32\ INFRA/Phone\ App
flutter analyze

# 2. Check server syntax
cd /home/shreyansh/.openclaw/workspace/scripts
python3 -m py_compile friday_integration_server.py

# 3. Check server starts
python3 friday_integration_server.py --port 41263 &
curl http://localhost:41263/health
```

### 7. OUTPUT DELIVERABLES

Create:
1. **Bug report** - List any issues found and fixed
2. **Performance report** - Document optimizations made
3. **Test results** - Show that endpoints work correctly
4. **Updated files** - Any files you modified

### 8. SPECIFIC CODE SECTIONS TO SCRUTINIZE

**Critical Section 1: FridayService.toggleRecording()**
```dart
// CHECK: Is state properly synchronized?
// CHECK: Is file deleted after sending?
// CHECK: Is error handling complete?
```

**Critical Section 2: DeviceProvider.activateSleepMode()**
```dart
// CHECK: Does fade animation complete before next step?
// CHECK: Is http failure handled without breaking flow?
// CHECK: Is alarm scheduled with correct time?
```

**Critical Section 3: Python server voice handler**
```python
# CHECK: Is audio size limited to prevent DoS?
# CHECK: Are temp files cleaned up on error?
# CHECK: Is transcription async/non-blocking?
```

**Critical Section 4: Alarm sync**
```dart
// CHECK: Is _currentFiringAlarm cleared properly?
// CHECK: Is laptop notified on snooze AND dismiss?
// CHECK: Is timeout short enough for snooze UX?
```

### 9. ACCEPTANCE CRITERIA

Before marking complete, verify:
- [ ] `flutter build apk` succeeds with zero errors
- [ ] `flutter analyze` reports zero issues (or only approved ignores)
- [ ] Python server passes `python3 -m py_compile`
- [ ] All endpoints respond correctly to curl tests
- [ ] No obvious memory leaks in code review
- [ ] UI is responsive (no synchronous file/network on main thread)
- [ ] User gets clear feedback for all actions

### 10. BE THOROUGH

This code will be used daily. A bug means:
- Voice command doesn't work → frustration
- Sleep mode fails → lights stay on all night
- Alarm sync broken → oversleeping

Take the time to do this right.

---

## Context Reminders

**User is "Daddy"** - technical user, prefers working code over explanations. Be direct.

**Target device is Samsung Galaxy J6** - old, limited RAM. Performance matters.

**Network is local WiFi** - 192.168.1.15. Expect occasional packet loss.

**OpenClaw Gateway already exists** - don't break existing /hooks/wake, /hooks/agent.

**Friday is the AI assistant** - this integration lets user talk to Friday via phone.

---

## Output Format

Your final response should be:

```
## Summary
Brief: X bugs found, Y optimizations made, Z files modified.

## Bugs Fixed
1. [Description] → [Fix]
2. ...

## Performance Improvements
1. [What was slow] → [How fixed]
2. ...

## Test Results
```
[curl/terminal output showing working endpoints]
```

## Remaining Concerns
[Any technical debt or things needing manual testing]

## Files Modified
- `/path/to/file.dart` - [what changed]
- ...
```

Get to work. This needs to be bulletproof.

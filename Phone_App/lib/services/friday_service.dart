// lib/services/friday_service.dart
// Friday voice command service - records audio and sends to OpenClaw

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';

import '../models/app_settings.dart';

/// Manages voice recording and communication with Friday (OpenClaw AI)
///
/// - Records audio when user taps Friday button
/// - Sends audio to OpenClaw webhook for transcription
/// - Provides state management for UI feedback
class FridayService extends ChangeNotifier {
  static const Duration _requestTimeout = Duration(seconds: 5);

  AppSettings _settings;
  AudioRecorder? _recorder;
  
  bool _isRecording = false;
  String? _recordingPath;
  String? _lastError;
  DateTime? _recordingStartedAt;
  
  // Getters
  bool get isRecording => _isRecording;
  String? get lastError => _lastError;
  Uri get voiceEndpoint => Uri.parse('${_settings.fridayBaseUrl}/hooks/voice');
  Map<String, String> get requestHeaders => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${_settings.fridayHookToken}',
      };
  Duration? get recordingDuration => 
      _recordingStartedAt != null 
          ? DateTime.now().difference(_recordingStartedAt!) 
          : null;
  AudioRecorder get _audioRecorder => _recorder ??= AudioRecorder();
  
  /// Stream for recording state updates
  final _recordingController = StreamController<bool>.broadcast();
  Stream<bool> get recordingState => _recordingController.stream;

  FridayService({required AppSettings settings}) : _settings = settings;

  /// Initialize and request permissions
  Future<bool> initialize() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        _lastError = 'Microphone permission denied';
        notifyListeners();
        return false;
      }
      return true;
    } catch (e) {
      _lastError = 'Failed to initialize: $e';
      notifyListeners();
      return false;
    }
  }

  /// Toggle recording on/off
  /// When stopping, sends audio to Friday
  Future<void> toggleRecording() async {
    if (_isRecording) {
      await _stopAndSend();
    } else {
      await _startRecording();
    }
  }

  /// Start recording audio
  Future<void> _startRecording() async {
    try {
      // Check permission first
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        throw Exception('Microphone permission denied');
      }

      final tempDir = Directory.systemTemp;
      _recordingPath =
          '${tempDir.path}/friday_command_${DateTime.now().millisecondsSinceEpoch}.wav';
      
      // Configure for optimal voice recording
      const config = RecordConfig(
        encoder: AudioEncoder.wav,
        bitRate: 128000,
        sampleRate: 16000, // Whisper-optimized
        numChannels: 1, // Mono
      );

      await _audioRecorder.start(config, path: _recordingPath!);
      
      _isRecording = true;
      _recordingStartedAt = DateTime.now();
      _lastError = null;
      _recordingController.add(true);
      notifyListeners();

      debugPrint('[FridayService] Started recording to $_recordingPath');
    } catch (e) {
      _lastError = 'Failed to start recording: $e';
      _isRecording = false;
      notifyListeners();
      debugPrint('[FridayService] Error starting recording: $e');
    }
  }

  /// Stop recording and send to Friday
  Future<void> _stopAndSend() async {
    String? path;
    try {
      // Stop recording
      path = await _audioRecorder.stop();
      _isRecording = false;
      _recordingStartedAt = null;
      _recordingController.add(false);
      notifyListeners();

      if (path == null || path.isEmpty) {
        debugPrint('[FridayService] No recording captured');
        return;
      }

      debugPrint('[FridayService] Stopped recording, sending to Friday...');

      // Send to Friday
      try {
        await _sendToFriday(path);
      } finally {
        // Cleanup temp file even if send fails
        await _cleanupRecording(path);
      }

    } catch (e) {
      _lastError = 'Failed to stop/send: $e';
      _isRecording = false;
      _recordingStartedAt = null;
      notifyListeners();
      debugPrint('[FridayService] Error stopping/sending: $e');
      if (path != null) {
        await _cleanupRecording(path);
      }
    }
  }

  /// Send audio file to OpenClaw webhook
  Future<void> _sendToFriday(String audioPath) async {
    try {
      // Read audio file
      final audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        throw Exception('Audio file not found');
      }

      final audioBytes = await audioFile.readAsBytes();
      final base64Audio = await compute(base64Encode, audioBytes);

      // Prepare payload
      final payload = {
        'audio': base64Audio,
        'timestamp': DateTime.now().toIso8601String(),
        'format': 'wav',
        'sampleRate': 16000,
        'source': 'openclaw_remote_app',
      };

      // Send to Friday
      final response = await http.post(
        voiceEndpoint,
        headers: requestHeaders,
        body: jsonEncode(payload),
      ).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        debugPrint('[FridayService] Audio sent successfully');
      } else {
        debugPrint('[FridayService] Failed to send: ${response.statusCode} - ${response.body}');
        _lastError = 'Server error: ${response.statusCode}';
        notifyListeners();
      }
    } on TimeoutException {
      _lastError = 'Connection timeout - is the laptop online?';
      notifyListeners();
      debugPrint('[FridayService] Timeout sending to Friday');
    } catch (e) {
      _lastError = 'Failed to send: $e';
      notifyListeners();
      debugPrint('[FridayService] Error sending to Friday: $e');
    }
  }

  /// Cleanup recording file
  Future<void> _cleanupRecording(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[FridayService] Cleaned up recording file');
      }
    } catch (e) {
      debugPrint('[FridayService] Failed to cleanup: $e');
    }
  }

  /// Force stop recording without sending (for UI cancel)
  Future<void> cancelRecording() async {
    if (_isRecording) {
      try {
        final path = await _audioRecorder.stop();
        _isRecording = false;
        _recordingStartedAt = null;
        _recordingController.add(false);
        notifyListeners();
        
        if (path != null) {
          await _cleanupRecording(path);
        }
      } catch (e) {
        debugPrint('[FridayService] Error canceling: $e');
      }
    }
  }

  /// Force send last recording (for retry)
  Future<void> retryLastSend() async {
    if (_recordingPath != null && await File(_recordingPath!).exists()) {
      try {
        await _sendToFriday(_recordingPath!);
      } finally {
        await _cleanupRecording(_recordingPath!);
      }
    }
  }

  /// Update settings reference
  void updateSettings(AppSettings settings) {
    _settings = settings;
  }

  @override
  void dispose() {
    _recordingController.close();
    if (_isRecording) {
      _recorder?.stop();
    }
    _recorder?.dispose();
    super.dispose();
  }
}

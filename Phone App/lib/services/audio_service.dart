// lib/services/audio_service.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';

class AudioService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  Stream<Uint8List>? _pcmStream;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  /// Starts recording a 16-bit PCM mono stream at 16000 Hz.
  /// This is optimized for low-end devices and voice/clap frequencies.
  Future<Stream<Uint8List>?> startPcmStream() async {
    if (_isRunning) return _pcmStream;

    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) return null;

    try {
      _pcmStream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
      _isRunning = true;
      return _pcmStream;
    } catch (e) {
      _isRunning = false;
      return null;
    }
  }

  void stop() {
    if (!_isRunning) return;
    _audioRecorder.stop();
    _isRunning = false;
    _pcmStream = null;
  }

  void dispose() {
    _audioRecorder.dispose();
  }
}

// lib/services/clap_detector.dart
import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:fftea/fftea.dart';
import 'audio_service.dart';

typedef ClapCallback = void Function();
typedef DbCallback = void Function(double db);

/// Messages sent to the isolate
abstract class IsolateMsg {}

class AudioChunkMsg extends IsolateMsg {
  final Uint8List chunk;
  AudioChunkMsg(this.chunk);
}

class UpdateSettingsMsg extends IsolateMsg {
  final double sensitivity;
  UpdateSettingsMsg(this.sensitivity);
}

/// Messages received from the isolate
abstract class MainMsg {}

class ClapDetectedMsg extends MainMsg {}

class RmsUpdateMsg extends MainMsg {
  final double db;
  RmsUpdateMsg(this.db);
}

class ClapDetector {
  final AudioService _audioService = AudioService();
  StreamSubscription<Uint8List>? _audioSubscription;

  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;

  ClapCallback? onSingleClap;
  ClapCallback? onDoubleClap;
  DbCallback? onDbUpdate;

  bool _isRunning = false;

  // Double clap state
  int _clapCount = 0;
  Timer? _clapResetTimer;
  final int clapWindowMs;

  ClapDetector({this.clapWindowMs = 1500});

  bool get isRunning => _isRunning;

  Future<bool> start() async {
    if (_isRunning) return true;

    // 1. Setup Isolate
    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_dspIsolateEntry, _receivePort!.sendPort);

    // 2. Listen to Isolate messages
    final broadcastPort = _receivePort!.asBroadcastStream();
    _sendPort =
        await broadcastPort.first as SendPort; // First message is SendPort

    broadcastPort.listen((message) {
      if (message is ClapDetectedMsg) {
        _handleSingleClap();
      } else if (message is RmsUpdateMsg) {
        onDbUpdate?.call(message.db);
      }
    });

    // 3. Start Audio Stream
    final stream = await _audioService.startPcmStream();
    if (stream == null) {
      stop();
      return false;
    }

    // 4. Forward audio chunks to isolate
    _audioSubscription = stream.listen(
      (data) {
        _sendPort?.send(AudioChunkMsg(data));
      },
      onError: (e) {
        stop();
        Future.delayed(const Duration(seconds: 2), start);
      },
      cancelOnError: false,
    );

    _isRunning = true;
    return true;
  }

  void _handleSingleClap() {
    onSingleClap?.call();

    _clapCount++;
    if (_clapCount >= 2) {
      _clapCount = 0;
      _clapResetTimer?.cancel();
      onDoubleClap?.call();
    } else {
      _clapResetTimer?.cancel();
      _clapResetTimer = Timer(Duration(milliseconds: clapWindowMs), () {
        _clapCount = 0;
      });
    }
  }

  void stop() {
    _audioSubscription?.cancel();
    _audioSubscription = null;
    _audioService.stop();
    _receivePort?.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    _isRunning = false;
    _clapResetTimer?.cancel();
  }

  void dispose() {
    stop();
    _audioService.dispose();
  }

  // ─── ISOLATE LOGIC ────────────────────────────────────────────────────────

  static void _dspIsolateEntry(SendPort sendPort) {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort); // Send back port for two-way comms

    final List<int> audioBuffer = [];
    const int frameSize = 1024;

    // Rolling noise floor (last 2 seconds = ~31 frames)
    final List<double> rmsHistory = [];
    const int historySize = 31;

    // State for clap validation
    int cooldownFrames = 0; // Prevent rapid triggers

    receivePort.listen((message) {
      if (message is AudioChunkMsg) {
        // Convert Uint8List (bytes) to 16-bit PCM samples
        final bytes = message.chunk;
        final int16List = Int16List.view(
            bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes ~/ 2);
        audioBuffer.addAll(int16List);

        // Process frames
        while (audioBuffer.length >= frameSize) {
          final frame = audioBuffer.sublist(0, frameSize);
          audioBuffer.removeRange(0, frameSize);

          if (cooldownFrames > 0) cooldownFrames--;

          // 1. RMS Calculation
          double sumSquares = 0;
          for (var sample in frame) {
            sumSquares += (sample * sample);
          }
          final rms = sqrt(sumSquares / frameSize);

          // Convert RMS to an approximate decibel value (relative to max 16-bit)
          // Int16 max is 32767. We map 0 to -inf, max to ~90dB.
          // For simplicity, a relative 0-100 scale:
          final db = rms > 0 ? 20 * log10(rms) : 0.0;
          sendPort.send(RmsUpdateMsg(db));

          // Maintain noise floor history
          rmsHistory.add(rms);
          if (rmsHistory.length > historySize) rmsHistory.removeAt(0);

          if (rmsHistory.length < 5 || cooldownFrames > 0) continue;

          final noiseFloor =
              rmsHistory.reduce((a, b) => a + b) / rmsHistory.length;

          // 2. Spike Detection
          // If RMS is suddenly much higher than noise floor (e.g., 4x) and meets minimum absolute energy
          if (rms > noiseFloor * 4.0 && rms > 1500) {
            // 3. FFT Frequency Filtering
            // We want to verify that the energy is concentrated in high frequencies (clap)
            final floatFrame = Float64List(frameSize);
            for (int i = 0; i < frameSize; i++) {
              floatFrame[i] = frame[i].toDouble();
            }

            // Using FFTea FFT directly
            final fft = FFT(frameSize);
            final spectrum = fft.realFft(floatFrame);
            final magnitudes = spectrum.magnitudes();

            // 16000Hz sample rate. Nyquist is 8000Hz. frameSize is 1024.
            // Each bin is 8000 / 512 = ~15.625 Hz.
            // Low band: 0 - 500 Hz (Bins 0 to 32)
            // Clap band: 2000 - 4000 Hz (Bins 128 to 256)

            double lowEnergy = 0;
            double clapEnergy = 0;

            for (int i = 0; i < 32; i++) {
              lowEnergy += magnitudes[i];
            }
            for (int i = 128; i < 256; i++) {
              clapEnergy += magnitudes[i];
            }

            // 4. Multi-Condition Validation
            // A clap should have significant energy in the high band compared to low band
            if (clapEnergy > lowEnergy * 0.8) {
              // Needs tuning, claps are broadband but less bassy than speech
              sendPort.send(ClapDetectedMsg());
              cooldownFrames = 5; // ~300ms cooldown (5 * 64ms)
            }
          }
        }
      }
    });
  }

  static double log10(num x) => log(x) / ln10;
}

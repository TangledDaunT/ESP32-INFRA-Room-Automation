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
  
  final double clapDbThreshold;
  final int clapWindowMs;

  ClapDetector({
    this.clapDbThreshold = 15.0,
    this.clapWindowMs = 1500,
  });

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

    // Send initial settings to isolate
    _sendPort?.send(UpdateSettingsMsg(clapDbThreshold));

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

  void updateSettings(double sensitivity) {
    _sendPort?.send(UpdateSettingsMsg(sensitivity));
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
    double dbThreshold = 15.0; // Default matching AppSettings

    receivePort.listen((message) {
      if (message is UpdateSettingsMsg) {
        dbThreshold = message.sensitivity;
      } else if (message is AudioChunkMsg) {
        // Convert Uint8List (bytes) to 16-bit PCM samples
        final bytes = message.chunk;
        
        final Int16List int16List;
        if (bytes.offsetInBytes % 2 == 0) {
          int16List = Int16List.view(
              bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes ~/ 2);
        } else {
          // If the buffer is not aligned, we make an aligned copy
          final alignedBytes = Uint8List.fromList(bytes);
          int16List = Int16List.view(
              alignedBytes.buffer, 0, alignedBytes.lengthInBytes ~/ 2);
        }
        
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
          final db = rms > 0 ? 20 * log10(rms) : 0.0;
          sendPort.send(RmsUpdateMsg(db));

          // Maintain noise floor history
          rmsHistory.add(rms);
          if (rmsHistory.length > historySize) rmsHistory.removeAt(0);

          if (rmsHistory.length < 5 || cooldownFrames > 0) continue;

          final noiseFloor =
              rmsHistory.reduce((a, b) => a + b) / rmsHistory.length;

          // 2. Spike Detection
          // Convert dbThreshold setting to linear ratio.
          final double ratio = pow(10.0, dbThreshold / 20.0).toDouble();
          
          if (rms > noiseFloor * ratio && rms > 800) {
            // 3. FFT Frequency Filtering
            final floatFrame = Float64List(frameSize);
            for (int i = 0; i < frameSize; i++) {
              floatFrame[i] = frame[i].toDouble();
            }

            // Using FFTea FFT directly
            final fft = FFT(frameSize);
            final spectrum = fft.realFft(floatFrame);
            final magnitudes = spectrum.magnitudes();

            double lowEnergy = 0;
            double clapEnergy = 0;

            for (int i = 0; i < 32; i++) {
              lowEnergy += magnitudes[i];
            }
            for (int i = 128; i < 256; i++) {
              clapEnergy += magnitudes[i];
            }

            // 4. Multi-Condition Validation
            if (clapEnergy > lowEnergy * 0.8) {
              sendPort.send(ClapDetectedMsg());
              cooldownFrames = 8; // ~512ms cooldown (8 * 64ms)
            }
          }
        }
      }
    });
  }

  static double log10(num x) => log(x) / ln10;
}

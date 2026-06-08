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
  final Map<String, dynamic> settings;
  UpdateSettingsMsg(this.settings);
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
    _sendPort?.send(UpdateSettingsMsg({'clapDbThreshold': clapDbThreshold, 'clapWindowMs': clapWindowMs}));

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

  void updateSettings(Map<String, dynamic> settings) {
    _sendPort?.send(UpdateSettingsMsg(settings));
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
    const int sampleRate = 16000;

    // Rolling noise floor (last 2 seconds = ~31 frames)
    final List<double> rmsHistory = [];
    const int historySize = 31;

    // State for clap validation
    int cooldownFrames = 0; // Prevent rapid triggers
    double dbThreshold = 15.0; // Default matching AppSettings
    double clapMinFreqKhz = 2.0;
    double clapMaxFreqKhz = 8.0;
    int clapMinAttackMs = 1;
    int clapMaxDurationMs = 150;
    double clapEnergyRatio = 3.0;
    int clapCooldownMs = 2000;
    bool clapHighPassEnabled = true;
    final int frameDurationMs = ((frameSize / sampleRate) * 1000).round();
    int requiredConsecutive = 1;

    receivePort.listen((message) {
      if (message is UpdateSettingsMsg) {
        final s = message.settings;
        if (s.containsKey('clapDbThreshold')) dbThreshold = (s['clapDbThreshold'] ?? dbThreshold).toDouble();
        if (s.containsKey('clapMinFreqKhz')) clapMinFreqKhz = (s['clapMinFreqKhz'] ?? clapMinFreqKhz).toDouble();
        if (s.containsKey('clapMaxFreqKhz')) clapMaxFreqKhz = (s['clapMaxFreqKhz'] ?? clapMaxFreqKhz).toDouble();
        if (s.containsKey('clapMinAttackMs')) clapMinAttackMs = s['clapMinAttackMs'] ?? clapMinAttackMs;
        if (s.containsKey('clapMaxDurationMs')) clapMaxDurationMs = s['clapMaxDurationMs'] ?? clapMaxDurationMs;
        if (s.containsKey('clapEnergyRatio')) clapEnergyRatio = (s['clapEnergyRatio'] ?? clapEnergyRatio).toDouble();
        if (s.containsKey('clapCooldownMs')) clapCooldownMs = s['clapCooldownMs'] ?? clapCooldownMs;
        if (s.containsKey('clapHighPassEnabled')) clapHighPassEnabled = s['clapHighPassEnabled'] ?? clapHighPassEnabled;
        // Convert cooldown ms to frames
        cooldownFrames =  (clapCooldownMs / (frameSize / sampleRate * 1000)).round();
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
          // 2. Adaptive threshold: combine ratio + absolute floor
          final double ratio = pow(10.0, dbThreshold / 20.0).toDouble();
          final double dynamicThreshold = noiseFloor * ratio + 200.0; // absolute floor

          if (rms > dynamicThreshold) {
            // 3. Pre-processing: optional high-pass to remove fan/EMI
            Float64List floatFrame = Float64List(frameSize);
            for (int i = 0; i < frameSize; i++) {
              floatFrame[i] = frame[i].toDouble();
            }

            if (clapHighPassEnabled) {
              // simple 1st-order high-pass (per-sample)
              double hpPrevInput = 0.0;
              double hpPrevOutput = 0.0;
              const double hpAlpha = 0.95; // tuned for ~100Hz cutoff at 16kHz
              for (int i = 0; i < frameSize; i++) {
                final input = floatFrame[i];
                final output = hpAlpha * (hpPrevOutput + input - hpPrevInput);
                hpPrevInput = input;
                hpPrevOutput = output;
                floatFrame[i] = output;
              }
            }

            // 4. FFT and band energy calculation
            final fft = FFT(frameSize);
            final spectrum = fft.realFft(floatFrame);
            final magnitudes = spectrum.magnitudes();

            final int clapBandStart = ((clapMinFreqKhz * 1000) * frameSize / sampleRate).round();
            final int clapBandEnd = ((clapMaxFreqKhz * 1000) * frameSize / sampleRate).round();
            final int lowNoiseBand = ((500) * frameSize / sampleRate).round();

            double clapEnergy = 0.0;
            double lowEnergy = 0.0;
            double totalEnergy = 0.0;
            for (int i = 0; i < magnitudes.length; i++) {
              final v = magnitudes[i];
              totalEnergy += v;
              if (i <= lowNoiseBand) lowEnergy += v;
              if (i >= clapBandStart && i <= clapBandEnd) clapEnergy += v;
            }

            final clapRatio = clapEnergy / (lowEnergy + 1.0);

            // 5. Attack-speed check (simple derivative)
            // store previous RMS in static-like closure by using a map holder
            // For simplicity, keep previousRms local static via a list
            // We will reuse rmsHistory last value as previous
            final double previousRms = rmsHistory.isNotEmpty ? rmsHistory.last : 0.0;
            final double attackSpeed = rms - previousRms;

            if (attackSpeed > 0 && clapRatio >= clapEnergyRatio) {
              // Duration check: approximate via frameDurationMs
              if (frameDurationMs <= clapMaxDurationMs) {
                sendPort.send(ClapDetectedMsg());
                cooldownFrames = (clapCooldownMs / (frameDurationMs)).round();
              }
            }
          }
        }
      }
    });
  }

  static double log10(num x) => log(x) / ln10;
}

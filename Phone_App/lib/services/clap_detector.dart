// lib/services/clap_detector.dart
import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
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
  VoidCallback? onClapDetectorFailed;
  VoidCallback? onClapDetectorRecovered;

  bool _isRunning = false;
  int _restartCount = 0;
  DateTime? _firstRestartAt;

  // Double clap state
  int _clapCount = 0;
  Timer? _clapResetTimer;
  
  final double clapDbThreshold;
  final int clapWindowMs;

  ClapDetector({
    // Kept in sync with AppSettings' default (8.0) — a caller that omits
    // this should behave the same as a fresh install.
    this.clapDbThreshold = 8.0,
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
        _restartCount++;
        _firstRestartAt ??= DateTime.now();
        if (_restartCount > 3 &&
            DateTime.now().difference(_firstRestartAt!) < const Duration(seconds: 60)) {
          onClapDetectorFailed?.call();
          return;
        }
        Future.delayed(const Duration(seconds: 2), start);
      },
      cancelOnError: false,
    );

    _isRunning = true;
    if (_restartCount > 0) {
      onClapDetectorRecovered?.call();
    }
    _restartCount = 0;
    _firstRestartAt = null;
    return true;
  }

  void updateSettings(Map<String, dynamic> settings) {
    _sendPort?.send(UpdateSettingsMsg(settings));
  }

  void _handleSingleClap() {
    _clapCount++;
    if (_clapCount >= 2) {
      // Second clap of the pair — report only the double-clap, not a
      // redundant single-clap for the same gesture.
      _clapCount = 0;
      _clapResetTimer?.cancel();
      onDoubleClap?.call();
    } else {
      onSingleClap?.call();
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

    const int frameSize = 1024;
    const int sampleRate = 16000;
    final _RingBuffer audioBuffer = _RingBuffer(frameSize * 4);
    // Reused across every candidate frame — a fresh FFT plan/twiddle-table
    // allocation per clap was avoidable CPU/GC churn on weak hardware.
    final FFT fft = FFT(frameSize);

    // Rolling noise floor (last 2 seconds = ~31 frames)
    final List<double> rmsHistory = [];
    const int historySize = 31;

    // State for clap validation
    int cooldownFrames = 0; // Prevent rapid triggers
    int consecutiveAboveThreshold = 0; // frames the RMS has stayed elevated
    double dbThreshold = 15.0; // Default matching AppSettings
    double clapMinFreqKhz = 2.0;
    double clapMaxFreqKhz = 8.0;
    int clapMinAttackMs = 1;
    int clapMaxDurationMs = 150;
    double clapEnergyRatio = 3.0;
    int clapCooldownMs = 2000;
    bool clapHighPassEnabled = true;
    final int frameDurationMs = ((frameSize / sampleRate) * 1000).round();

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
          final frame = audioBuffer.takeFrame(frameSize);

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

          // Capture the *previous* frame's RMS before this frame overwrites
          // rmsHistory's tail — reading rmsHistory.last after the add() below
          // would just be this frame's own rms, making attack-speed always 0.
          final double previousRms = rmsHistory.isNotEmpty ? rmsHistory.last : rms;

          // Maintain noise floor history
          rmsHistory.add(rms);
          if (rmsHistory.length > historySize) rmsHistory.removeAt(0);

          if (rms > dynamicRmsThreshold(rmsHistory, dbThreshold)) {
            consecutiveAboveThreshold++;
          } else {
            consecutiveAboveThreshold = 0;
          }

          if (rmsHistory.length < 5 || cooldownFrames > 0) continue;

          final dynamicThreshold = dynamicRmsThreshold(rmsHistory, dbThreshold);

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

            // 4. FFT and band energy calculation (fft instance reused above)
            final spectrum = fft.realFft(floatFrame);
            final magnitudes = spectrum.magnitudes();

            final int clapBandStart = ((clapMinFreqKhz * 1000) * frameSize / sampleRate).round();
            final int clapBandEnd = ((clapMaxFreqKhz * 1000) * frameSize / sampleRate).round();
            final int lowNoiseBand = ((500) * frameSize / sampleRate).round();

            double clapEnergy = 0.0;
            double lowEnergy = 0.0;
            for (int i = 0; i < magnitudes.length; i++) {
              final v = magnitudes[i];
              if (i <= lowNoiseBand) lowEnergy += v;
              if (i >= clapBandStart && i <= clapBandEnd) clapEnergy += v;
            }

            final clapRatio = clapEnergy / (lowEnergy + 1.0);

            // 5. Attack-speed check (simple derivative vs the prior frame)
            final double attackSpeed = rms - previousRms;

            if (attackSpeed > 0 && clapRatio >= clapEnergyRatio) {
              // Duration check: reject sounds that have already been
              // elevated for longer than clapMaxDurationMs — a real clap is
              // a brief transient, not a sustained loud sound. Resolution
              // is limited to one frame period (~frameDurationMs).
              final eventDurationMs = consecutiveAboveThreshold * frameDurationMs;
              if (eventDurationMs <= clapMaxDurationMs) {
                sendPort.send(ClapDetectedMsg());
                cooldownFrames = (clapCooldownMs / frameDurationMs).round();
              }
            }
          }
        }
      }
    });
  }

  static double log10(num x) => log(x) / ln10;
}

/// Adaptive RMS threshold: noise floor (rolling average) scaled by the
/// configured dB ratio, plus a small absolute floor.
double dynamicRmsThreshold(List<double> rmsHistory, double dbThresholdDb) {
  final noiseFloor = rmsHistory.reduce((a, b) => a + b) / rmsHistory.length;
  final ratio = pow(10.0, dbThresholdDb / 20.0).toDouble();
  return noiseFloor * ratio + 200.0;
}

/// Fixed-capacity ring buffer of 16-bit PCM samples for the always-on DSP
/// isolate. Frames are extracted with [takeFrame], which advances the read
/// cursor in O(frameSize) — unlike a plain `List<int>` drained with
/// `sublist`+`removeRange`, which shifts the entire remaining backlog on
/// every single frame for the lifetime of the isolate.
class _RingBuffer {
  _RingBuffer(int capacity) : _data = Int16List(capacity);

  final Int16List _data;
  int _start = 0;
  int _length = 0;

  int get length => _length;

  void addAll(Int16List samples) {
    final capacity = _data.length;
    for (final sample in samples) {
      _data[(_start + _length) % capacity] = sample;
      if (_length < capacity) {
        _length++;
      } else {
        // Buffer is full (processing fell behind) — drop the oldest sample.
        _start = (_start + 1) % capacity;
      }
    }
  }

  /// Copies out the oldest [frameSize] samples and advances past them.
  Int16List takeFrame(int frameSize) {
    final capacity = _data.length;
    final frame = Int16List(frameSize);
    for (int i = 0; i < frameSize; i++) {
      frame[i] = _data[(_start + i) % capacity];
    }
    _start = (_start + frameSize) % capacity;
    _length -= frameSize;
    return frame;
  }
}

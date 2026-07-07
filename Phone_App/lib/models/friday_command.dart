// lib/models/friday_command.dart
// Model for Friday voice command responses

/// Represents a voice command sent to Friday
class FridayCommand {
  final String id;
  final String? transcription;
  final String audioBase64;
  final DateTime timestamp;
  final CommandStatus status;
  final String? response;
  final Map<String, dynamic>? intent;
  final Map<String, dynamic>? actions;
  final String? error;

  const FridayCommand({
    required this.id,
    this.transcription,
    required this.audioBase64,
    required this.timestamp,
    this.status = CommandStatus.pending,
    this.response,
    this.intent,
    this.actions,
    this.error,
  });

  /// Create from JSON payload received from phone
  factory FridayCommand.fromPhonePayload(Map<String, dynamic> json) {
    return FridayCommand(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      audioBase64: json['audio'] ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      status: CommandStatus.pending,
    );
  }

  /// Create from JSON after processing
  factory FridayCommand.fromJson(Map<String, dynamic> json) {
    return FridayCommand(
      id: json['id'] ?? '',
      transcription: json['transcription'],
      audioBase64: json['audioBase64'] ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      status: CommandStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => CommandStatus.pending,
      ),
      response: json['response'],
      intent: json['intent'] != null ? Map<String, dynamic>.from(json['intent']) : null,
      actions: json['actions'] != null ? Map<String, dynamic>.from(json['actions']) : null,
      error: json['error'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'transcription': transcription,
        'audioBase64': audioBase64,
        'timestamp': timestamp.toIso8601String(),
        'status': status.name,
        'response': response,
        'intent': intent,
        'actions': actions,
        'error': error,
      };

  FridayCommand copyWith({
    String? id,
    String? transcription,
    String? audioBase64,
    DateTime? timestamp,
    CommandStatus? status,
    String? response,
    Map<String, dynamic>? intent,
    Map<String, dynamic>? actions,
    String? error,
  }) {
    return FridayCommand(
      id: id ?? this.id,
      transcription: transcription ?? this.transcription,
      audioBase64: audioBase64 ?? this.audioBase64,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      response: response ?? this.response,
      intent: intent ?? this.intent,
      actions: actions ?? this.actions,
      error: error ?? this.error,
    );
  }

  /// Check if command was successful
  bool get isSuccess => status == CommandStatus.completed && error == null;

  /// Get display text for UI
  String get displayText {
    if (transcription != null && transcription!.isNotEmpty) {
      return transcription!;
    }
    if (error != null && error!.isNotEmpty) {
      return 'Error: $error';
    }
    return 'Processing...';
  }
}

/// Status of a Friday command
enum CommandStatus {
  pending,     // Just received, waiting
  transcribing, // Transcribing audio
  processing,  // AI processing
  completed,   // Done, has response
  failed,      // Error occurred
}

/// Represents a processed voice command with device actions
class VoiceIntent {
  final String command; // e.g., "turn on the lights"
  final IntentType type;
  final Map<String, dynamic> parameters;
  final double confidence;

  const VoiceIntent({
    required this.command,
    required this.type,
    required this.parameters,
    required this.confidence,
  });

  factory VoiceIntent.fromJson(Map<String, dynamic> json) {
    return VoiceIntent(
      command: json['command'] ?? '',
      type: IntentType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => IntentType.unknown,
      ),
      parameters: Map<String, dynamic>.from(json['parameters'] ?? {}),
      confidence: (json['confidence'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'command': command,
        'type': type.name,
        'parameters': parameters,
        'confidence': confidence,
      };
}

/// Types of voice intents
enum IntentType {
  turnOn,       // Turn on device
  turnOff,      // Turn off device
  setBrightness, // Adjust brightness
  setColor,     // Set RGB color
  sleep,        // Activate sleep mode
  wake,         // Wake up mode
  query,        // Ask question
  unknown,      // Couldn't understand
}

/// Actions that can be executed from voice commands
class DeviceAction {
  final String device; // e.g., 'rgb', 'light', 'fan', 'socket'
  final String action; // e.g., 'setOn', 'setOff', 'setBrightness'
  final dynamic value;  // e.g., true, 200, 'red'

  const DeviceAction({
    required this.device,
    required this.action,
    this.value,
  });

  factory DeviceAction.fromJson(Map<String, dynamic> json) {
    return DeviceAction(
      device: json['device'] ?? '',
      action: json['action'] ?? '',
      value: json['value'],
    );
  }

  Map<String, dynamic> toJson() => {
        'device': device,
        'action': action,
        'value': value,
      };
}

/// Sleep/Wake configuration
class SleepConfig {
  final Duration duration;  // Default 5:30 hours
  final bool turnOffRgb;
  final bool turnOffBackup;
  final bool setLaptopBrightness;
  final int laptopBrightnessValue;
  final bool playAlarmOnLaptop;

  const SleepConfig({
    this.duration = const Duration(hours: 5, minutes: 30),
    this.turnOffRgb = true,
    this.turnOffBackup = true,
    this.setLaptopBrightness = true,
    this.laptopBrightnessValue = 0,
    this.playAlarmOnLaptop = true,
  });

  factory SleepConfig.fromJson(Map<String, dynamic> json) {
    return SleepConfig(
      duration: Duration(
        hours: json['hours'] ?? 5,
        minutes: json['minutes'] ?? 30,
      ),
      turnOffRgb: json['turnOffRgb'] ?? true,
      turnOffBackup: json['turnOffBackup'] ?? true,
      setLaptopBrightness: json['setLaptopBrightness'] ?? true,
      laptopBrightnessValue: json['laptopBrightnessValue'] ?? 0,
      playAlarmOnLaptop: json['playAlarmOnLaptop'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'hours': duration.inHours,
        'minutes': duration.inMinutes % 60,
        'turnOffRgb': turnOffRgb,
        'turnOffBackup': turnOffBackup,
        'setLaptopBrightness': setLaptopBrightness,
        'laptopBrightnessValue': laptopBrightnessValue,
        'playAlarmOnLaptop': playAlarmOnLaptop,
      };

  /// Calculate wakeup time from current time
  DateTime getWakeupTime(DateTime from) {
    return from.add(duration);
  }
}

/// Cross-device alarm synchronization
class AlarmSync {
  final String alarmId;
  final String label;
  final DateTime scheduledTime;
  final bool playOnPhone;
  final bool playOnLaptop;
  final AlarmSyncStatus syncStatus;

  const AlarmSync({
    required this.alarmId,
    required this.label,
    required this.scheduledTime,
    this.playOnPhone = true,
    this.playOnLaptop = true,
    this.syncStatus = AlarmSyncStatus.pending,
  });

  factory AlarmSync.fromJson(Map<String, dynamic> json) {
    return AlarmSync(
      alarmId: json['alarm_id'] ?? '',
      label: json['label'] ?? '',
      scheduledTime: DateTime.tryParse(json['scheduled_time'] ?? '') ?? DateTime.now(),
      playOnPhone: json['play_on_phone'] ?? true,
      playOnLaptop: json['play_on_laptop'] ?? true,
      syncStatus: AlarmSyncStatus.values.firstWhere(
        (e) => e.name == json['sync_status'],
        orElse: () => AlarmSyncStatus.pending,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'alarm_id': alarmId,
        'label': label,
        'scheduled_time': scheduledTime.toIso8601String(),
        'play_on_phone': playOnPhone,
        'play_on_laptop': playOnLaptop,
        'sync_status': syncStatus.name,
      };
}

enum AlarmSyncStatus {
  pending,
  phoneAck,
  laptopAck,
  synced,
  failed,
}

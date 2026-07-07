class MacSystemStatus {
  const MacSystemStatus({
    required this.reachable,
    required this.cpuPercent,
    required this.memoryPercent,
    required this.diskPercent,
    required this.timestamp,
    this.batteryPercent,
    this.batteryCharging,
    this.wifiSsid,
    this.wifiDevice,
    this.hostname,
    this.macosVersion,
    this.uptimeSeconds,
    this.agentCpuPercent,
    this.agentMemoryMb,
  });

  final bool reachable;
  final double? batteryPercent;
  final bool? batteryCharging;
  final String? wifiSsid;
  final String? wifiDevice;
  final double cpuPercent;
  final double memoryPercent;
  final double diskPercent;
  final double timestamp;
  final String? hostname;
  final String? macosVersion;
  final double? uptimeSeconds;
  final double? agentCpuPercent;
  final double? agentMemoryMb;

  factory MacSystemStatus.fromJson(Map<String, dynamic> json) {
    return MacSystemStatus(
      reachable: json['reachable'] == true,
      batteryPercent: (json['batteryPercent'] as num?)?.toDouble(),
      batteryCharging: json['batteryCharging'] as bool?,
      wifiSsid: json['wifiSsid']?.toString(),
      wifiDevice: json['wifiDevice']?.toString(),
      cpuPercent: (json['cpuPercent'] as num?)?.toDouble() ?? 0,
      memoryPercent: (json['memoryPercent'] as num?)?.toDouble() ?? 0,
      diskPercent: (json['diskPercent'] as num?)?.toDouble() ?? 0,
      timestamp: (json['timestamp'] as num?)?.toDouble() ?? 0,
      hostname: json['hostname']?.toString(),
      macosVersion: json['macosVersion']?.toString(),
      uptimeSeconds: (json['uptimeSeconds'] as num?)?.toDouble(),
      agentCpuPercent: (json['agentCpuPercent'] as num?)?.toDouble(),
      agentMemoryMb: (json['agentMemoryMb'] as num?)?.toDouble(),
    );
  }
}

class MacNotificationItem {
  const MacNotificationItem({
    required this.id,
    required this.appName,
    required this.requestId,
    required this.summary,
    required this.timestamp,
    required this.dismissed,
  });

  final String id;
  final String appName;
  final String requestId;
  final String summary;
  final double timestamp;
  final bool dismissed;

  factory MacNotificationItem.fromJson(Map<String, dynamic> json) {
    return MacNotificationItem(
      id: json['id']?.toString() ?? '',
      appName: json['appName']?.toString() ?? 'Unknown',
      requestId: json['requestId']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      timestamp: (json['timestamp'] as num?)?.toDouble() ?? 0,
      dismissed: json['dismissed'] == true,
    );
  }
}

class MacAudioDevice {
  const MacAudioDevice({required this.id, required this.name});

  final String id;
  final String name;

  factory MacAudioDevice.fromJson(Map<String, dynamic> json) {
    return MacAudioDevice(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

class MacCaptureResult {
  const MacCaptureResult({
    required this.success,
    required this.kind,
    required this.filename,
    this.previewBase64,
    this.savedTo,
    this.reason,
  });

  final bool success;
  final String kind;
  final String filename;
  final String? previewBase64;
  final String? savedTo;
  final String? reason;

  factory MacCaptureResult.fromJson(Map<String, dynamic> json) {
    return MacCaptureResult(
      success: json['success'] == true,
      kind: json['kind']?.toString() ?? '',
      filename: json['filename']?.toString() ?? '',
      previewBase64: json['previewBase64']?.toString(),
      savedTo: json['savedTo']?.toString(),
      reason: json['reason']?.toString(),
    );
  }
}
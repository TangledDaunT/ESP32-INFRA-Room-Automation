import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/mac_agent_models.dart';

class MacCommandResult {
  const MacCommandResult({
    required this.success,
    required this.target,
    this.action,
    this.reason,
  });

  final bool success;
  final String target;
  final String? action;
  final String? reason;

  factory MacCommandResult.fromJson(Map<String, dynamic> json) {
    return MacCommandResult(
      success: json['success'] == true,
      target: json['target']?.toString() ?? '',
      action: json['action']?.toString(),
      reason: (json['reason'] ?? json['detail'])?.toString(),
    );
  }

  factory MacCommandResult.failure(String target, String reason) {
    return MacCommandResult(
      success: false,
      target: target,
      reason: reason,
    );
  }
}

class MacService {
  const MacService(this.baseUrl);

  final String baseUrl;

  String get _normalizedBase => baseUrl.replaceAll(RegExp(r'/+$'), '');

  Iterable<String> get _candidateBases sync* {
    yield _normalizedBase;
    if (!_normalizedBase.contains('127.0.0.1')) yield 'http://127.0.0.1:8765';
    if (!_normalizedBase.contains('localhost')) yield 'http://localhost:8765';
  }

  Future<Map<String, dynamic>?> _getJson(String path) async {
    for (final base in _candidateBases) {
      try {
        final response = await http
            .get(Uri.parse('$base$path'))
            .timeout(const Duration(seconds: 4));
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _getJsonList(String path) async {
    for (final base in _candidateBases) {
      try {
        final response = await http
            .get(Uri.parse('$base$path'))
            .timeout(const Duration(seconds: 4));
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
            return decoded
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      } catch (_) {}
    }
    return const [];
  }

  Future<Map<String, dynamic>?> _postJson(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    for (final base in _candidateBases) {
      try {
        final response = await http
            .post(
              Uri.parse('$base$path'),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(body ?? const {}),
            )
            .timeout(const Duration(seconds: 15));
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return null;
  }

  Future<bool> _postOk(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    return (await _postJson(path, body)) != null;
  }

  Future<MacCommandResult> open(String target) async =>
      _send(target: target, action: 'open');

  Future<MacCommandResult> close(String target) async =>
      _send(target: target, action: 'close');

  Future<MacCommandResult> _send({
    required String target,
    required String action,
  }) async {
    MacCommandResult? lastFailure;
    for (final base in _candidateBases) {
      try {
        final response = await http
            .post(
              Uri.parse('$base/command'),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode({'target': target, 'action': action}),
            )
            .timeout(const Duration(seconds: 4));

        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final result = MacCommandResult.fromJson(decoded);
          if (response.statusCode >= 200 && response.statusCode < 300) {
            return result;
          }
          return MacCommandResult.failure(
            target,
            result.reason ?? 'Mac agent rejected the command',
          );
        }

        return MacCommandResult.failure(target, 'Unexpected Mac agent response');
      } on TimeoutException {
        lastFailure = MacCommandResult.failure(target, 'Mac agent timed out');
      } catch (error) {
        lastFailure = MacCommandResult.failure(target, error.toString());
      }
    }

    return lastFailure ?? MacCommandResult.failure(target, 'Mac agent unreachable');
  }

  Future<MacSystemStatus?> fetchStatus() async {
    final json = await _getJson('/status');
    if (json == null) return null;
    return MacSystemStatus.fromJson(json);
  }

  Future<List<MacNotificationItem>> fetchNotifications() async {
    final json = await _getJsonList('/notifications');
    return json.map(MacNotificationItem.fromJson).toList();
  }

  Future<MacCaptureResult?> takeScreenshot() async {
    final json = await _postJson('/screenshot');
    if (json == null) return null;
    return MacCaptureResult.fromJson(json);
  }

  Future<MacCaptureResult?> recordScreen({int durationSeconds = 10}) async {
    final json = await _postJson('/screen-record', {
      'durationSeconds': durationSeconds,
    });
    if (json == null) return null;
    return MacCaptureResult.fromJson(json);
  }

  Future<List<MacAudioDevice>> fetchOutputDevices() async {
    final json = await _getJsonList('/media/output-devices');
    return json.map(MacAudioDevice.fromJson).toList();
  }

  Future<bool> mediaPlayPause() async => _postOk('/media/play-pause');
  Future<bool> mediaNext() async => _postOk('/media/next');
  Future<bool> mediaPrevious() async => _postOk('/media/previous');

  Future<bool> setVolume(int level) async {
    return _postOk('/media/volume', {'level': level});
  }

  Future<bool> setOutputDevice(String deviceId) async {
    return _postOk('/media/output-device', {'deviceId': deviceId});
  }

  Future<bool> dismissNotification(String id) async {
    return _postOk('/notifications/$id/action', {'action': 'dismiss'});
  }

  Future<bool> openNotification(String id) async {
    return _postOk('/notifications/$id/action', {'action': 'open'});
  }
}

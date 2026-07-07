import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

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

  Future<MacCommandResult> open(String target) async {
    return _send(target: target, action: 'open');
  }

  Future<MacCommandResult> close(String target) async {
    return _send(target: target, action: 'close');
  }

  Future<MacCommandResult> _send({
    required String target,
    required String action,
  }) async {
    final normalizedBase = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final candidateBases = <String>{
      normalizedBase,
      if (!normalizedBase.contains('127.0.0.1')) 'http://127.0.0.1:8765',
      if (!normalizedBase.contains('localhost')) 'http://localhost:8765',
    };

    MacCommandResult? lastFailure;
    for (final base in candidateBases) {
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
}

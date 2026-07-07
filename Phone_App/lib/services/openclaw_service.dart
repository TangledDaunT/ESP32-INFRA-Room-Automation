// lib/services/openclaw_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/app_settings.dart';
import '../models/device_state.dart';

typedef StateCallback = void Function(Map<String, dynamic> state);

class OpenClawService {
  AppSettings _settings;
  StateCallback? onStateReceived;
  VoidCallback? onConnected;
  VoidCallback? onDisconnected;

  WebSocketChannel? _channel;
  StreamSubscription? _wsSubscription;
  Timer? _reconnectTimer;
  ConnectionStatus status = ConnectionStatus.disconnected;
  int _reconnectDelay = 2;

  OpenClawService(this._settings);

  void updateSettings(AppSettings settings) {
    _settings = settings;
  }

  String get _httpBase => _settings.openclawBaseUrl; // e.g. "http://192.168.1.30"
  
  String get _wsUrl {
    final uri = Uri.parse(_httpBase);
    return 'ws://${uri.host}:${uri.port}/ws';
  }

  /// Connect WebSocket
  void connect() {
    _reconnectTimer?.cancel();
    _connectWs();
  }

  void _connectWs() {
    if (status == ConnectionStatus.connected) return;
    
    status = ConnectionStatus.connecting;
    
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      
      _wsSubscription = _channel!.stream.listen(
        (message) {
          if (status != ConnectionStatus.connected) {
            status = ConnectionStatus.connected;
            _reconnectDelay = 2;
            onConnected?.call();
          }
          try {
            final data = jsonDecode(message) as Map<String, dynamic>;
            onStateReceived?.call(data);
          } catch (_) {}
        },
        onError: (error) {
          _handleDisconnect();
        },
        onDone: () {
          _handleDisconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    status = ConnectionStatus.disconnected;
    onDisconnected?.call();
    
    _wsSubscription?.cancel();
    _channel?.sink.close();
    
    // Auto-reconnect with exponential backoff
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelay), _connectWs);
    _reconnectDelay = (_reconnectDelay * 2).clamp(2, 30);
  }

  /// Send Command to API (HTTP POST) - Firmware accepts POST at /api/cmd
  Future<bool> _sendCommand(Map<String, dynamic> payload) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_httpBase/api/cmd'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      // Fallback: Try to send over WebSocket if HTTP fails
      if (status == ConnectionStatus.connected && _channel != null) {
        _channel!.sink.add(jsonEncode(payload));
        return true;
      }
      return false;
    }
  }

  /// Send Command exclusively over WebSocket (ideal for high-frequency updates)
  bool sendWsCommand(Map<String, dynamic> payload) {
    if (status == ConnectionStatus.connected && _channel != null) {
      _channel!.sink.add(jsonEncode(payload));
      return true;
    }
    return false;
  }

  // ── Specific Commands ──

  Future<bool> setRelay(int channel, bool state) async {
    return _sendCommand({
      'cmd': 'relay',
      'ch': channel,
      'val': state
    });
  }

  Future<bool> setStripBrightness(int brightness) async {
    return _sendCommand({
      'cmd': 'strip',
      'val': brightness
    });
  }

  Future<bool> setFlashBrightness(int brightness) async {
    return _sendCommand({
      'cmd': 'flash',
      'val': brightness
    });
  }

  Future<bool> setMode(String mode) async {
    return _sendCommand({
      'cmd': 'mode',
      'val': mode
    });
  }

  Future<bool> setAllOff() async {
    return _sendCommand({'cmd': 'all_off'});
  }

  Future<bool> setAllOn() async {
    return _sendCommand({'cmd': 'all_on'});
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _wsSubscription?.cancel();
    _channel?.sink.close();
    status = ConnectionStatus.disconnected;
  }

  void dispose() {
    disconnect();
  }
}

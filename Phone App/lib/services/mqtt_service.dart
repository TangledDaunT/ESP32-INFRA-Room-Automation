// lib/services/mqtt_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/app_settings.dart';
import '../models/device_state.dart';

typedef MqttMessageCallback = void Function(String topic, String payload);

class MqttService {
  MqttServerClient? _client;
  AppSettings _settings;
  MqttMessageCallback? onMessage;
  VoidCallback? onConnected;
  VoidCallback? onDisconnected;

  bool _intentionalDisconnect = false;
  Timer? _reconnectTimer;

  MqttService(this._settings);

  void updateSettings(AppSettings settings) {
    _settings = settings;
  }

  ConnectionStatus get status {
    if (_client == null) return ConnectionStatus.disconnected;
    switch (_client!.connectionStatus?.state) {
      case MqttConnectionState.connected:
        return ConnectionStatus.connected;
      case MqttConnectionState.connecting:
        return ConnectionStatus.connecting;
      default:
        return ConnectionStatus.disconnected;
    }
  }

  Future<bool> connect() async {
    _intentionalDisconnect = false;
    _reconnectTimer?.cancel();

    final clientId = 'openclaw_remote_${DateTime.now().millisecondsSinceEpoch}';

    _client = MqttServerClient(_settings.mqttBroker, clientId);
    _client!.port = _settings.mqttPort;
    _client!.keepAlivePeriod = 30;
    _client!.connectTimeoutPeriod = 5000;
    _client!.autoReconnect = false;
    _client!.logging(on: false);

    if (_settings.mqttUseTls) {
      _client!.secure = true;
    }

    _client!.onConnected = _onConnected;
    _client!.onDisconnected = _onDisconnected;
    _client!.onAutoReconnected = null;

    final connMsg = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .withWillTopic('openclaw/remote/status')
        .withWillMessage('{"status":"offline"}')
        .withWillRetain()
        .withWillQos(MqttQos.atLeastOnce)
        .startClean();

    if (_settings.mqttUsername.isNotEmpty) {
      connMsg.authenticateAs(_settings.mqttUsername, _settings.mqttPassword);
    }

    _client!.connectionMessage = connMsg;

    try {
      await _client!.connect();
      if (_client!.connectionStatus?.state == MqttConnectionState.connected) {
        _subscribeToAll();
        _publishOnline();
        _listenToMessages();
        return true;
      }
      return false;
    } catch (e) {
      _client?.disconnect();
      _scheduleReconnect();
      return false;
    }
  }

  void _onConnected() {
    onConnected?.call();
    _publishOnline();
  }

  void _onDisconnected() {
    onDisconnected?.call();
    if (!_intentionalDisconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_intentionalDisconnect) connect();
    });
  }

  void _publishOnline() {
    publish('openclaw/remote/status', '{"status":"online"}', retain: true);
  }

  void _subscribeToAll() {
    final topics = [
      _settings.topicFan,
      _settings.topicLight,
      _settings.topicSocket,
      _settings.topicRgb,
      _settings.topicRgbBrightness,
      _settings.topicBackupBrightness,
      _settings.topicSmoke,
      _settings.topicLux,
      _settings.topicPresence,
      _settings.topicSleepStatus,
      _settings.topicStateSync,
    ];

    for (final topic in topics) {
      _client!.subscribe(topic, MqttQos.atLeastOnce);
    }
  }

  void _listenToMessages() {
    _client!.updates?.listen((List<MqttReceivedMessage<MqttMessage>> events) {
      for (final event in events) {
        final msg = event.payload as MqttPublishMessage;
        final payload =
            MqttPublishPayload.bytesToStringAsString(msg.payload.message);
        onMessage?.call(event.topic, payload);
      }
    });
  }

  void publish(String topic, String payload, {bool retain = false}) {
    if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
      return;
    }
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    _client!.publishMessage(
      topic,
      MqttQos.atLeastOnce,
      builder.payload!,
      retain: retain,
    );
  }

  void publishDeviceCommand(String topic, bool state) {
    publish(topic, state ? 'ON' : 'OFF');
  }

  void publishBrightness(String topic, int brightness) {
    publish(topic, brightness.toString());
  }

  void publishJson(String topic, Map<String, dynamic> data) {
    publish(topic, jsonEncode(data));
  }

  void disconnect() {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _client?.disconnect();
  }

  void dispose() {
    disconnect();
  }
}

// Alias so we can use VoidCallback cleanly
// typedef VoidCallback = void Function();

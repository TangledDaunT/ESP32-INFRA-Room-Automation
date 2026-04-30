// lib/services/ble_service.dart
//
// ESP32 BLE FIRMWARE SETUP (add this to your ESP32 code):
// ─────────────────────────────────────────────────────────
// #include <BLEDevice.h>
// #include <BLEServer.h>
// #include <BLEUtils.h>
// #include <BLE2902.h>
//
// #define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
// #define CMD_CHAR_UUID       "beb5483e-36e1-4688-b7f5-ea07361b26a8"  // WRITE
// #define SENSOR_CHAR_UUID    "beb5483e-36e1-4688-b7f5-ea07361b26a9"  // NOTIFY
//
// BLEServer* pServer;
// BLECharacteristic* cmdChar;
// BLECharacteristic* sensorChar;
//
// void setup() {
//   BLEDevice::init("OpenClaw_ESP32");
//   pServer = BLEDevice::createServer();
//   BLEService* pService = pServer->createService(SERVICE_UUID);
//   cmdChar = pService->createCharacteristic(CMD_CHAR_UUID, BLECharacteristic::PROPERTY_WRITE);
//   sensorChar = pService->createCharacteristic(SENSOR_CHAR_UUID,
//       BLECharacteristic::PROPERTY_NOTIFY);
//   sensorChar->addDescriptor(new BLE2902());
//   pService->start();
//   BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
//   pAdvertising->addServiceUUID(SERVICE_UUID);
//   pAdvertising->start();
// }
//
// // In loop(), publish sensor JSON:
// // {"smoke":245,"lux":12.5,"presence":true}
// ─────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/device_state.dart';

typedef BleMessageCallback = void Function(Map<String, dynamic> data);
typedef BleStatusCallback = void Function(ConnectionStatus status);

class BleService {
  static const String _serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String _cmdCharUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  static const String _sensorCharUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a9';

  String deviceName;
  BleMessageCallback? onSensorData;
  BleStatusCallback? onStatusChanged;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _cmdChar;
  BluetoothCharacteristic? _sensorChar;
  StreamSubscription? _scanSub;
  StreamSubscription? _sensorSub;
  StreamSubscription? _connSub;

  ConnectionStatus _status = ConnectionStatus.disconnected;
  bool _connecting = false;
  bool _intentionalDisconnect = false;
  Timer? _reconnectTimer;

  BleService(this.deviceName);

  ConnectionStatus get status => _status;

  void _setStatus(ConnectionStatus s) {
    _status = s;
    onStatusChanged?.call(s);
  }

  Future<void> startScan() async {
    if (_connecting || _status == ConnectionStatus.connected) return;
    _connecting = true;
    _setStatus(ConnectionStatus.connecting);

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 15),
      withNames: [deviceName],
    );

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        if (result.device.platformName == deviceName) {
          FlutterBluePlus.stopScan();
          _connect(result.device);
          break;
        }
      }
    });

    FlutterBluePlus.isScanning.listen((scanning) {
      if (!scanning && _status == ConnectionStatus.connecting) {
        // Scan ended without finding device
        _connecting = false;
        _setStatus(ConnectionStatus.disconnected);
        _scheduleReconnect();
      }
    });
  }

  Future<void> _connect(BluetoothDevice device) async {
    _device = device;

    _connSub = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _cleanup();
        if (!_intentionalDisconnect) {
          _scheduleReconnect();
        }
      }
    });

    try {
      await device.connect(timeout: const Duration(seconds: 10));
      final services = await device.discoverServices();

      for (final service in services) {
        if (service.uuid.toString().toLowerCase() == _serviceUuid) {
          for (final char in service.characteristics) {
            final uuid = char.uuid.toString().toLowerCase();
            if (uuid == _cmdCharUuid) _cmdChar = char;
            if (uuid == _sensorCharUuid) {
              _sensorChar = char;
              await char.setNotifyValue(true);
              _sensorSub = char.onValueReceived.listen(_onSensorData);
            }
          }
        }
      }

      _connecting = false;
      _setStatus(ConnectionStatus.connected);
    } catch (e) {
      _cleanup();
      _scheduleReconnect();
    }
  }

  void _onSensorData(List<int> data) {
    try {
      final json = jsonDecode(String.fromCharCodes(data)) as Map<String, dynamic>;
      onSensorData?.call(json);
    } catch (_) {}
  }

  Future<void> sendCommand(Map<String, dynamic> cmd) async {
    if (_cmdChar == null || _status != ConnectionStatus.connected) return;
    try {
      final bytes = utf8.encode(jsonEncode(cmd));
      await _cmdChar!.write(bytes, withoutResponse: false);
    } catch (_) {}
  }

  void _scheduleReconnect() {
    if (_intentionalDisconnect) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 8), startScan);
  }

  void _cleanup() {
    _sensorSub?.cancel();
    _connSub?.cancel();
    _cmdChar = null;
    _sensorChar = null;
    _connecting = false;
    _setStatus(ConnectionStatus.disconnected);
  }

  void disconnect() {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _scanSub?.cancel();
    FlutterBluePlus.stopScan();
    _device?.disconnect();
    _cleanup();
  }

  void dispose() {
    disconnect();
  }
}

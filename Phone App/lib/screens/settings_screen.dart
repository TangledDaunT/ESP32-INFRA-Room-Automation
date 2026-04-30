// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../providers/settings_provider.dart';
import '../providers/device_provider.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings _draft;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final sp = context.read<SettingsProvider>();
    _draft = AppSettings.fromJson(sp.settings.toJson());
  }

  void _save() async {
    final sp = context.read<SettingsProvider>();
    final dp = context.read<DeviceProvider>();
    await sp.save(_draft);
    await dp.updateSettings(_draft);
    setState(() => _dirty = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Settings saved'),
        backgroundColor: AppTheme.accentDim,
        duration: Duration(seconds: 2),
      ));
    }
  }

  void _change(VoidCallback fn) {
    setState(() { fn(); _dirty = true; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('SETTINGS'),
        actions: [
          if (_dirty)
            TextButton(
              onPressed: _save,
              child: const Text('SAVE',
                  style: TextStyle(color: AppTheme.accent, letterSpacing: 1)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // ── MQTT ──────────────────────────────────────
          _section('MQTT BROKER'),
          _textField('Broker IP / Hostname', _draft.mqttBroker,
              (v) => _change(() => _draft.mqttBroker = v)),
          _numberField('Port', _draft.mqttPort,
              (v) => _change(() => _draft.mqttPort = v)),
          _textField('Username (optional)', _draft.mqttUsername,
              (v) => _change(() => _draft.mqttUsername = v)),
          _textField('Password (optional)', _draft.mqttPassword,
              (v) => _change(() => _draft.mqttPassword = v),
              obscure: true),
          _toggle('Use TLS', _draft.mqttUseTls,
              (v) => _change(() => _draft.mqttUseTls = v)),

          // ── OpenClaw ──────────────────────────────────
          _section('OPENCLAW HTTP'),
          _textField('Base URL (e.g. http://192.168.1.5:8000)',
              _draft.openclawBaseUrl,
              (v) => _change(() => _draft.openclawBaseUrl = v)),

          // ── BLE ───────────────────────────────────────
          _section('BLUETOOTH (BLE)'),
          _textField('ESP32 Device Name', _draft.bleDeviceName,
              (v) => _change(() => _draft.bleDeviceName = v)),

          // ── MQTT Topics ───────────────────────────────
          _section('MQTT TOPICS'),
          _textField('Fan', _draft.topicFan,
              (v) => _change(() => _draft.topicFan = v)),
          _textField('Main Light', _draft.topicLight,
              (v) => _change(() => _draft.topicLight = v)),
          _textField('Socket', _draft.topicSocket,
              (v) => _change(() => _draft.topicSocket = v)),
          _textField('RGB Toggle', _draft.topicRgb,
              (v) => _change(() => _draft.topicRgb = v)),
          _textField('RGB Brightness', _draft.topicRgbBrightness,
              (v) => _change(() => _draft.topicRgbBrightness = v)),
          _textField('Backup Brightness', _draft.topicBackupBrightness,
              (v) => _change(() => _draft.topicBackupBrightness = v)),
          _textField('Smoke Sensor', _draft.topicSmoke,
              (v) => _change(() => _draft.topicSmoke = v)),
          _textField('Lux Sensor', _draft.topicLux,
              (v) => _change(() => _draft.topicLux = v)),
          _textField('Presence Sensor', _draft.topicPresence,
              (v) => _change(() => _draft.topicPresence = v)),
          _textField('State Sync (from OpenClaw)', _draft.topicStateSync,
              (v) => _change(() => _draft.topicStateSync = v)),

          // ── Night Mode ────────────────────────────────
          _section('NIGHT MODE'),
          _timeField('Night Starts', _draft.nightStartHour, _draft.nightStartMinute,
              (h, m) => _change(() { _draft.nightStartHour = h; _draft.nightStartMinute = m; })),
          _timeField('Night Ends', _draft.nightEndHour, _draft.nightEndMinute,
              (h, m) => _change(() { _draft.nightEndHour = h; _draft.nightEndMinute = m; })),
          _doubleField('Lux Night Threshold', _draft.luxNightThreshold,
              (v) => _change(() => _draft.luxNightThreshold = v),
              hint: 'Below this lux = night'),

          // ── Sleep Detection ───────────────────────────
          _section('SLEEP DETECTION'),
          _numberField('Lights Off For (mins) = Sleeping',
              _draft.sleepDetectionMinutes,
              (v) => _change(() => _draft.sleepDetectionMinutes = v)),
          _doubleField('MQ-2 Sleep Threshold', _draft.mq2SleepThreshold,
              (v) => _change(() => _draft.mq2SleepThreshold = v),
              hint: 'Elevated CO2 = person breathing in room'),
          _numberField('No Presence For (mins) = Away',
              _draft.presenceAbsenceMinutes,
              (v) => _change(() => _draft.presenceAbsenceMinutes = v)),

          // ── Wake-up ───────────────────────────────────
          _section('WAKE-UP ROUTINE'),
          _timeField('Wake-up Time', _draft.wakeUpHour, _draft.wakeUpMinute,
              (h, m) => _change(() { _draft.wakeUpHour = h; _draft.wakeUpMinute = m; })),
          _numberField('PWM Ramp Start (mins before wake)',
              _draft.wakeUpRampMinutes,
              (v) => _change(() => _draft.wakeUpRampMinutes = v)),

          // ── Smoke Alarm ───────────────────────────────
          _section('SMOKE ALARM'),
          _doubleField('Smoke Alarm Threshold (ppm)', _draft.smokeAlarmThreshold,
              (v) => _change(() => _draft.smokeAlarmThreshold = v)),

          // ── UI ────────────────────────────────────────
          _section('INTERFACE'),
          _numberField('Idle Timeout (seconds)', _draft.idleTimeoutSeconds,
              (v) => _change(() => _draft.idleTimeoutSeconds = v)),

          // ── Clap ──────────────────────────────────────
          _section('CLAP DETECTION'),
          _doubleField('Clap dB Threshold (above avg)', _draft.clapDbThreshold,
              (v) => _change(() => _draft.clapDbThreshold = v),
              hint: 'Spike above rolling average to count as clap'),
          _numberField('Double-clap Window (ms)', _draft.clapWindowMs,
              (v) => _change(() => _draft.clapWindowMs = v)),

          const SizedBox(height: 40),

          // ── Save Button ───────────────────────────────
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: AppTheme.bg,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('SAVE SETTINGS',
                style: TextStyle(
                    fontWeight: FontWeight.w800, letterSpacing: 2)),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Text(
          label,
          style: const TextStyle(
            color: AppTheme.accent,
            fontSize: 10,
            letterSpacing: 2.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _textField(String label, String value, ValueChanged<String> onChanged,
      {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        initialValue: value,
        obscureText: obscure,
        onChanged: onChanged,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppTheme.textSecond, fontSize: 12),
          filled: true,
          fillColor: AppTheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.accent),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _numberField(
      String label, int value, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        initialValue: value.toString(),
        keyboardType: TextInputType.number,
        onChanged: (v) {
          final parsed = int.tryParse(v);
          if (parsed != null) onChanged(parsed);
        },
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppTheme.textSecond, fontSize: 12),
          filled: true,
          fillColor: AppTheme.surface,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.accent)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _doubleField(
      String label, double value, ValueChanged<double> onChanged,
      {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        initialValue: value.toString(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (v) {
          final parsed = double.tryParse(v);
          if (parsed != null) onChanged(parsed);
        },
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: const TextStyle(color: AppTheme.textDim, fontSize: 11),
          labelStyle: const TextStyle(color: AppTheme.textSecond, fontSize: 12),
          filled: true,
          fillColor: AppTheme.surface,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.accent)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecond, fontSize: 13)),
          const Spacer(),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _timeField(String label, int hour, int minute,
      void Function(int h, int m) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecond, fontSize: 13)),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: hour, minute: minute),
                builder: (ctx, child) => Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: const ColorScheme.dark(primary: AppTheme.accent),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                onChanged(picked.hour, picked.minute);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Text(
                '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

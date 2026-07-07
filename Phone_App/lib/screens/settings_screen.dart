import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../models/app_settings.dart';
import '../providers/device_provider.dart';
import '../providers/settings_provider.dart';
import '../theme.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/settings_row.dart';
import '../widgets/time_picker_sheet.dart';
import '../widgets/toggle_switch.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings _draft;
  late TextEditingController _brokerController;
  late TextEditingController _portController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _openclawController;
  late TextEditingController _macAgentController;
  late TextEditingController _bleController;
  late TextEditingController _historyController;

  bool _showPassword = false;
  bool _advancedExpanded = false;
  bool _topicsExpanded = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    _draft = AppSettings.fromJson(settings.toJson());
    _brokerController = TextEditingController(text: _draft.mqttBroker);
    _portController = TextEditingController(text: _draft.mqttPort.toString());
    _usernameController = TextEditingController(text: _draft.mqttUsername);
    _passwordController = TextEditingController(text: _draft.mqttPassword);
    _openclawController = TextEditingController(text: _draft.openclawBaseUrl);
    _macAgentController = TextEditingController(text: _draft.macAgentBaseUrl);
    _bleController = TextEditingController(text: _draft.bleDeviceName);
    _historyController = TextEditingController(text: _draft.historySyncUrl);
  }

  @override
  void dispose() {
    _brokerController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _openclawController.dispose();
    _macAgentController.dispose();
    _bleController.dispose();
    _historyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final settingsProvider = context.read<SettingsProvider>();
    final deviceProvider = context.read<DeviceProvider>();
    await settingsProvider.save(_draft);
    await deviceProvider.updateSettings(_draft);
    if (!mounted) {
      return;
    }
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SETTINGS SAVED'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _markDirty() {
    if (!_dirty) {
      setState(() => _dirty = true);
    }
  }

  Future<void> _pickTime(
    String title,
    int hour,
    int minute,
    void Function(int hour, int minute) onSelected,
  ) async {
    final result = await showTimePickerSheet(
      context,
      title: title,
      initialTime: TimeOfDay(hour: hour, minute: minute),
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      onSelected(result.hour, result.minute);
      _dirty = true;
    });
  }

  Future<void> _pickNumber({
    required String title,
    required int initial,
    required int min,
    required int max,
    required ValueChanged<int> onSelected,
    String? suffix,
  }) async {
    final result = await showNumericPickerSheet(
      context,
      title: title,
      initialValue: initial,
      min: min,
      max: max,
      suffix: suffix,
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      onSelected(result);
      _dirty = true;
    });
  }

  String _formatTime(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  double get _clapSensitivityPercent =>
      ((_draft.clapDbThreshold / 30).clamp(0, 1) * 100).toDouble();

  set _clapSensitivityPercent(double value) {
    _draft.clapDbThreshold = ((value / 100) * 30).clamp(0, 30);
  }

  Future<void> _confirmDiscardAndPop() async {
    final discard = await showConfirmDialog(
      context,
      title: 'DISCARD CHANGES?',
      message: 'You have unsaved settings changes. Discard them?',
      confirmLabel: 'DISCARD',
    );
    if (discard && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmDiscardAndPop();
      },
      child: Scaffold(
        backgroundColor: AppColors.black,
        body: SafeArea(
          child: CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: AppSpace.pagePadding,
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            behavior: HitTestBehavior.opaque,
                            child: Text(
                              '← SETTINGS',
                              style: AppTextStyles.labelLG(
                                color: AppColors.white90,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            kUiVersion,
                            style: AppTextStyles.labelSM(),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.lg),
                      const Divider(
                          color: AppColors.white20, thickness: 1, height: 1),
                      const SizedBox(height: AppSpace.xl),
                      const _SectionHeader(title: 'MQTT.CONFIG'),
                      SettingsRow(
                        label: 'BROKER',
                        trailing: _buildTextField(
                          controller: _brokerController,
                          onChanged: (value) {
                            _draft.mqttBroker = value;
                            _markDirty();
                          },
                        ),
                      ),
                      SettingsRow(
                        label: 'PORT',
                        trailing: _buildTextField(
                          controller: _portController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          onChanged: (value) {
                            final parsed = int.tryParse(value);
                            if (parsed != null) {
                              _draft.mqttPort = parsed;
                              _markDirty();
                            }
                          },
                        ),
                      ),
                      SettingsRow(
                        label: 'USERNAME',
                        trailing: _buildTextField(
                          controller: _usernameController,
                          onChanged: (value) {
                            _draft.mqttUsername = value;
                            _markDirty();
                          },
                        ),
                      ),
                      SettingsRow(
                        label: 'PASSWORD',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 160,
                              child: _buildTextField(
                                controller: _passwordController,
                                obscureText: !_showPassword,
                                onChanged: (value) {
                                  _draft.mqttPassword = value;
                                  _markDirty();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                setState(() => _showPassword = !_showPassword);
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Icon(
                                _showPassword
                                    ? Symbols.visibility_off
                                    : Symbols.visibility,
                                size: 18,
                                color: AppColors.white40,
                                fill: 0,
                                weight: 300,
                                opticalSize: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpace.xl),
                      const _SectionHeader(title: 'NETWORK.CONFIG'),
                      SettingsRow(
                        label: 'OPENCLAW URL',
                        trailing: _buildTextField(
                          controller: _openclawController,
                          onChanged: (value) {
                            _draft.openclawBaseUrl = value;
                            _markDirty();
                          },
                        ),
                      ),
                      SettingsRow(
                        label: 'MAC AGENT URL',
                        trailing: _buildTextField(
                          controller: _macAgentController,
                          onChanged: (value) {
                            _draft.macAgentBaseUrl = value;
                            _markDirty();
                          },
                        ),
                      ),
                      SettingsRow(
                        label: 'ESP32 BLE NAME',
                        trailing: _buildTextField(
                          controller: _bleController,
                          onChanged: (value) {
                            _draft.bleDeviceName = value;
                            _markDirty();
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpace.xl),
                      const _SectionHeader(title: 'AUTOMATION'),
                      SettingsRow(
                        label: 'WAKE-UP TIME',
                        onTap: () => _pickTime(
                          'WAKE-UP TIME',
                          _draft.wakeUpHour,
                          _draft.wakeUpMinute,
                          (hour, minute) {
                            _draft.wakeUpHour = hour;
                            _draft.wakeUpMinute = minute;
                          },
                        ),
                        trailing: _buildTapValue(_formatTime(
                          _draft.wakeUpHour,
                          _draft.wakeUpMinute,
                        )),
                      ),
                      SettingsRow(
                        label: 'NIGHT MODE START',
                        onTap: () => _pickTime(
                          'NIGHT MODE START',
                          _draft.nightStartHour,
                          _draft.nightStartMinute,
                          (hour, minute) {
                            _draft.nightStartHour = hour;
                            _draft.nightStartMinute = minute;
                          },
                        ),
                        trailing: _buildTapValue(_formatTime(
                          _draft.nightStartHour,
                          _draft.nightStartMinute,
                        )),
                      ),
                      SettingsRow(
                        label: 'NIGHT MODE END',
                        onTap: () => _pickTime(
                          'NIGHT MODE END',
                          _draft.nightEndHour,
                          _draft.nightEndMinute,
                          (hour, minute) {
                            _draft.nightEndHour = hour;
                            _draft.nightEndMinute = minute;
                          },
                        ),
                        trailing: _buildTapValue(_formatTime(
                          _draft.nightEndHour,
                          _draft.nightEndMinute,
                        )),
                      ),
                      SettingsRow(
                        label: 'LUX THRESHOLD',
                        onTap: () => _pickNumber(
                          title: 'LUX THRESHOLD',
                          initial: _draft.luxNightThreshold.round(),
                          min: 0,
                          max: 2000,
                          onSelected: (value) =>
                              _draft.luxNightThreshold = value.toDouble(),
                        ),
                        trailing: _buildTapValue(
                          _draft.luxNightThreshold.round().toString(),
                        ),
                      ),
                      SettingsRow(
                        label: 'PRESENCE TIMEOUT',
                        onTap: () => _pickNumber(
                          title: 'PRESENCE TIMEOUT',
                          initial: _draft.presenceAbsenceMinutes,
                          min: 1,
                          max: 60,
                          onSelected: (value) =>
                              _draft.presenceAbsenceMinutes = value,
                          suffix: ' MIN',
                        ),
                        trailing: _buildTapValue(
                          '${_draft.presenceAbsenceMinutes} MIN',
                        ),
                      ),
                      const SizedBox(height: AppSpace.xl),
                      const _SectionHeader(title: 'SLEEP.DETECTION'),
                      SettingsRow(
                        label: 'LIGHTS-OFF TIMER',
                        onTap: () => _pickNumber(
                          title: 'LIGHTS-OFF TIMER',
                          initial: _draft.sleepDetectionMinutes,
                          min: 1,
                          max: 60,
                          onSelected: (value) =>
                              _draft.sleepDetectionMinutes = value,
                          suffix: ' MIN',
                        ),
                        trailing: _buildTapValue(
                          '${_draft.sleepDetectionMinutes} MIN',
                        ),
                      ),
                      SettingsRow(
                        label: 'SMOKE THRESHOLD',
                        onTap: () => _pickNumber(
                          title: 'SMOKE THRESHOLD',
                          initial: _draft.smokeAlarmThreshold.round(),
                          min: 0,
                          max: 4095,
                          onSelected: (value) =>
                              _draft.smokeAlarmThreshold = value.toDouble(),
                        ),
                        trailing: _buildTapValue(
                          _draft.smokeAlarmThreshold.round().toString(),
                        ),
                      ),
                      const SizedBox(height: AppSpace.xl),
                      const _SectionHeader(title: 'ADVANCED'),
                      GestureDetector(
                        onTap: () {
                          setState(
                              () => _advancedExpanded = !_advancedExpanded);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Text(
                                _advancedExpanded ? 'COLLAPSE' : 'EXPAND',
                                style: AppTextStyles.labelSM(
                                  color: AppColors.white60,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                _advancedExpanded
                                    ? Symbols.expand_less
                                    : Symbols.expand_more,
                                size: 18,
                                color: AppColors.white40,
                                fill: 0,
                                weight: 300,
                                opticalSize: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 200),
                        crossFadeState: _advancedExpanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: const SizedBox.shrink(),
                        secondChild: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 16, top: 20, bottom: 6),
                              child: Text(
                                'CLAP DETECTION',
                                style: AppTextStyles.labelSM().copyWith(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  letterSpacing: 2.0,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            SettingsRow(
                              label: 'CLAP SENSITIVITY',
                              trailing: SizedBox(
                                width: 180,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Slider(
                                      value: _clapSensitivityPercent,
                                      min: 0,
                                      max: 100,
                                      onChanged: (value) {
                                        setState(() {
                                          _clapSensitivityPercent = value;
                                          _dirty = true;
                                        });
                                      },
                                    ),
                                    Text(
                                      '${_clapSensitivityPercent.round()}%',
                                      style: AppTextStyles.bodyLG(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 16, top: 20, bottom: 6),
                              child: Text(
                                'SLEEP THRESHOLDS',
                                style: AppTextStyles.labelSM().copyWith(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  letterSpacing: 2.0,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            SettingsRow(
                              label: 'IDLE TIMEOUT',
                              onTap: () => _pickNumber(
                                title: 'IDLE TIMEOUT',
                                initial: _draft.idleTimeoutSeconds,
                                min: 10,
                                max: 300,
                                onSelected: (value) =>
                                    _draft.idleTimeoutSeconds = value,
                                suffix: ' SEC',
                              ),
                              trailing: _buildTapValue(
                                '${_draft.idleTimeoutSeconds} SEC',
                              ),
                            ),
                            SettingsRow(
                              label: 'WAKE-UP RAMP',
                              onTap: () => _pickNumber(
                                title: 'WAKE-UP RAMP',
                                initial: _draft.wakeUpRampMinutes,
                                min: 1,
                                max: 120,
                                onSelected: (value) =>
                                    _draft.wakeUpRampMinutes = value,
                                suffix: ' MIN',
                              ),
                              trailing: _buildTapValue(
                                '${_draft.wakeUpRampMinutes} MIN',
                              ),
                            ),
                            SettingsRow(
                              label: 'MQ2 THRESHOLD',
                              onTap: () => _pickNumber(
                                title: 'MQ2 THRESHOLD',
                                initial: _draft.mq2SleepThreshold.round(),
                                min: 0,
                                max: 2000,
                                onSelected: (value) =>
                                    _draft.mq2SleepThreshold = value.toDouble(),
                              ),
                              trailing: _buildTapValue(
                                _draft.mq2SleepThreshold.round().toString(),
                              ),
                            ),
                            SettingsRow(
                              label: 'MQTT TLS',
                              onTap: () {
                                setState(() {
                                  _draft.mqttUseTls = !_draft.mqttUseTls;
                                  _dirty = true;
                                });
                              },
                              // Row itself is already the full tap target
                              // (see onTap above) — the switch is a visual
                              // indicator only, so it doesn't fire its own
                              // nested tap handler on top of the row's.
                              trailing: ToggleSwitch(value: _draft.mqttUseTls),
                            ),
                            SettingsRow(
                              label: 'CLAP WINDOW',
                              onTap: () => _pickNumber(
                                title: 'CLAP WINDOW',
                                initial: _draft.clapWindowMs,
                                min: 300,
                                max: 3000,
                                onSelected: (value) =>
                                    _draft.clapWindowMs = value,
                                suffix: ' MS',
                              ),
                              trailing:
                                  _buildTapValue('${_draft.clapWindowMs} MS'),
                            ),
                            SettingsRow(
                              label: 'PRESENCE AUTO LIGHT',
                              onTap: () {
                                setState(() {
                                  _draft.presenceAutoRestoreLight =
                                      !_draft.presenceAutoRestoreLight;
                                  _dirty = true;
                                });
                              },
                              trailing: ToggleSwitch(
                                value: _draft.presenceAutoRestoreLight,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 16, top: 20, bottom: 6),
                              child: Text(
                                'HISTORY SYNC',
                                style: AppTextStyles.labelSM().copyWith(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  letterSpacing: 2.0,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            SettingsRow(
                              label: 'HISTORY SYNC',
                              onTap: () {
                                setState(() {
                                  _draft.historySyncEnabled =
                                      !_draft.historySyncEnabled;
                                  _dirty = true;
                                });
                              },
                              trailing: ToggleSwitch(
                                  value: _draft.historySyncEnabled),
                            ),
                            SettingsRow(
                              label: 'LAPTOP LOG URL',
                              trailing: _buildTextField(
                                controller: _historyController,
                                onChanged: (value) {
                                  _draft.historySyncUrl = value;
                                  _markDirty();
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 16, top: 20, bottom: 6),
                              child: Text(
                                'SPOTIFY',
                                style: AppTextStyles.labelSM().copyWith(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  letterSpacing: 2.0,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            SettingsRow(
                              label: 'NOW PLAYING',
                              onTap: () {
                                setState(() {
                                  _draft.spotifyEnabled =
                                      !_draft.spotifyEnabled;
                                  _dirty = true;
                                });
                              },
                              trailing:
                                  ToggleSwitch(value: _draft.spotifyEnabled),
                            ),
                            SettingsRow(
                              label: 'POLLING URL',
                              trailing: Text(
                                '${_draft.fridayBaseUrl}/api/spotify',
                                style: AppTextStyles.labelSM().copyWith(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            SettingsRow(
                              label: 'HIGH-PASS FILTER',
                              onTap: () {
                                setState(() {
                                  _draft.clapHighPassEnabled =
                                      !_draft.clapHighPassEnabled;
                                  _dirty = true;
                                });
                              },
                              trailing: ToggleSwitch(
                                  value: _draft.clapHighPassEnabled),
                            ),
                            SettingsRow(
                              label: 'CLAP FREQ MIN',
                              onTap: () => _pickNumber(
                                title: 'CLAP FREQ MIN (Hz)',
                                initial: (_draft.clapMinFreqKhz * 1000).round(),
                                min: 1000,
                                max: 8000,
                                onSelected: (value) =>
                                    _draft.clapMinFreqKhz = value / 1000.0,
                                suffix: ' Hz',
                              ),
                              trailing: _buildTapValue(
                                  '${(_draft.clapMinFreqKhz * 1000).round()} Hz'),
                            ),
                            SettingsRow(
                              label: 'CLAP FREQ MAX',
                              onTap: () => _pickNumber(
                                title: 'CLAP FREQ MAX (Hz)',
                                initial: (_draft.clapMaxFreqKhz * 1000).round(),
                                min: 2000,
                                max: 16000,
                                onSelected: (value) =>
                                    _draft.clapMaxFreqKhz = value / 1000.0,
                                suffix: ' Hz',
                              ),
                              trailing: _buildTapValue(
                                  '${(_draft.clapMaxFreqKhz * 1000).round()} Hz'),
                            ),
                            SettingsRow(
                              label: 'MIN ATTACK (ms)',
                              onTap: () => _pickNumber(
                                title: 'MIN ATTACK (ms)',
                                initial: _draft.clapMinAttackMs,
                                min: 1,
                                max: 50,
                                onSelected: (value) =>
                                    _draft.clapMinAttackMs = value,
                                suffix: ' ms',
                              ),
                              trailing: _buildTapValue(
                                  '${_draft.clapMinAttackMs} MS'),
                            ),
                            SettingsRow(
                              label: 'MAX DURATION (ms)',
                              onTap: () => _pickNumber(
                                title: 'MAX DURATION (ms)',
                                initial: _draft.clapMaxDurationMs,
                                // DSP frame resolution is ~64ms (1024 samples
                                // @ 16kHz) — values below that can never match.
                                min: 64,
                                max: 500,
                                onSelected: (value) =>
                                    _draft.clapMaxDurationMs = value,
                                suffix: ' ms',
                              ),
                              trailing: _buildTapValue(
                                  '${_draft.clapMaxDurationMs} MS'),
                            ),
                            SettingsRow(
                              label: 'ENERGY RATIO',
                              onTap: () => _pickNumber(
                                title: 'ENERGY RATIO',
                                initial: _draft.clapEnergyRatio.round(),
                                min: 1,
                                max: 10,
                                onSelected: (value) =>
                                    _draft.clapEnergyRatio = value.toDouble(),
                              ),
                              trailing:
                                  _buildTapValue('${_draft.clapEnergyRatio}x'),
                            ),
                            SettingsRow(
                              label: 'CLAP COOLDOWN',
                              onTap: () => _pickNumber(
                                title: 'CLAP COOLDOWN (ms)',
                                initial: _draft.clapCooldownMs,
                                min: 200,
                                max: 5000,
                                onSelected: (value) =>
                                    _draft.clapCooldownMs = value,
                                suffix: ' ms',
                              ),
                              trailing:
                                  _buildTapValue('${_draft.clapCooldownMs} MS'),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(
                                    () => _topicsExpanded = !_topicsExpanded);
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                child: Row(
                                  children: [
                                    Text(
                                      'MQTT.TOPICS',
                                      style: AppTextStyles.labelLG(),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      _topicsExpanded
                                          ? Symbols.expand_less
                                          : Symbols.expand_more,
                                      size: 18,
                                      color: AppColors.white40,
                                      fill: 0,
                                      weight: 300,
                                      opticalSize: 24,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            AnimatedCrossFade(
                              duration: const Duration(milliseconds: 200),
                              crossFadeState: _topicsExpanded
                                  ? CrossFadeState.showSecond
                                  : CrossFadeState.showFirst,
                              firstChild: const SizedBox.shrink(),
                              secondChild: Column(
                                children: [
                                  _TopicValue(
                                      label: 'FAN', value: _draft.topicFan),
                                  _TopicValue(
                                      label: 'LIGHT', value: _draft.topicLight),
                                  _TopicValue(
                                      label: 'SOCKET',
                                      value: _draft.topicSocket),
                                  _TopicValue(
                                      label: 'RGB', value: _draft.topicRgb),
                                  _TopicValue(
                                    label: 'RGB BRIGHTNESS',
                                    value: _draft.topicRgbBrightness,
                                  ),
                                  _TopicValue(
                                    label: 'BACKUP BRIGHTNESS',
                                    value: _draft.topicBackupBrightness,
                                  ),
                                  _TopicValue(
                                      label: 'SMOKE', value: _draft.topicSmoke),
                                  _TopicValue(
                                      label: 'LUX', value: _draft.topicLux),
                                  _TopicValue(
                                    label: 'PRESENCE',
                                    value: _draft.topicPresence,
                                  ),
                                  _TopicValue(
                                    label: 'STATE SYNC',
                                    value: _draft.topicStateSync,
                                  ),
                                  _TopicValue(
                                    label: 'WAKEUP DONE',
                                    value: _draft.topicWakeupDone,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpace.xxl),
                      GestureDetector(
                        onTap: _dirty ? _save : null,
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: double.infinity,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _dirty
                                ? AppColors.white.withValues(alpha: 0.08)
                                : null,
                            border: Border.all(
                              color: _dirty
                                  ? AppColors.white90
                                  : AppColors.white20,
                              width: 1,
                            ),
                            boxShadow: _dirty ? GlassDecoration.glow() : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _dirty ? 'SAVE SETTINGS' : 'NO CHANGES',
                            style: AppTextStyles.labelLG(
                              color: _dirty
                                  ? AppColors.white90
                                  : AppColors.white40,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpace.xl),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return SizedBox(
      width: 180,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: AppTextStyles.bodyLG(),
        textAlign: TextAlign.right,
        cursorColor: AppColors.white90,
        cursorWidth: 1,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: obscureText ? '••••••' : '—',
          hintStyle: AppTextStyles.bodyLG(color: AppColors.white20),
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildTapValue(String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppTextStyles.bodyLG(),
        ),
        const SizedBox(width: 8),
        const Icon(
          Symbols.chevron_right,
          size: 16,
          color: AppColors.white40,
          fill: 0,
          weight: 300,
          opticalSize: 24,
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title.toUpperCase(), style: AppTextStyles.labelLG()),
        const SizedBox(width: 12),
        const Expanded(
          child: SizedBox(
            height: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(color: AppColors.white20),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopicValue extends StatelessWidget {
  const _TopicValue({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SettingsRow(
      label: label,
      trailing: SizedBox(
        width: 180,
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: AppTextStyles.bodyLG(color: AppColors.white60),
        ),
      ),
    );
  }
}

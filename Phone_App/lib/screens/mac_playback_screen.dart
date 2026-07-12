import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../models/mac_agent_models.dart';
import '../providers/settings_provider.dart';
import '../services/mac_service.dart';
import '../services/page_activity_controller.dart';
import '../theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/staggered_reveal.dart';

class MacPlaybackScreen extends StatefulWidget {
  const MacPlaybackScreen({super.key});

  @override
  State<MacPlaybackScreen> createState() => _MacPlaybackScreenState();
}

class _MacPlaybackScreenState extends State<MacPlaybackScreen> {
  static const _volumeDebounce = Duration(milliseconds: 220);

  PageActivityController? _activity;
  Timer? _volumeTimer;
  bool _loading = true;
  bool _busy = false;
  bool _volumeSending = false;
  double _volume = 50;
  String? _selectedDeviceId;
  String? _message;
  List<MacAudioDevice> _devices = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final activity = context.read<PageActivityController>();
    if (!identical(_activity, activity)) {
      _activity?.removeListener(_handleVisibilityChange);
      _activity = activity;
      _activity!.addListener(_handleVisibilityChange);
      _handleVisibilityChange();
    }
  }

  @override
  void dispose() {
    _activity?.removeListener(_handleVisibilityChange);
    _volumeTimer?.cancel();
    super.dispose();
  }

  void _handleVisibilityChange() {
    final visible = _activity?.isVisible(ControlPageIndex.macPlayback) ?? false;
    if (visible && _devices.isEmpty) {
      unawaited(_refreshOutputs());
    }
  }

  MacService _service() {
    return MacService(
        context.read<SettingsProvider>().settings.macAgentBaseUrl);
  }

  void _pingActivity() {
    context.read<PageActivityController>().pingActivity();
  }

  Future<void> _refreshOutputs() async {
    setState(() => _loading = true);
    final devices = await _service().fetchOutputDevices();
    if (!mounted) return;
    setState(() {
      _devices = devices;
      _selectedDeviceId ??= devices.isEmpty ? null : devices.first.id;
      _loading = false;
      _message = devices.isEmpty ? 'No output devices found' : null;
    });
  }

  Future<void> _runAction(
    Future<bool> Function(MacService service) action, {
    String successMessage = 'Command sent',
  }) async {
    if (_busy) return;
    _pingActivity();
    setState(() {
      _busy = true;
      _message = null;
    });

    final ok = await action(_service());
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = ok ? successMessage : 'Mac agent did not accept command';
    });
  }

  Future<void> _playPause() => _runAction(
        (service) => service.mediaPlayPause(),
        successMessage: 'Play / pause sent',
      );

  Future<void> _previousTrack() => _runAction(
        (service) => service.mediaPrevious(),
        successMessage: 'Previous sent',
      );

  Future<void> _nextTrack() => _runAction(
        (service) => service.mediaNext(),
        successMessage: 'Next sent',
      );

  void _onVolumeChanged(double value) {
    _pingActivity();
    setState(() => _volume = value);
    _volumeTimer?.cancel();
    _volumeTimer = Timer(_volumeDebounce, () {
      unawaited(_sendVolume(value.round()));
    });
  }

  Future<void> _sendVolume(int value) async {
    if (_volumeSending) return;
    _volumeSending = true;
    final ok = await _service().setVolume(value);
    if (!mounted) {
      _volumeSending = false;
      return;
    }
    setState(() {
      _message = ok ? 'Volume ${value.clamp(0, 100)}%' : 'Volume update failed';
    });
    _volumeSending = false;
  }

  Future<void> _onVolumeChangeEnd(double value) async {
    _volumeTimer?.cancel();
    await _sendVolume(value.round());
  }

  Future<void> _setOutputDevice(String? deviceId) async {
    if (deviceId == null || deviceId == _selectedDeviceId) return;
    _pingActivity();
    setState(() {
      _selectedDeviceId = deviceId;
      _busy = true;
      _message = null;
    });
    final ok = await _service().setOutputDevice(deviceId);
    if (!mounted) return;
    final name = _devices
        .where((device) => device.id == deviceId)
        .map((device) => device.name)
        .firstOrNull;
    setState(() {
      _busy = false;
      _message = ok ? 'Output: ${name ?? deviceId}' : 'Output switch failed';
    });
  }

  @override
  Widget build(BuildContext context) {
    final macAgentUrl =
        context.watch<SettingsProvider>().settings.macAgentBaseUrl;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: GestureDetector(
        onTapDown: (_) => _pingActivity(),
        onPanDown: (_) => _pingActivity(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'MAC PLAYBACK',
                      style: AppTextStyles.labelLG(color: AppColors.white90),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        macAgentUrl.replaceFirst(RegExp(r'^https?://'), ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: AppTextStyles.labelSM(color: AppColors.white30),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox.square(
                      dimension: 36,
                      child: IconButton(
                        tooltip: 'Refresh outputs',
                        onPressed: _loading ? null : _refreshOutputs,
                        icon: const Icon(Symbols.refresh, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 720;
                      final controls = StaggeredReveal(
                        index: 0,
                        child: _PlaybackPanel(
                          busy: _busy,
                          onPrevious: _previousTrack,
                          onPlayPause: _playPause,
                          onNext: _nextTrack,
                        ),
                      );
                      final volume = StaggeredReveal(
                        index: 1,
                        child: _VolumePanel(
                          loading: _loading,
                          volume: _volume,
                          devices: _devices,
                          selectedDeviceId: _selectedDeviceId,
                          onVolumeChanged: _onVolumeChanged,
                          onVolumeChangeEnd: _onVolumeChangeEnd,
                          onDeviceChanged: _busy ? null : _setOutputDevice,
                        ),
                      );

                      if (compact) {
                        return Column(
                          children: [
                            Expanded(child: controls),
                            const SizedBox(height: 14),
                            Expanded(child: volume),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(flex: 6, child: controls),
                          const SizedBox(width: 14),
                          Expanded(flex: 5, child: volume),
                        ],
                      );
                    },
                  ),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _message!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelSM(color: AppColors.white40),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaybackPanel extends StatelessWidget {
  const _PlaybackPanel({
    required this.busy,
    required this.onPrevious,
    required this.onPlayPause,
    required this.onNext,
  });

  final bool busy;
  final VoidCallback onPrevious;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TRANSPORT',
            style: AppTextStyles.labelLG(color: AppColors.white90),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: _MediaButton(
                  icon: Symbols.skip_previous,
                  label: 'PREV',
                  enabled: !busy,
                  onTap: onPrevious,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: _MediaButton(
                  icon: Symbols.play_pause,
                  label: 'PLAY / PAUSE',
                  prominent: true,
                  enabled: !busy,
                  onTap: onPlayPause,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _MediaButton(
                  icon: Symbols.skip_next,
                  label: 'NEXT',
                  enabled: !busy,
                  onTap: onNext,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              const Icon(
                Symbols.laptop_mac,
                size: 18,
                color: AppColors.white30,
                weight: 300,
              ),
              const SizedBox(width: 10),
              Text(
                busy ? 'SENDING' : 'READY',
                style: AppTextStyles.labelSM(color: AppColors.white30),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VolumePanel extends StatelessWidget {
  const _VolumePanel({
    required this.loading,
    required this.volume,
    required this.devices,
    required this.selectedDeviceId,
    required this.onVolumeChanged,
    required this.onVolumeChangeEnd,
    required this.onDeviceChanged,
  });

  final bool loading;
  final double volume;
  final List<MacAudioDevice> devices;
  final String? selectedDeviceId;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<double> onVolumeChangeEnd;
  final ValueChanged<String?>? onDeviceChanged;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'VOLUME',
                style: AppTextStyles.labelLG(color: AppColors.white90),
              ),
              const Spacer(),
              Text(
                '${volume.round()}%',
                style: AppTextStyles.headlineMD(color: AppColors.white90),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Slider(
            min: 0,
            max: 100,
            value: volume.clamp(0, 100).toDouble(),
            onChanged: onVolumeChanged,
            onChangeEnd: onVolumeChangeEnd,
          ),
          const SizedBox(height: 22),
          Text(
            'OUTPUT',
            style: AppTextStyles.labelSM(color: AppColors.white40),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: selectedDeviceId,
            isExpanded: true,
            hint: Text(
              loading ? 'Loading outputs' : 'No output device',
              style: AppTextStyles.bodyLG(color: AppColors.white40),
            ),
            items: devices
                .map(
                  (device) => DropdownMenuItem<String>(
                    value: device.id,
                    child: Text(
                      device.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: onDeviceChanged,
            decoration: const InputDecoration(border: InputBorder.none),
          ),
          const Spacer(),
          _LevelMeter(value: volume),
        ],
      ),
    );
  }
}

class _MediaButton extends StatelessWidget {
  const _MediaButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.prominent = false,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: enabled ? 1 : 0.45,
          child: GlassContainer(
            borderRadius: 18,
            isActive: prominent,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: prominent ? 32 : 24,
                  color: AppColors.white90,
                  fill: 0,
                  weight: 300,
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSM(color: AppColors.white90),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelMeter extends StatelessWidget {
  const _LevelMeter({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(18, (index) {
          final threshold = (index + 1) / 18;
          final active = value / 100 >= threshold;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                height: 8 + (index % 6) * 5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: active ? AppColors.white60 : AppColors.white08,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

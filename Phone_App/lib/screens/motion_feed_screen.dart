import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../models/app_settings.dart';
import '../providers/device_provider.dart';
import '../providers/settings_provider.dart';
import '../theme.dart';

class MotionFeedScreen extends StatefulWidget {
  const MotionFeedScreen({super.key});

  @override
  State<MotionFeedScreen> createState() => _MotionFeedScreenState();
}

class _MotionFeedScreenState extends State<MotionFeedScreen> {
  CameraController? _previewController;
  DeviceProvider? _device;
  bool _cameraReady = false;
  bool _starting = true;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final device = context.read<DeviceProvider>();
    _device = device;
    await device.startMotionDetection();
    if (!mounted) return;

    final controller = device.motionDetector.cameraController;
    setState(() {
      _previewController = controller;
      _cameraReady = controller != null && controller.value.isInitialized;
      _starting = false;
    });
  }

  Future<void> _switchCamera(bool useFrontCamera) async {
    final settingsProvider = context.read<SettingsProvider>();
    final updated = AppSettings.fromJson(settingsProvider.settings.toJson())
      ..motionUseFrontCamera = useFrontCamera;
    await settingsProvider.save(updated);
    await _device!.updateSettings(updated);

    setState(() {
      _starting = true;
      _cameraReady = false;
      _previewController = null;
    });
    final success = await _device!.switchMotionCamera();
    if (!mounted) return;
    final controller = _device!.motionDetector.cameraController;
    setState(() {
      _previewController = controller;
      _cameraReady =
          success && controller != null && controller.value.isInitialized;
      _starting = false;
    });
  }

  Future<void> _toggleStealth() async {
    final settingsProvider = context.read<SettingsProvider>();
    final updated = AppSettings.fromJson(settingsProvider.settings.toJson())
      ..motionStealthEnabled = !settingsProvider.settings.motionStealthEnabled;
    await settingsProvider.save(updated);
    await _device!.updateSettings(updated);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    unawaited(_device?.stopMotionDetection());
    _previewController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final device = context.watch<DeviceProvider>();
    final state = device.state;
    final motionDetected = state.motionStatus == 'MOTION' ||
        (state.lastMotionDetected != null &&
            DateTime.now().difference(state.lastMotionDetected!).inSeconds <
                10);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await device.stopMotionDetection();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.black,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(status: state.motionStatus ?? 'IDLE'),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: _starting
                          ? const _Initializing()
                          : device.settings.motionStealthEnabled
                              ? _StealthMonitor(
                                  status: state.motionStatus ?? 'STANDBY',
                                  frontCamera:
                                      device.settings.motionUseFrontCamera,
                                )
                              : _cameraReady && _previewController != null
                                  ? CameraPreview(_previewController!)
                                  : const _Placeholder(),
                    ),
                    if (motionDetected) const _MotionDetectedAlert(),
                  ],
                ),
              ),
              _BottomControls(
                useFrontCamera: device.settings.motionUseFrontCamera,
                stealthEnabled: device.settings.motionStealthEnabled,
                onSwitchCamera: _switchCamera,
                onToggleStealth: _toggleStealth,
                onStop: () async {
                  await device.stopMotionDetection();
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.status});

  final String status;

  Color _statusColor() {
    switch (status) {
      case 'MOTION':
        return const Color(0xFFFF4444);
      case 'DETECTING':
        return const Color(0xFFFFCC44);
      case 'SCANNING':
        return const Color(0xFF5588FF);
      default:
        return AppColors.white40;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.white20)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              final device = context.read<DeviceProvider>();
              await device.stopMotionDetection();
              if (context.mounted) Navigator.of(context).pop();
            },
            behavior: HitTestBehavior.opaque,
            child: Text('← MOTION',
                style: AppTextStyles.labelLG(color: AppColors.white90)),
          ),
          const Spacer(),
          Icon(Symbols.videocam, size: 14, color: _statusColor()),
          const SizedBox(width: 8),
          Text(status, style: AppTextStyles.labelLG(color: _statusColor())),
        ],
      ),
    );
  }
}

class _Initializing extends StatelessWidget {
  const _Initializing();

  @override
  Widget build(BuildContext context) => const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.white60),
          SizedBox(height: 16),
          Text('STARTING CAMERA',
              style: TextStyle(color: AppColors.white60, letterSpacing: 2)),
        ],
      );
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    final status = context.watch<DeviceProvider>().state.motionStatus ?? 'IDLE';
    final isError = status == 'ERROR';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(isError ? Symbols.videocam_off : Symbols.motion_photos_paused,
            size: 64,
            color: isError ? const Color(0xFFFF7777) : AppColors.white10),
        const SizedBox(height: 16),
        Text(isError ? 'CAMERA ACCESS NEEDED' : 'WAITING FOR MOTION',
            style: AppTextStyles.labelLG(color: AppColors.white60)),
      ],
    );
  }
}

class _StealthMonitor extends StatelessWidget {
  const _StealthMonitor({required this.status, required this.frontCamera});

  final String status;
  final bool frontCamera;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Symbols.visibility_off,
              size: 72, color: AppColors.white60, weight: 300),
          const SizedBox(height: AppSpace.lg),
          Text('STEALTH MONITORING ACTIVE',
              style: AppTextStyles.labelLG(color: AppColors.white90)
                  .copyWith(fontSize: 12, letterSpacing: 1.8)),
          const SizedBox(height: AppSpace.sm),
          Text('${frontCamera ? 'FRONT' : 'BACK'} CAMERA • $status',
              style: AppTextStyles.labelSM(color: AppColors.white60)),
        ],
      );
}

class _MotionDetectedAlert extends StatelessWidget {
  const _MotionDetectedAlert();

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFD32F2F).withValues(alpha: 0.94),
              border: Border.all(color: AppColors.white, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Symbols.warning, color: AppColors.white, size: 28),
                const SizedBox(width: AppSpace.md),
                Text('MOTION DETECTED',
                    style: AppTextStyles.labelLG(color: AppColors.white)
                        .copyWith(fontSize: 16, letterSpacing: 2.2)),
              ],
            ),
          ),
        ),
      );
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.onStop,
    required this.onSwitchCamera,
    required this.onToggleStealth,
    required this.useFrontCamera,
    required this.stealthEnabled,
  });

  final VoidCallback onStop;
  final ValueChanged<bool> onSwitchCamera;
  final VoidCallback onToggleStealth;
  final bool useFrontCamera;
  final bool stealthEnabled;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.white20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _ControlButton(
                    icon: Symbols.cameraswitch,
                    label:
                        useFrontCamera ? 'USE BACK CAMERA' : 'USE FRONT CAMERA',
                    onPressed: () => onSwitchCamera(!useFrontCamera),
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: _ControlButton(
                    icon: stealthEnabled
                        ? Symbols.visibility
                        : Symbols.visibility_off,
                    label: stealthEnabled ? 'SHOW LIVE VIEW' : 'STEALTH MODE',
                    onPressed: onToggleStealth,
                    active: stealthEnabled,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: TextButton.icon(
                onPressed: onStop,
                icon: const Icon(Symbols.stop_circle, size: 20),
                label: Text('STOP MOTION DETECT',
                    style:
                        AppTextStyles.labelLG(color: const Color(0xFFFF4444))),
                style: TextButton.styleFrom(
                  backgroundColor:
                      const Color(0xFFFF4444).withValues(alpha: 0.15),
                  foregroundColor: const Color(0xFFFF4444),
                  side: const BorderSide(color: Color(0xFFFF4444)),
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero),
                ),
              ),
            ),
          ],
        ),
      );
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 44,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label,
              style: AppTextStyles.labelSM(color: AppColors.white90)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.white90,
            backgroundColor: active ? AppColors.white10 : Colors.transparent,
            side: BorderSide(
                color: active ? AppColors.white90 : AppColors.white30),
            shape:
                const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
        ),
      );
}

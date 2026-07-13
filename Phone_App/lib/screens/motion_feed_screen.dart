import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../providers/device_provider.dart';
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
    if (controller == null || !controller.value.isInitialized) {
      if (mounted) {
        setState(() {
          _starting = false;
          _cameraReady = false;
        });
      }
      return;
    }

    setState(() {
      _previewController = controller;
      _cameraReady = true;
      _starting = false;
    });
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await device.stopMotionDetection();
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.black,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(status: device.state.motionStatus ?? 'IDLE'),
              Expanded(
                child: Center(
                  child: _starting
                      ? const _Initializing()
                      : _cameraReady && _previewController != null
                          ? CameraPreview(_previewController!)
                          : const _Placeholder(),
                ),
              ),
              _BottomControls(
                onStop: () async {
                  final device = context.read<DeviceProvider>();
                  await device.stopMotionDetection();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
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

  Color _statusColor(String status) {
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
        border: Border(
          bottom: BorderSide(color: AppColors.white20, width: 1),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              final device = context.read<DeviceProvider>();
              await device.stopMotionDetection();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Text(
              '← MOTION',
              style: AppTextStyles.labelLG(color: AppColors.white90),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              const Icon(
                Symbols.videocam,
                size: 14,
                color: AppColors.white40,
                weight: 300,
                opticalSize: 24,
              ),
              const SizedBox(width: 8),
              Text(
                status,
                style: AppTextStyles.labelLG(color: _statusColor(status)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Initializing extends StatelessWidget {
  const _Initializing();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const CircularProgressIndicator(color: AppColors.white60),
        const SizedBox(height: 16),
        Text(
          'STARTING CAMERA',
          style: AppTextStyles.labelLG(color: AppColors.white60),
        ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    final status = context.watch<DeviceProvider>().state.motionStatus ?? 'IDLE';
    final isError = status == 'ERROR';
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isError ? Symbols.videocam_off : Symbols.motion_photos_paused,
            size: 64,
            color: isError ? const Color(0xFFFF7777) : AppColors.white10,
            weight: 300,
            opticalSize: 24,
          ),
          const SizedBox(height: 16),
          Text(
            isError
                ? 'CAMERA ACCESS NEEDED'
                : status == 'MOTION'
                    ? 'MOTION DETECTED'
                    : 'WAITING FOR MOTION',
            textAlign: TextAlign.center,
            style: AppTextStyles.labelLG(color: AppColors.white60),
          ),
        ],
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({required this.onStop});

  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.white20, width: 1),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: TextButton(
          onPressed: onStop,
          style: TextButton.styleFrom(
            backgroundColor: const Color(0xFFFF4444).withValues(alpha: 0.15),
            foregroundColor: const Color(0xFFFF4444),
            side: const BorderSide(color: Color(0xFFFF4444), width: 1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Symbols.stop_circle,
                size: 20,
                weight: 300,
                opticalSize: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'STOP MOTION DETECT',
                style: AppTextStyles.labelLG(color: const Color(0xFFFF4444)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'control_screen.dart';
import 'mac_control_screen.dart';
import 'mac_media_screen.dart';

class ControlPagesScreen extends StatelessWidget {
  const ControlPagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageView(
      physics: const BouncingScrollPhysics(),
      reverse: true,
      children: const [
        ControlScreen(),
        MacControlScreen(),
        MacMediaScreen(),
      ],
    );
  }
}

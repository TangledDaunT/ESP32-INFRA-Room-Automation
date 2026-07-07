import 'package:flutter/material.dart';

import '../theme.dart';

Future<TimeOfDay?> showTimePickerSheet(
  BuildContext context, {
  required String title,
  required TimeOfDay initialTime,
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => TimePickerSheet(
      title: title,
      initialTime: initialTime,
    ),
  );
}

Future<int?> showNumericPickerSheet(
  BuildContext context, {
  required String title,
  required int initialValue,
  required int min,
  required int max,
  String? suffix,
}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => NumericPickerSheet(
      title: title,
      initialValue: initialValue,
      min: min,
      max: max,
      suffix: suffix,
    ),
  );
}

class TimePickerSheet extends StatefulWidget {
  const TimePickerSheet({
    super.key,
    required this.title,
    required this.initialTime,
  });

  final String title;
  final TimeOfDay initialTime;

  @override
  State<TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<TimePickerSheet> {
  late int _hour = widget.initialTime.hour;
  late int _minute = widget.initialTime.minute;

  @override
  Widget build(BuildContext context) {
    return _PickerShell(
      title: widget.title,
      child: Row(
        children: [
          Expanded(
            child: _PickerColumn(
              initialItem: _hour,
              count: 24,
              builder: (value) => value.toString().padLeft(2, '0'),
              onSelectedItemChanged: (value) => setState(() => _hour = value),
            ),
          ),
          Text(
            ':',
            style: AppTextStyles.displayLG(color: AppColors.white40),
          ),
          Expanded(
            child: _PickerColumn(
              initialItem: _minute,
              count: 60,
              builder: (value) => value.toString().padLeft(2, '0'),
              onSelectedItemChanged: (value) => setState(() => _minute = value),
            ),
          ),
        ],
      ),
      onSet: () =>
          Navigator.of(context).pop(TimeOfDay(hour: _hour, minute: _minute)),
    );
  }
}

class NumericPickerSheet extends StatefulWidget {
  const NumericPickerSheet({
    super.key,
    required this.title,
    required this.initialValue,
    required this.min,
    required this.max,
    this.suffix,
  });

  final String title;
  final int initialValue;
  final int min;
  final int max;
  final String? suffix;

  @override
  State<NumericPickerSheet> createState() => _NumericPickerSheetState();
}

class _NumericPickerSheetState extends State<NumericPickerSheet> {
  late int _value = widget.initialValue.clamp(widget.min, widget.max);

  @override
  Widget build(BuildContext context) {
    return _PickerShell(
      title: widget.title,
      child: _PickerColumn(
        initialItem: _value - widget.min,
        count: widget.max - widget.min + 1,
        builder: (index) => '${index + widget.min}${widget.suffix ?? ''}',
        onSelectedItemChanged: (index) {
          setState(() => _value = widget.min + index);
        },
      ),
      onSet: () => Navigator.of(context).pop(_value),
    );
  }
}

class _PickerShell extends StatelessWidget {
  const _PickerShell({
    required this.title,
    required this.child,
    required this.onSet,
  });

  final String title;
  final Widget child;
  final VoidCallback onSet;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.black,
        border: Border(top: AppBorders.thinBorder),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  title.toUpperCase(),
                  style: AppTextStyles.labelLG(color: AppColors.white90),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Divider(
                      color: AppColors.white20, thickness: 1, height: 1),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            SizedBox(
              height: 220,
              child: child,
            ),
            const SizedBox(height: AppSpace.lg),
            GestureDetector(
              onTap: onSet,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.white60, width: 1),
                ),
                alignment: Alignment.center,
                child: Text(
                  'SET',
                  style: AppTextStyles.labelLG(color: AppColors.white90),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerColumn extends StatefulWidget {
  const _PickerColumn({
    required this.initialItem,
    required this.count,
    required this.builder,
    required this.onSelectedItemChanged,
  });

  final int initialItem;
  final int count;
  final String Function(int value) builder;
  final ValueChanged<int> onSelectedItemChanged;

  @override
  State<_PickerColumn> createState() => _PickerColumnState();
}

class _PickerColumnState extends State<_PickerColumn> {
  // Created once and reused for the life of this column — the previous
  // implementation built a new FixedExtentScrollController on every scroll
  // detent (every setState the parent picker triggered) and never disposed
  // the discarded ones, leaking a controller per tick of every time/number
  // picker interaction across Settings and Alarms.
  late final FixedExtentScrollController _controller =
      FixedExtentScrollController(initialItem: widget.initialItem);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: _controller,
      itemExtent: 54,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: widget.onSelectedItemChanged,
      perspective: 0.003,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: widget.count,
        builder: (context, index) {
          return Center(
            child: Text(
              widget.builder(index),
              style: AppTextStyles.displayLG(color: AppColors.white90),
            ),
          );
        },
      ),
    );
  }
}

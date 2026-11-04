import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';

import '../../../../core/util/date_only.dart';

/// Read-only field that opens the date picker. Shows a clear button when
/// [clearable] is true and a date is set.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.clearable = false,
    this.firstDate,
    this.lastDate,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool clearable;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    final DateTime? current = value;

    return InkWell(
      borderRadius: AppRadius.controlBorder,
      onTap: () async {
        final DateTime start = firstDate ?? DateTime(2000);
        final DateTime end = lastDate ?? DateTime(2100);
        DateTime initial = current ?? dateOnly(DateTime.now());
        if (initial.isBefore(start)) {
          initial = start;
        }
        if (initial.isAfter(end)) {
          initial = end;
        }
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: start,
          lastDate: end,
        );
        if (picked != null) {
          onChanged(dateOnly(picked));
        }
      },
      child: InputDecorator(
        isEmpty: current == null,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: (clearable && current != null)
              ? IconButton(
                  tooltip: 'Clear $label',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => onChanged(null),
                )
              : const Icon(Icons.event_rounded),
        ),
        child: Text(
          current == null ? '' : formatDate(current),
          style: context.akText.bodyLarge,
        ),
      ),
    );
  }
}

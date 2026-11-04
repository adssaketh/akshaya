import 'package:flutter/material.dart';

/// Visual status of a pantry item.
///
/// Domain code (Phase 1) decides which kind applies to a stock record; the
/// design system only owns the label, icon and colours for each kind. Every
/// kind has a distinct icon and word so status never relies on colour alone.
enum StatusKind {
  fresh('Fresh', Icons.check_rounded),
  expiring('Expiring soon', Icons.schedule_rounded),
  expired('Expired', Icons.warning_amber_rounded),
  lowStock('Low stock', Icons.arrow_downward_rounded),
  outOfStock('Out of stock', Icons.remove_circle_outline_rounded);

  const StatusKind(this.label, this.icon);

  /// Default English label (the app always displays English).
  final String label;

  /// Default icon shown next to the label.
  final IconData icon;
}

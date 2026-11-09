import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/presentation/providers.dart';

/// How the pantry list is drawn.
enum PantryViewMode {
  list('list', 'List', Icons.view_list_rounded),
  grid('grid', 'Grid', Icons.grid_view_rounded),
  gallery('gallery', 'Gallery', Icons.image_outlined),
  compact('compact', 'Compact', Icons.format_list_bulleted_rounded);

  const PantryViewMode(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;

  static PantryViewMode fromKey(String? text) {
    for (final PantryViewMode m in PantryViewMode.values) {
      if (m.key == text) {
        return m;
      }
    }
    return PantryViewMode.list;
  }
}

/// Keys in the local settings table (per phone, never synced).
abstract final class PantryViewKeys {
  static const String mode = 'pantry.view_mode';
  static const String zoom = 'pantry.zoom';
}

const int kPantryZoomMax = 3;
const int kPantryZoomDefault = 1;

/// View mode and zoom of the pantry list.
final class PantryViewSettings {
  const PantryViewSettings({
    this.mode = PantryViewMode.list,
    this.zoom = kPantryZoomDefault,
  });

  factory PantryViewSettings.fromMap(Map<String, String> values) {
    return PantryViewSettings(
      mode: PantryViewMode.fromKey(values[PantryViewKeys.mode]),
      zoom: (int.tryParse(values[PantryViewKeys.zoom] ?? '') ??
              kPantryZoomDefault)
          .clamp(0, kPantryZoomMax),
    );
  }

  final PantryViewMode mode;

  /// 0 (smallest) to [kPantryZoomMax] (largest).
  final int zoom;

  /// List and compact: text size multiplier.
  double get textFactor {
    const List<double> list = <double>[0.9, 1.0, 1.15, 1.3];
    const List<double> compact = <double>[0.9, 1.0, 1.1, 1.2];
    return (mode == PantryViewMode.compact ? compact : list)[zoom];
  }

  /// Grid and gallery: tiles per row.
  int get columns {
    const List<int> grid = <int>[4, 3, 2, 1];
    const List<int> gallery = <int>[3, 2, 2, 1];
    return (mode == PantryViewMode.gallery ? gallery : grid)[zoom];
  }

  // Equality keeps the pantry from rebuilding when unrelated settings (usage
  // counters and so on) are written to the same table.
  @override
  bool operator ==(Object other) {
    return other is PantryViewSettings &&
        other.mode == mode &&
        other.zoom == zoom;
  }

  @override
  int get hashCode => Object.hash(mode, zoom);
}

final Provider<PantryViewSettings> pantryViewProvider =
    Provider<PantryViewSettings>((Ref ref) {
  final Map<String, String> stored =
      ref.watch(settingsMapProvider).value ?? const <String, String>{};
  return PantryViewSettings.fromMap(stored);
});

/// Saves the view mode and/or zoom.
Future<void> savePantryView(
  WidgetRef ref, {
  PantryViewMode? mode,
  int? zoom,
}) {
  return ref.read(settingsRepositoryProvider).writeAll(<String, String>{
    if (mode != null) PantryViewKeys.mode: mode.key,
    if (zoom != null) PantryViewKeys.zoom: '${zoom.clamp(0, kPantryZoomMax)}',
  });
}

import 'package:flutter/material.dart';

import '../tokens/layout_tokens.dart';

/// One row of controls under the header (search box, segmented switch, sort
/// button). Gives every screen the same side margin and the same gap below.
class ToolbarRow extends StatelessWidget {
  const ToolbarRow({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: child,
    );
  }
}

/// A horizontally scrolling row of chips with the standard gap, optionally
/// followed by a fixed [trailing] widget (a menu button).
class ChipRow extends StatelessWidget {
  const ChipRow({super.key, required this.children, this.trailing});

  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final Widget scroller = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.lg),
      child: Row(
        children: <Widget>[
          for (final (int i, Widget c) in children.indexed) ...<Widget>[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            c,
          ],
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: trailing == null
          ? scroller
          : Row(
              children: <Widget>[
                Expanded(child: scroller),
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: trailing,
                ),
              ],
            ),
    );
  }
}

/// A segment of [AkshayaSegmented].
@immutable
class AkshayaSegment<T> {
  const AkshayaSegment({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// The full-width two-or-three way switch used under the header (Category /
/// Location, Ideas / Saved). Styling comes from the theme's segmented-button
/// theme, so every switch in the app looks the same.
class AkshayaSegmented<T> extends StatelessWidget {
  const AkshayaSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<AkshayaSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      showSelectedIcon: false,
      segments: <ButtonSegment<T>>[
        for (final AkshayaSegment<T> s in segments)
          ButtonSegment<T>(
            value: s.value,
            label: Text(s.label),
            icon: s.icon == null ? null : Icon(s.icon),
          ),
      ],
      selected: <T>{selected},
      onSelectionChanged: (Set<T> value) => onChanged(value.first),
    );
  }
}

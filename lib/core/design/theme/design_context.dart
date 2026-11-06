import 'package:flutter/material.dart';

import '../tokens/akshaya_colors.dart';

/// Shortcuts for reading design tokens from a [BuildContext].
extension AkshayaThemeContext on BuildContext {
  /// Akshaya colour tokens for the current theme.
  ///
  /// Falls back to the matching palette when the ambient theme is not an
  /// Akshaya theme (for example a bare MaterialApp in a test).
  AkshayaColors get akColors {
    final ThemeData theme = Theme.of(this);
    return theme.extension<AkshayaColors>() ??
        (theme.brightness == Brightness.dark
            ? AkshayaColors.dark
            : AkshayaColors.light);
  }

  /// Space at the bottom of the screen taken by the floating navigation bar
  /// (and the system gesture area). Tab screens run behind the bar, so their
  /// scrolling content adds this to its bottom padding. On screens pushed over
  /// the tabs it is only the system inset.
  double get navClearance => MediaQuery.paddingOf(this).bottom;

  /// Extra lift a floating button needs on a tab screen: the bar's height
  /// beyond the system inset the Scaffold already respects.
  double get navBarInset {
    final double extra = MediaQuery.paddingOf(this).bottom -
        MediaQuery.viewPaddingOf(this).bottom;
    return extra > 0 ? extra : 0;
  }

  /// Text theme for the current theme.
  TextTheme get akText => Theme.of(this).textTheme;
}

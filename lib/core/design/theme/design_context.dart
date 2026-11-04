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

  /// Text theme for the current theme.
  TextTheme get akText => Theme.of(this).textTheme;
}

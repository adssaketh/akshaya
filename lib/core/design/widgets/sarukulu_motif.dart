import 'package:flutter/material.dart';

import '../theme/design_context.dart';
import '../tokens/layout_tokens.dart';

/// A small diamond of dots (1-3-5-3-1), used as a quiet decorative motif in
/// headers and empty states. Named for sarukulu (సరుకులు), the groceries and
/// provisions the app keeps track of.
class SarukuluMotif extends StatelessWidget {
  const SarukuluMotif({
    super.key,
    this.size = AppSizes.sarukuluHeader,
    this.color,
  });

  final double size;

  /// Defaults to the accent colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _SarukuluPainter(color ?? context.akColors.accent),
      ),
    );
  }
}

class _SarukuluPainter extends CustomPainter {
  _SarukuluPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double unit = size.width / 48;
    final Paint paint = Paint()..color = color.withValues(alpha: 0.55);
    for (int row = -2; row <= 2; row++) {
      final int count = 5 - 2 * row.abs();
      for (int i = 0; i < count; i++) {
        final double dx = (i - (count - 1) / 2) * 9 * unit;
        final double dy = row * 9 * unit;
        canvas.drawCircle(
          Offset(size.width / 2 + dx, size.height / 2 + dy),
          1.8 * unit,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SarukuluPainter oldDelegate) =>
      oldDelegate.color != color;
}

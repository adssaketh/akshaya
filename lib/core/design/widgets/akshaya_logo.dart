import 'package:flutter/material.dart';

import '../theme/design_context.dart';
import '../tokens/layout_tokens.dart';

/// The Akshaya Patra mark: a pot that never empties, with grains rising
/// from it. Drawn in code so it recolours with the theme.
class AkshayaLogo extends StatelessWidget {
  const AkshayaLogo({super.key, this.size = AppSizes.logo, this.color});

  final double size;

  /// Defaults to the primary colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Akshaya',
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: _LogoPainter(color ?? context.akColors.primary),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);

    final Paint fill = Paint()..color = color;
    final Path pot = Path()
      ..moveTo(6, 11)
      ..lineTo(18, 11)
      ..lineTo(16.8, 18)
      ..arcToPoint(const Offset(13.8, 20.5), radius: const Radius.circular(3))
      ..lineTo(10.2, 20.5)
      ..arcToPoint(const Offset(7.2, 18), radius: const Radius.circular(3))
      ..close();
    canvas.drawPath(pot, fill);

    final Paint rim = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final Path lip = Path()
      ..moveTo(8, 11)
      ..cubicTo(8, 9.4, 9.4, 8.6, 12, 8.6)
      ..cubicTo(14.6, 8.6, 16, 9.4, 16, 11);
    canvas.drawPath(lip, rim);

    canvas.drawCircle(const Offset(9.5, 6.2), 1.1, fill);
    canvas.drawCircle(const Offset(12, 4.6), 1.1, fill);
    canvas.drawCircle(const Offset(14.5, 6.2), 1.1, fill);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) => oldDelegate.color != color;
}

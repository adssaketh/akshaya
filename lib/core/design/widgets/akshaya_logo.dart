import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/design_context.dart';
import '../tokens/akshaya_colors.dart';
import '../tokens/layout_tokens.dart';

/// The Akshaya Patra mark: a woven basket that never empties, holding a
/// cleaning bottle, a carrot and leafy greens (food and household supplies
/// in one place), with a handle over the top.
///
/// Drawn in code from the colour tokens, so it follows light and dark mode.
/// The same geometry is in `assets/branding/akshaya_patra_logo.svg` and in
/// the launcher icon (`tool/generate_launcher_icons.py`); change all three
/// together.
class AkshayaLogo extends StatelessWidget {
  const AkshayaLogo({super.key, this.size = AppSizes.logo});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Akshaya Patra',
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: _LogoPainter(context.akColors),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.colors);

  final AkshayaColors colors;

  // The artwork is drawn on a 120-unit grid; its content spans x 27..93 and
  // y 18..103, which is scaled to fill the square and centred.
  static const double _contentTop = 14;
  static const double _contentHeight = 92;
  static const double _centreX = 60;

  void _ellipse(
    Canvas canvas,
    Paint paint, {
    required double cx,
    required double cy,
    required double rx,
    required double ry,
    required double degrees,
  }) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(degrees * math.pi / 180);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
      paint,
    );
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.height / _contentHeight;
    canvas.save();
    canvas.translate(size.width / 2 - _centreX * scale, -_contentTop * scale);
    canvas.scale(scale);

    Paint fill(Color color) => Paint()..color = color;
    // Lit from the top left: a body goes from a lighter to a darker shade of
    // its colour across its bounds.
    Paint shaded(Color color, Rect bounds) => Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color.lerp(color, colors.surface, 0.28)!,
          color,
          Color.lerp(color, colors.textPrimary, 0.38)!,
        ],
        stops: const <double>[0, 0.5, 1],
      ).createShader(bounds);
    Paint shine() => fill(colors.surface.withValues(alpha: 0.4));
    Paint stroke(Color color, double width) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    final Color brown = colors.textPrimary;
    final Color terracotta = colors.primary;
    final Color turmeric = colors.accent;
    final Color leaf = colors.fresh.foreground;
    final Color bottle = colors.lowStock.foreground;

    // Soft shadow under the basket.
    canvas.drawOval(
      const Rect.fromLTWH(28, 101, 68, 9),
      Paint()
        ..color = brown.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Handle.
    canvas.drawPath(
      Path()
        ..moveTo(36, 60)
        ..cubicTo(36, 12, 84, 12, 84, 60),
      stroke(brown, 3.5),
    );

    // Bottle and its cap.
    const Rect bottleRect = Rect.fromLTWH(39, 34, 14, 28);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bottleRect, const Radius.circular(3.5)),
      shaded(bottle, bottleRect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(41, 36, 3, 22),
        const Radius.circular(1.5),
      ),
      shine(),
    );
    const Rect capRect = Rect.fromLTWH(42, 28, 8, 7.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(capRect, const Radius.circular(2.2)),
      shaded(turmeric, capRect),
    );

    // Carrot with its leaves.
    canvas.drawPath(
      Path()
        ..moveTo(58, 62)
        ..lineTo(70, 62)
        ..lineTo(64, 34)
        ..close(),
      shaded(turmeric, const Rect.fromLTWH(58, 34, 12, 28)),
    );
    canvas.drawLine(
      const Offset(60.5, 60),
      const Offset(64, 40),
      stroke(colors.surface.withValues(alpha: 0.4), 1.4),
    );
    canvas.drawPath(
      Path()
        ..moveTo(64, 34)
        ..cubicTo(58, 24, 60, 20, 64, 18)
        ..cubicTo(68, 20, 70, 24, 64, 34)
        ..close(),
      shaded(leaf, const Rect.fromLTWH(60, 18, 8, 16)),
    );

    // Leafy greens.
    _ellipse(
      canvas,
      shaded(leaf, const Rect.fromLTWH(70, 35, 16, 26)),
      cx: 78,
      cy: 48,
      rx: 5,
      ry: 13,
      degrees: 22,
    );
    _ellipse(
      canvas,
      fill(leaf.withValues(alpha: 0.7)),
      cx: 85,
      cy: 52,
      rx: 4,
      ry: 11,
      degrees: 50,
    );

    // Basket.
    canvas.drawPath(
      Path()
        ..moveTo(30, 63)
        ..lineTo(90, 63)
        ..lineTo(84, 99)
        ..quadraticBezierTo(83.5, 103, 79.5, 103)
        ..lineTo(40.5, 103)
        ..quadraticBezierTo(36.5, 103, 36, 99)
        ..close(),
      shaded(terracotta, const Rect.fromLTWH(30, 63, 60, 40)),
    );
    canvas.drawLine(
      const Offset(33, 66),
      const Offset(37.5, 98),
      stroke(colors.surface.withValues(alpha: 0.28), 2),
    );
    const Rect rimRect = Rect.fromLTWH(27, 58, 66, 9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rimRect, const Radius.circular(4.5)),
      shaded(brown, rimRect),
    );

    // Weave.
    final Paint weave = stroke(colors.background, 2.2);
    canvas.drawLine(const Offset(34, 79), const Offset(86, 79), weave);
    canvas.drawLine(const Offset(36, 91), const Offset(84, 91), weave);
    canvas.drawLine(const Offset(48, 68), const Offset(46, 100), weave);
    canvas.drawLine(const Offset(60, 68), const Offset(60, 100), weave);
    canvas.drawLine(const Offset(72, 68), const Offset(74, 100), weave);
    canvas.drawCircle(const Offset(60, 85), 2.6, fill(turmeric));

    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) =>
      oldDelegate.colors != colors;
}

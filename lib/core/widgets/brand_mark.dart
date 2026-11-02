import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The app's logo mark: a doctor bust wearing a stethoscope on a gradient
/// badge — a person actively running their clinic, not an abstract shape
/// that could be read as anything (an earlier ring version was mistaken
/// for an eye). Doubles as the launcher icon (see assets/icon/*.png,
/// rasterized straight from [paintDoctorBadge]).
class BrandMark extends StatefulWidget {
  const BrandMark({super.key, this.size = 40});

  final double size;

  @override
  State<BrandMark> createState() => _BrandMarkState();
}

class _BrandMarkState extends State<BrandMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        final scale = 1 + (0.06 * t);
        final opacity = 0.95 + (0.05 * t);
        return Opacity(
          opacity: opacity,
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(painter: _DoctorBadgePainter()),
      ),
    );
  }
}

class _DoctorBadgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => paintDoctorBadge(canvas, size);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Paints a gradient circular badge with a white doctor bust (head, coat,
/// stethoscope) on top — coordinates are laid out on a normalized 0-100
/// grid, scaled to whatever [size] this is drawn at, so it stays crisp
/// from a small inline header mark up to a 1024px launcher icon. Exposed
/// as a plain function (not just the CustomPainter) so the launcher-icon
/// generator script rasterizes this exact drawing rather than a hand-kept
/// copy of it.
void paintDoctorBadge(Canvas canvas, Size size) {
  final scale = size.width / 100;
  Offset p(double x, double y) => Offset(x * scale, y * scale);
  final center = p(50, 50);

  final sweep = SweepGradient(
    startAngle: 0,
    endAngle: 6.28319,
    colors: const [
      AppColors.focus,
      AppColors.lens,
      AppColors.aqua,
      AppColors.focus,
    ],
  ).createShader(Rect.fromCircle(center: center, radius: 50 * scale));
  canvas.drawCircle(center, 50 * scale, Paint()..shader = sweep);

  final white = Paint()..color = Colors.white;

  // Head.
  canvas.drawCircle(p(50, 33), 13 * scale, white);

  // Coat/shoulders — a rounded poncho shape flaring from the neck down to
  // a wide, softly rounded hem, with a small collar notch at the top where
  // it meets the neck.
  final coat = Path()
    ..moveTo(p(33, 51).dx, p(33, 51).dy)
    ..cubicTo(
      p(27, 61).dx,
      p(27, 61).dy,
      p(19, 70).dx,
      p(19, 70).dy,
      p(17, 85).dx,
      p(17, 85).dy,
    )
    ..quadraticBezierTo(p(50, 93).dx, p(50, 93).dy, p(83, 85).dx, p(83, 85).dy)
    ..cubicTo(
      p(81, 70).dx,
      p(81, 70).dy,
      p(73, 61).dx,
      p(73, 61).dy,
      p(67, 51).dx,
      p(67, 51).dy,
    )
    ..quadraticBezierTo(p(50, 45).dx, p(50, 45).dy, p(33, 51).dx, p(33, 51).dy)
    ..close();
  canvas.drawPath(coat, white);

  // Stethoscope draped around the neck — a rounded U-shaped tube down to a
  // small chest piece, in a darker tone so it reads against the white coat
  // instead of disappearing into it.
  final tubePaint = Paint()
    ..color = AppColors.aquaDeep
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.2 * scale
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  final tube = Path()
    ..moveTo(p(38, 53).dx, p(38, 53).dy)
    ..cubicTo(
      p(35, 64).dx,
      p(35, 64).dy,
      p(41, 74).dx,
      p(41, 74).dy,
      p(50, 74).dx,
      p(50, 74).dy,
    )
    ..cubicTo(
      p(59, 74).dx,
      p(59, 74).dy,
      p(65, 64).dx,
      p(65, 64).dy,
      p(62, 53).dx,
      p(62, 53).dy,
    );
  canvas.drawPath(tube, tubePaint);
  canvas.drawCircle(
    p(50, 77),
    4.4 * scale,
    Paint()..color = AppColors.aquaDeep,
  );
}

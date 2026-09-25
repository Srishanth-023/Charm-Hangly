import 'package:flutter/material.dart';
import '../physics/rope_point.dart';
import '../../../core/models/rope_style.dart';

class RopePainter extends CustomPainter {
  final List<RopePoint> points;
  final RopeStyle style;
  final Color primaryColor;

  RopePainter({
    required this.points,
    required this.style,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    // Match Android overlay exactly
    final ropeColor = style == RopeStyle.goldChain ? const Color(0xFFFFD700) : primaryColor;
    final ropeWidth = 4.5;

    // 1. Ambient Glow behind cord for Neon style
    if (style == RopeStyle.neon) {
      final glowPaint = Paint()
        ..color = ropeColor.withAlpha(80)
        ..strokeWidth = ropeWidth * 3.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      final glowPath = Path();
      glowPath.moveTo(points[0].position.x, points[0].position.y);
      for (int i = 1; i < points.length; i++) {
        glowPath.lineTo(points[i].position.x, points[i].position.y);
      }
      canvas.drawPath(glowPath, glowPaint);
    }

    // 2. Main Rope Path
    final path = Path();
    path.moveTo(points[0].position.x, points[0].position.y);

    // Smooth spline curve through points
    for (int i = 1; i < points.length - 1; i++) {
      final p0 = points[i].position;
      final p1 = points[i + 1].position;
      final midX = (p0.x + p1.x) / 2.0;
      final midY = (p0.y + p1.y) / 2.0;
      path.quadraticBezierTo(p0.x, p0.y, midX, midY);
    }
    path.lineTo(points.last.position.x, points.last.position.y);

    final ropePaint = Paint()
      ..color = ropeColor
      ..strokeWidth = ropeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, ropePaint);

    // 3. Chain links or highlights if applicable
    if (style == RopeStyle.goldChain || style == RopeStyle.silverChain) {
      final linkPaint = Paint()
        ..color = Colors.white.withAlpha(120)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      for (int i = 1; i < points.length; i += 2) {
        canvas.drawCircle(
          Offset(points[i].position.x, points[i].position.y),
          ropeWidth * 0.8,
          linkPaint,
        );
      }
    }

    // Removed Anchor Knot at the top as requested by the user
  }

  @override
  bool shouldRepaint(covariant RopePainter oldDelegate) => true;
}

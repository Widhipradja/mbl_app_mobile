import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class MblAppIcon extends StatelessWidget {
  final double size;

  const MblAppIcon({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MblIconPainter()),
    );
  }
}

class _MblIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Background with white gradient
    final gradientRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, height),
      Radius.circular(width * 0.215),
    );

    final backgroundGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
    );

    final backgroundPaint = Paint()
      ..shader = backgroundGradient.createShader(
        Rect.fromLTWH(0, 0, width, height),
      );

    canvas.drawRRect(gradientRect, backgroundPaint);

    // Decorative background circles
    _drawBackgroundCircles(canvas, width, height);

    // Main blue container with shadow
    final mainContainer = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        width * 0.158,
        height * 0.158,
        width * 0.684,
        height * 0.684,
      ),
      Radius.circular(width * 0.156),
    );

    // Shadow for main container
    final shadowPath = Path()..addRRect(mainContainer);
    canvas.drawShadow(
      shadowPath,
      Colors.black.withOpacity(0.15),
      width * 0.015,
      true,
    );

    // Blue gradient for main container
    final blueGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
    );

    final mainContainerPaint = Paint()
      ..shader = blueGradient.createShader(mainContainer.outerRect);

    canvas.drawRRect(mainContainer, mainContainerPaint);

    // Inner decorative circles
    _drawInnerCircles(canvas, width, height);

    // Top curved accent line
    _drawTopAccent(canvas, width, height);

    // Subtle background icons
    _drawSubtleIcons(canvas, width, height);

    // MBL Text with enhanced styling
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'MBL',
        style: TextStyle(
          color: Colors.white,
          fontSize: width * 0.273,
          fontWeight: FontWeight.w900,
          letterSpacing: -width * 0.01,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.2),
              offset: Offset(0, width * 0.008),
              blurRadius: width * 0.015,
            ),
          ],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((width - textPainter.width) / 2, height * 0.475),
    );

    // Bottom accent line with dots
    _drawBottomAccent(canvas, width, height);

    // Corner decorative dots
    _drawCornerDots(canvas, width, height);
  }

  void _drawBackgroundCircles(Canvas canvas, double width, double height) {
    // Top-left decorative circle (blue)
    final blueCircleGradient = RadialGradient(
      colors: [
        Color(0xFF3B82F6).withOpacity(0.09),
        Color(0xFF3B82F6).withOpacity(0.05),
      ],
    );

    final circlePaint = Paint()
      ..shader = blueCircleGradient.createShader(
        Rect.fromCircle(
          center: Offset(width * 0.146, height * 0.146),
          radius: width * 0.098,
        ),
      );
    canvas.drawCircle(
      Offset(width * 0.146, height * 0.146),
      width * 0.098,
      circlePaint,
    );

    // Bottom-right decorative circle (green accent)
    final greenCircleGradient = RadialGradient(
      colors: [
        Color(0xFF10B981).withOpacity(0.09),
        Color(0xFF10B981).withOpacity(0.05),
      ],
    );

    final greenPaint = Paint()
      ..shader = greenCircleGradient.createShader(
        Rect.fromCircle(
          center: Offset(width * 0.854, height * 0.854),
          radius: width * 0.117,
        ),
      );
    canvas.drawCircle(
      Offset(width * 0.854, height * 0.854),
      width * 0.117,
      greenPaint,
    );

    // Rotated square (orange accent)
    canvas.save();
    canvas.translate(width * 0.806, height * 0.171);
    canvas.rotate(0.349); // 20 degrees in radians

    final orangeGradient = LinearGradient(
      colors: [
        Color(0xFFF59E0B).withOpacity(0.06),
        Color(0xFFD97706).withOpacity(0.04),
      ],
    );

    final squareRect = Rect.fromLTWH(
      -width * 0.073,
      -width * 0.073,
      width * 0.146,
      width * 0.146,
    );
    final squarePaint = Paint()
      ..shader = orangeGradient.createShader(squareRect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(squareRect, Radius.circular(width * 0.029)),
      squarePaint,
    );
    canvas.restore();
  }

  void _drawInnerCircles(Canvas canvas, double width, double height) {
    final innerCirclePaint = Paint()..color = Colors.white.withOpacity(0.09);

    canvas.drawCircle(
      Offset(width * 0.293, height * 0.293),
      width * 0.078,
      innerCirclePaint,
    );
    canvas.drawCircle(
      Offset(width * 0.707, height * 0.707),
      width * 0.098,
      innerCirclePaint,
    );
  }

  void _drawTopAccent(Canvas canvas, double width, double height) {
    final path = Path()
      ..moveTo(width * 0.244, height * 0.244)
      ..quadraticBezierTo(
        width * 0.5,
        height * 0.293,
        width * 0.756,
        height * 0.244,
      );

    final accentPaint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.008
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, accentPaint);
  }

  void _drawSubtleIcons(Canvas canvas, double width, double height) {
    final iconPaint = Paint()
      ..color = Colors.white.withOpacity(0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.01
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Dollar sign (left)
    final dollarPath = Path()
      ..moveTo(width * 0.327, height * 0.342)
      ..lineTo(width * 0.327, height * 0.410)
      ..moveTo(width * 0.307, height * 0.357)
      ..cubicTo(
        width * 0.307,
        height * 0.347,
        width * 0.318,
        height * 0.337,
        width * 0.332,
        height * 0.337,
      )
      ..cubicTo(
        width * 0.346,
        height * 0.337,
        width * 0.357,
        height * 0.347,
        width * 0.357,
        height * 0.357,
      )
      ..cubicTo(
        width * 0.357,
        height * 0.367,
        width * 0.346,
        height * 0.376,
        width * 0.332,
        height * 0.381,
      )
      ..cubicTo(
        width * 0.318,
        height * 0.386,
        width * 0.307,
        height * 0.391,
        width * 0.307,
        height * 0.401,
      )
      ..cubicTo(
        width * 0.307,
        height * 0.411,
        width * 0.318,
        height * 0.420,
        width * 0.332,
        height * 0.420,
      )
      ..cubicTo(
        width * 0.346,
        height * 0.420,
        width * 0.357,
        height * 0.411,
        width * 0.357,
        height * 0.401,
      );

    canvas.drawPath(dollarPath, iconPaint);

    // Community icon (center) - three people heads
    final communityPaint = Paint()
      ..color = Colors.white.withOpacity(0.14)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(width * 0.485, height * 0.366),
      width * 0.015,
      communityPaint,
    );
    canvas.drawCircle(
      Offset(width * 0.515, height * 0.366),
      width * 0.015,
      communityPaint,
    );
    canvas.drawCircle(
      Offset(width * 0.5, height * 0.391),
      width * 0.015,
      communityPaint,
    );

    // Simple body shapes
    final bodyPath = Path()
      ..moveTo(width * 0.478, height * 0.381)
      ..lineTo(width * 0.478, height * 0.410)
      ..moveTo(width * 0.522, height * 0.381)
      ..lineTo(width * 0.522, height * 0.410)
      ..moveTo(width * 0.493, height * 0.406)
      ..lineTo(width * 0.493, height * 0.425)
      ..lineTo(width * 0.507, height * 0.425)
      ..lineTo(width * 0.507, height * 0.406);

    canvas.drawPath(bodyPath, iconPaint);

    // Checkmark (right)
    final checkPath = Path()
      ..moveTo(width * 0.640, height * 0.376)
      ..lineTo(width * 0.655, height * 0.395)
      ..lineTo(width * 0.688, height * 0.352);

    canvas.drawPath(checkPath, iconPaint);
  }

  void _drawBottomAccent(Canvas canvas, double width, double height) {
    // Central line
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = width * 0.006
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(width * 0.324, height * 0.684),
      Offset(width * 0.676, height * 0.684),
      linePaint,
    );

    // Left dot (green accent)
    final leftDotGradient = RadialGradient(
      colors: [
        Color(0xFF10B981).withOpacity(0.95),
        Color(0xFF059669).withOpacity(0.75),
      ],
    );

    final leftDotPaint = Paint()
      ..shader = leftDotGradient.createShader(
        Rect.fromCircle(
          center: Offset(width * 0.305, height * 0.684),
          radius: width * 0.008,
        ),
      );

    canvas.drawCircle(
      Offset(width * 0.305, height * 0.684),
      width * 0.008,
      leftDotPaint,
    );

    // Right dot (orange accent)
    final rightDotGradient = RadialGradient(
      colors: [
        Color(0xFFF59E0B).withOpacity(0.95),
        Color(0xFFD97706).withOpacity(0.75),
      ],
    );

    final rightDotPaint = Paint()
      ..shader = rightDotGradient.createShader(
        Rect.fromCircle(
          center: Offset(width * 0.695, height * 0.684),
          radius: width * 0.008,
        ),
      );

    canvas.drawCircle(
      Offset(width * 0.695, height * 0.684),
      width * 0.008,
      rightDotPaint,
    );
  }

  void _drawCornerDots(Canvas canvas, double width, double height) {
    final dotPaint = Paint()..color = Colors.white.withOpacity(0.18);
    final dotRadius = width * 0.012;

    canvas.drawCircle(
      Offset(width * 0.225, height * 0.225),
      dotRadius,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(width * 0.775, height * 0.225),
      dotRadius,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(width * 0.225, height * 0.775),
      dotRadius,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(width * 0.775, height * 0.775),
      dotRadius,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

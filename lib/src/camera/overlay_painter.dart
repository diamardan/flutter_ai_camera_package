import 'package:flutter/material.dart';

class OvalOverlayPainter extends CustomPainter {
  final Color overlayColor;
  final double borderWidth;

  OvalOverlayPainter({this.overlayColor = const Color.fromRGBO(0, 0, 0, 0.7), this.borderWidth = 3});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = overlayColor;
    // Full screen
    canvas.drawRect(Offset.zero & size, paint);

    // Clear oval center
    final holePaint = Paint()..blendMode = BlendMode.clear;
    final rect = Rect.fromCenter(center: size.center(Offset.zero), width: size.width * 0.7, height: size.height * 0.5);
    canvas.drawOval(rect, holePaint);

    // Draw border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..color = Colors.white;
    canvas.drawOval(rect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

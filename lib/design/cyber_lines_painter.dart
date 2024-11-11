import 'package:flutter/material.dart';

class CyberlinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00FF9F).withOpacity(0.1)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();

    // Draw diagonal lines
    for (double i = -size.width; i < size.width; i += 40) {
      path.moveTo(i, 0);
      path.lineTo(i + size.width / 2, size.height);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

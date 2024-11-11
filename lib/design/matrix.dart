import 'dart:math';
import 'package:flutter/material.dart';

class MatrixRain extends StatefulWidget {
  const MatrixRain({super.key});

  @override
  MatrixRainState createState() => MatrixRainState();
}

class MatrixRainState extends State<MatrixRain>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<MatrixDrop> drops;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration:
          const Duration(milliseconds: 2000), // Slowed down character change
      vsync: this,
    )..repeat();
    drops = List.generate(100, (index) => MatrixDrop());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: MatrixRainPainter(drops, _controller.value),
          child: Container(),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class MatrixDrop {
  double x = Random().nextDouble();
  double y = Random().nextDouble();
  double speed = (Random().nextDouble() * 0.1) + 0.1;
  int framesSinceLastChange = 0;
  DateTime lastUpdated = DateTime.now();
  String character = ''; // Store the current character

  MatrixDrop() {
    character = _getRandomCharacter();
  }

  // Method to determine if 0.5 seconds have passed since the last update
  bool shouldChangeCharacter() {
    if (DateTime.now().difference(lastUpdated).inSeconds >= 0.5) {
      lastUpdated = DateTime.now();
      character = _getRandomCharacter(); // Change character after 2 seconds
      return true;
    }
    return false;
  }

  // Helper to get a random character
  String _getRandomCharacter() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*()-_=+[]{}|;:,.<>?/~`';
    return chars[Random().nextInt(chars.length)];
  }

  void update() {
    y += speed * 0.01;
    framesSinceLastChange++;
  }

  void reset() {
    y = 0;
    speed = (Random().nextDouble() * 0.2) + 0.2;
    framesSinceLastChange = 0;
  }
}

class MatrixRainPainter extends CustomPainter {
  final List<MatrixDrop> drops;
  final double animationValue;
  final String chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*()-_=+[]{}|;:,.<>?/~`';

  MatrixRainPainter(this.drops, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final textStyle = TextStyle(
        color: Colors.greenAccent, fontSize: 16, fontFamily: 'Source Code Pro');
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (var drop in drops) {
      final position = Offset(drop.x * size.width, drop.y * size.height);

      if (drop.shouldChangeCharacter()) {
        drop.update();
      }

      final textSpan = TextSpan(
        text: drop.character, // Use stored character
        style: textStyle,
      );

      textPainter.text = textSpan;
      textPainter.layout();
      textPainter.paint(canvas, position);

      drop.update();
      if (drop.y * size.height > size.height) {
        drop.reset();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

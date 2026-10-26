import 'package:flutter/material.dart';

class CommunityLogoPainter extends CustomPainter {
  const CommunityLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 48, size.height / 48);
    final paint = Paint()..isAntiAlias = true;

    // Chữ thập đỏ y tế
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(21, 5, 7, 22),
        const Radius.circular(1.5),
      ),
      paint..color = const Color(0xffef4654),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(14, 12, 21, 7),
        const Radius.circular(1.5),
      ),
      paint,
    );

    // Bàn tay nâng đỡ xanh dương bên trái
    final left = Path()
      ..moveTo(4, 21)
      ..cubicTo(2, 33, 11, 43, 23, 44)
      ..cubicTo(22, 36, 16, 33, 12, 30)
      ..lineTo(8, 21)
      ..quadraticBezierTo(6, 17, 4, 21)
      ..close();
    canvas.drawPath(left, paint..color = const Color(0xff1474c7));

    // Bàn tay nâng đỡ xanh dương bên phải
    final right = Path()
      ..moveTo(44, 21)
      ..cubicTo(46, 33, 37, 43, 25, 44)
      ..cubicTo(26, 36, 32, 33, 36, 30)
      ..lineTo(40, 21)
      ..quadraticBezierTo(42, 17, 44, 21)
      ..close();
    canvas.drawPath(right, paint..color = const Color(0xff1474c7));

    // Họa tiết cánh lá xanh ngọc
    canvas.drawOval(
      const Rect.fromLTWH(12, 27, 9, 6),
      paint..color = const Color(0xff20b69b),
    );
    canvas.drawOval(const Rect.fromLTWH(27, 27, 9, 6), paint);
    canvas.drawCircle(
      const Offset(24, 31),
      2.8,
      paint..color = const Color(0xff1474c7),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CommunityLogo extends StatelessWidget {
  final double size;
  const CommunityLogo({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(
        painter: CommunityLogoPainter(),
      ),
    );
  }
}

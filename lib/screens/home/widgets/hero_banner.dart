import 'package:flutter/material.dart';

/// Ảnh minh họa khuôn viên y tế, không phải ảnh cơ sở Hiệp Phước thực tế.
class HeroBanner extends StatelessWidget {
  const HeroBanner({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 2.55,
        child: Image.asset(
          'assets/images/health_center_banner.png',
          fit: BoxFit.cover,
          semanticLabel: 'Ảnh minh họa khuôn viên trung tâm y tế',
        ),
      ),
    ),
  );
}

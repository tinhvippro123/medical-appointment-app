import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.onNotifications,
    required this.onProfile,
  });
  final VoidCallback onNotifications, onProfile;
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
    child: Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: MediaQuery.paddingOf(context).top,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xff349ff0), Color(0xff2369d5)],
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.zero,
            child: ClipPath(
              clipper: _HeaderClipper(),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xff349ff0), Color(0xff2369d5)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: Stack(
                  children: [
                    const Positioned(
                      right: 106,
                      top: 18,
                      child: Icon(
                        Icons.add_rounded,
                        size: 32,
                        color: Color(0x147fffff),
                      ),
                    ),
                    const Positioned(
                      right: 66,
                      bottom: 2,
                      child: Icon(
                        Icons.add_rounded,
                        size: 46,
                        color: Color(0x187fffff),
                      ),
                    ),
                    const Positioned(
                      right: 126,
                      bottom: 14,
                      child: Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: Color(0x117fffff),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 8, 18),
                      child: Row(
                        children: [
                          Semantics(
                            label: 'Biểu tượng y tế cộng đồng',
                            image: true,
                            child: const CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.white,
                              child: SizedBox(
                                width: 43,
                                height: 43,
                                child: CustomPaint(
                                  painter: _CommunityLogoPainter(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Trung tâm y tế',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    height: 1.2,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'XÃ HIỆP PHƯỚC',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Vì sức khỏe cộng đồng',
                                  style: TextStyle(
                                    color: Color(0xffd6ebff),
                                    fontSize: 10,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Thông báo',
                            onPressed: onNotifications,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 48,
                            ),
                            padding: const EdgeInsets.all(8),
                            icon: const Icon(
                              Icons.notifications_none_rounded,
                              size: 21,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Hồ sơ cá nhân',
                            onPressed: onProfile,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 48,
                            ),
                            padding: const EdgeInsets.all(8),
                            icon: const Icon(
                              Icons.person_outline_rounded,
                              size: 23,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width, 18)
    ..lineTo(size.width, size.height - 10)
    ..quadraticBezierTo(size.width * .48, size.height + 6, 18, size.height - 8)
    ..quadraticBezierTo(0, size.height - 10, 0, size.height - 14)
    ..lineTo(0, 18)
    ..lineTo(0, 0)
    ..close();
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Biểu tượng minh họa bằng vector; có thể thay bằng logo chính thức.
class _CommunityLogoPainter extends CustomPainter {
  const _CommunityLogoPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 48, size.height / 48);
    final paint = Paint()..isAntiAlias = true;
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
    final left = Path()
      ..moveTo(4, 21)
      ..cubicTo(2, 33, 11, 43, 23, 44)
      ..cubicTo(22, 36, 16, 33, 12, 30)
      ..lineTo(8, 21)
      ..quadraticBezierTo(6, 17, 4, 21)
      ..close();
    canvas.drawPath(left, paint..color = const Color(0xff1474c7));
    final right = Path()
      ..moveTo(44, 21)
      ..cubicTo(46, 33, 37, 43, 25, 44)
      ..cubicTo(26, 36, 32, 33, 36, 30)
      ..lineTo(40, 21)
      ..quadraticBezierTo(42, 17, 44, 21)
      ..close();
    canvas.drawPath(right, paint..color = const Color(0xff1474c7));
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

/// Minh họa vector bằng Flutter; thay bằng ảnh trung tâm chính thức khi có.
class HealthCenterPlaceholder extends StatelessWidget {
  const HealthCenterPlaceholder({super.key});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _BuildingPainter(), child: const SizedBox.expand());
}

class _BuildingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    void rect(double x, double y, double w, double h, Color color) {
      canvas.drawRect(
        Rect.fromLTWH(
          size.width * x,
          size.height * y,
          size.width * w,
          size.height * h,
        ),
        p..color = color,
      );
    }

    rect(0, 0, 1, 1, const Color(0xffbce5ff));
    canvas.drawCircle(
      Offset(size.width * .83, size.height * .2),
      24,
      p..color = const Color(0xffffefb3),
    );
    rect(0, .82, 1, .18, const Color(0xff8bcab8));
    rect(.22, .26, .68, .57, const Color(0xfff2f7fc));
    rect(.18, .23, .76, .05, const Color(0xff2c7bc1));
    rect(.23, .48, .66, .03, const Color(0xffbad7e9));
    for (var row = 0; row < 2; row++) {
      for (var i = 0; i < 6; i++) {
        rect(.27 + i * .1, .34 + row * .23, .055, .11, const Color(0xff64a6cd));
      }
    }
    rect(.49, .66, .15, .17, const Color(0xff2e719e));
    rect(.51, .14, .1, .13, Colors.white);
    rect(.55, .155, .022, .095, const Color(0xffe75962));
    rect(.525, .19, .072, .026, const Color(0xffe75962));
    for (final x in [.12, .95]) {
      rect(x, .65, .018, .22, const Color(0xff77998f));
      canvas.drawCircle(
        Offset(size.width * x, size.height * .62),
        size.height * .14,
        p..color = const Color(0xff55ad91),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FeaturePlaceholder extends StatelessWidget {
  const FeaturePlaceholder({
    super.key,
    required this.title,
    this.icon = Icons.medical_services_outlined,
  });
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: FeatureMessage(title: title, icon: icon),
  );
}

class FeatureMessage extends StatelessWidget {
  const FeatureMessage({super.key, required this.title, required this.icon});
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: AppColors.light,
            child: Icon(icon, size: 42, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Chức năng đang được phát triển.\nThông tin sẽ được cập nhật trong thời gian tới.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.6),
          ),
        ],
      ),
    ),
  );
}

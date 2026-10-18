import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/home_demo_data.dart';

class HealthcareServiceGrid extends StatelessWidget {
  const HealthcareServiceGrid({
    super.key,
    required this.onSelected,
    this.services = homeServices,
  });
  final ValueChanged<HealthService> onSelected;
  final List<HealthService> services;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth <= 20) {
        return const SizedBox.shrink();
      }
      final columns = constraints.maxWidth >= 700 ? 6 : 3;
      final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 12,
        children: services
            .map(
              (service) => SizedBox(
                width: width,
                child: HealthcareServiceCard(
                  service: service,
                  onTap: () => onSelected(service),
                ),
              ),
            )
            .toList(),
      );
    },
  );
}

class HealthcareServiceCard extends StatelessWidget {
  const HealthcareServiceCard({
    super.key,
    required this.service,
    required this.onTap,
  });
  final HealthService service;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: service.title.replaceAll('\n', ' '),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .94),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xffb6d5de), width: .8),
              ),
              padding: const EdgeInsets.all(10),
              child: Image.asset(
                service.asset,
                cacheWidth: 192,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              service.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: Color(0xff125bb5),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class HealthPromotionBanner extends StatelessWidget {
  const HealthPromotionBanner({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.light,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        const Expanded(flex: 2, child: DoctorIllustrationPlaceholder()),
        const SizedBox(width: 16),
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chủ động phòng bệnh\nbảo vệ sức khỏe gia đình bạn',
                style: TextStyle(
                  fontSize: 18,
                  height: 1.35,
                  color: AppColors.dark,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onTap,
                child: const Text('Tìm hiểu ngay'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Placeholder minh họa bác sĩ, không phải ảnh bác sĩ thực tế.
class DoctorIllustrationPlaceholder extends StatelessWidget {
  const DoctorIllustrationPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xffffddc5),
          borderRadius: BorderRadius.circular(30),
          border: const Border(
            top: BorderSide(color: AppColors.dark, width: 9),
          ),
        ),
        child: const Icon(Icons.face, size: 45, color: AppColors.dark),
      ),
      Container(
        width: 100,
        height: 85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(34),
            bottom: Radius.circular(12),
          ),
          border: Border.all(color: const Color(0xffd5e8fa)),
        ),
        child: const Icon(
          Icons.medical_services_outlined,
          color: AppColors.primary,
          size: 38,
        ),
      ),
    ],
  );
}

class LatestAnnouncements extends StatelessWidget {
  const LatestAnnouncements({
    super.key,
    required this.onAll,
    required this.onSelected,
    this.showHeading = true,
  });
  final VoidCallback onAll;
  final ValueChanged<Announcement> onSelected;
  final bool showHeading;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (showHeading)
        Row(
          children: [
            const Expanded(
              child: Text(
                'Thông báo mới',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(onPressed: onAll, child: const Text('Xem tất cả')),
          ],
        ),
      const Text(
        'Nội dung minh họa',
        style: TextStyle(fontSize: 11, color: AppColors.muted),
      ),
      const SizedBox(height: 12),
      Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < demoAnnouncements.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
              InkWell(
                onTap: () => onSelected(demoAnnouncements[i]),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 68,
                        decoration: BoxDecoration(
                          color: demoAnnouncements[i].color.withValues(
                            alpha: .12,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          demoAnnouncements[i].icon,
                          color: demoAnnouncements[i].color,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              demoAnnouncements[i].title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              demoAnnouncements[i].date,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.muted,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

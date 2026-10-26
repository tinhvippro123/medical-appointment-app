import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class CenterInformation extends StatelessWidget {
  const CenterInformation({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 24, 14, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Thông tin trung tâm',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xffdfedf8)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: .04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 23,
                    backgroundColor: AppColors.light,
                    child: Icon(
                      Icons.local_hospital_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trung tâm y tế',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'XÃ HIỆP PHƯỚC',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.dark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1, color: Color(0xffeaf1f8)),
              ),
              const _InformationRow(
                icon: Icons.schedule_rounded,
                title: 'Giờ làm việc',
              ),
              const SizedBox(height: 18),
              const _InformationRow(
                icon: Icons.location_on_outlined,
                title: 'Địa chỉ',
              ),
              const SizedBox(height: 18),
              const _InformationRow(
                icon: Icons.phone_outlined,
                title: 'Số điện thoại',
              ),
              const SizedBox(height: 18),
              const Text(
                'Thông tin liên hệ chính thức sẽ được cập nhật tại đây.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({required this.icon, required this.title});
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.light,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 21, color: AppColors.primary),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              'Đang cập nhật',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    ],
  );
}

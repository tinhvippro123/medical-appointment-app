import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/doctor.dart';

class DoctorSearchCard extends StatelessWidget {
  const DoctorSearchCard({
    super.key,
    required this.doctor,
    this.imageUrl,
    required this.onTap,
  });

  final Doctor doctor;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xffe2e8f0)),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 72,
                  height: 72,
                  color: AppColors.light,
                  child: imageUrl != null && imageUrl!.isNotEmpty
                      ? Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.person_rounded,
                            size: 38,
                            color: AppColors.primary,
                          ),
                        )
                      : const Icon(
                          Icons.person_rounded,
                          size: 38,
                          color: AppColors.primary,
                        ),
                ),
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tên & Học vị bác sĩ
                    Text(
                      doctor.qualification != null && doctor.qualification!.trim().isNotEmpty
                          ? '${doctor.qualification!.trim()} ${doctor.fullName}'
                          : 'BS. ${doctor.fullName}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),

                    // Chuyên khoa
                    Row(
                      children: [
                        const Icon(
                          Icons.medical_services_outlined,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            doctor.departmentName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.muted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Năm kinh nghiệm nếu có
                    if (doctor.experienceYears > 0) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.workspace_premium_outlined,
                            size: 14,
                            color: Color(0xfff59e0b),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${doctor.experienceYears} năm kinh nghiệm',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],

                    // Phí khám
                    Row(
                      children: [
                        const Icon(
                          Icons.payments_outlined,
                          size: 14,
                          color: Color(0xff10b981),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          doctor.feeFormatted,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff0f766e),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Padding(
                padding: EdgeInsets.only(top: 24, left: 4),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.muted,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

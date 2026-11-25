import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/doctor.dart';

/// Thẻ tóm tắt thông tin bác sĩ ở đầu màn hình chọn ngày giờ khám
class BookingDoctorSummary extends StatelessWidget {
  const BookingDoctorSummary({
    super.key,
    required this.doctor,
    this.imageUrl,
  });

  final Doctor doctor;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final doctorTitle =
        doctor.qualification != null && doctor.qualification!.trim().isNotEmpty
            ? '${doctor.qualification!.trim()} ${doctor.fullName}'
            : 'BS. ${doctor.fullName}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 60,
              height: 60,
              color: AppColors.light,
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.person_rounded,
                        size: 36,
                        color: AppColors.primary,
                      ),
                    )
                  : const Icon(
                      Icons.person_rounded,
                      size: 36,
                      color: AppColors.primary,
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctorTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  doctor.departmentName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        doctor.roomDetailDisplay,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    const Text(
                      ' • ',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
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
        ],
      ),
    );
  }
}

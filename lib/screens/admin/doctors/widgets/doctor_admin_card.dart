import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/doctor.dart';

class DoctorAdminCard extends StatelessWidget {
  const DoctorAdminCard({
    super.key,
    required this.doctor,
    required this.imageUrl,
    required this.onTap,
    required this.onDelete,
    this.onSchedule,
  });

  final Doctor doctor;
  final String? imageUrl;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onSchedule;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Ảnh đại diện
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 68,
                      height: 68,
                      color: AppColors.light,
                      child: imageUrl != null && imageUrl!.isNotEmpty
                          ? Image.network(
                              imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(
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

                  // 2. Thông tin chính
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                doctor.fullName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (doctor.qualification != null &&
                                doctor.qualification!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.light,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  doctor.qualification!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Chuyên khoa
                        Row(
                          children: [
                            const Icon(
                              Icons.local_hospital_outlined,
                              size: 15,
                              color: AppColors.muted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                doctor.departmentName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.text,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Phòng khám
                        Row(
                          children: [
                            const Icon(
                              Icons.meeting_room_outlined,
                              size: 15,
                              color: AppColors.muted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                doctor.roomDisplay,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: doctor.roomId != null
                                      ? AppColors.muted
                                      : Colors.amber.shade800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 0.8),
              const SizedBox(height: 10),

              // 3. Phí khám, kinh nghiệm và các nút thao tác
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doctor.feeFormatted,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          '${doctor.experienceYears} năm kinh nghiệm',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Nút Lịch làm việc
                      OutlinedButton.icon(
                        key: ValueKey('schedule-doctor-${doctor.id}'),
                        onPressed: onSchedule,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: BorderSide(color: Colors.blue.shade200),
                        ),
                        icon: const Icon(
                          Icons.calendar_month_outlined,
                          size: 15,
                          color: AppColors.primary,
                        ),
                        label: const Text(
                          'Lịch làm việc',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Nút xóa
                      IconButton(
                        key: ValueKey('delete-doctor-${doctor.id}'),
                        onPressed: onDelete,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        tooltip: 'Xóa bác sĩ',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

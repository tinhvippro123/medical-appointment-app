import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/doctor.dart';

class RelatedDoctorCard extends StatelessWidget {
  const RelatedDoctorCard({
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
    final displayName = doctor.qualification != null &&
            doctor.qualification!.trim().isNotEmpty
        ? '${doctor.qualification!.trim()} ${doctor.fullName}'
        : 'BS. ${doctor.fullName}';

    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 64,
                    height: 64,
                    color: AppColors.light,
                    child: imageUrl != null && imageUrl!.isNotEmpty
                        ? Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
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
                const SizedBox(height: 8),

                Text(
                  displayName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                    height: 1.2,
                  ),
                ),
                const Spacer(),

                if (doctor.experienceYears > 0)
                  Text(
                    '${doctor.experienceYears} năm KN',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 3),

                Text(
                  doctor.feeFormatted,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff0f766e),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/patient_profile.dart';

/// Thành phần chọn hồ sơ bệnh nhân gọn (dropdown) trong màn đặt lịch khám.
class BookingPatientProfileSection extends StatelessWidget {
  const BookingPatientProfileSection({
    super.key,
    required this.isLoading,
    required this.requiresLogin,
    required this.profiles,
    required this.selectedProfileId,
    required this.onChanged,
    required this.onRetry,
    required this.onLogin,
    this.errorMessage,
    this.enabled = true,
  });

  final bool isLoading;
  final bool requiresLogin;
  final List<PatientProfile> profiles;
  final int? selectedProfileId;
  final ValueChanged<int?> onChanged;
  final VoidCallback onRetry;
  final VoidCallback onLogin;
  final String? errorMessage;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.badge_outlined, size: 20, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Hồ sơ bệnh nhân',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text(
                  'Đang tải danh sách hồ sơ...',
                  style: TextStyle(fontSize: 14, color: AppColors.muted),
                ),
              ],
            )
          else if (requiresLogin)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.light,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Vui lòng đăng nhập để chọn hồ sơ bệnh nhân khi đặt lịch.',
                      style: TextStyle(fontSize: 13, color: AppColors.text),
                    ),
                  ),
                  TextButton(
                    onPressed: enabled ? onLogin : null,
                    child: const Text('Đăng nhập'),
                  ),
                ],
              ),
            )
          else if (errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xfffef2f2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xfffecaca)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 20,
                    color: Color(0xffef4444),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xffb91c1c),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: enabled ? onRetry : null,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            )
          else if (profiles.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xfffffbeb),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xfffde68a)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: Color(0xffd97706),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bạn chưa có hồ sơ bệnh nhân. Hãy tạo hồ sơ trước khi đặt lịch.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xff92400e),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            DropdownButtonFormField<int>(
              key: const ValueKey('booking-profile-dropdown'),
              initialValue: selectedProfileId,
              isExpanded: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              items: profiles
                  .map(
                    (profile) => DropdownMenuItem<int>(
                      value: profile.id,
                      child: Text(
                        profile.displayLabel,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: enabled ? onChanged : null,
            ),
        ],
      ),
    );
  }
}

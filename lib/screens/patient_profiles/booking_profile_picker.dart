import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/patient_profile.dart';

class BookingProfilePicker extends StatelessWidget {
  const BookingProfilePicker({
    super.key,
    required this.profiles,
    required this.selectedId,
    required this.onAdd,
    required this.onSelect,
    required this.onOpen,
    this.status,
  });

  final List<PatientProfile> profiles;
  final int? selectedId;
  final VoidCallback? onAdd;
  final ValueChanged<PatientProfile> onSelect;
  final ValueChanged<PatientProfile> onOpen;
  final Widget? status;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Chọn hồ sơ',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Thêm hồ sơ mới'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (status != null)
              status!
            else if (profiles.isEmpty)
              const Text('Bạn chưa có hồ sơ bệnh nhân.')
            else ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final profile in profiles)
                      _ProfileAvatar(
                        profile: profile,
                        selected: selectedId == profile.id,
                        onTap: () => onSelect(profile),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (final profile in profiles)
                _ProfileTile(
                  profile: profile,
                  selected: selectedId == profile.id,
                  onTap: () => onOpen(profile),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  final PatientProfile profile;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = profile.fullName.trim();
    final shortName = name.isEmpty ? 'Hồ sơ' : name.split(' ').last;
    return Semantics(
      selected: selected,
      label: profile.fullName,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 88,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: selected
                      ? AppColors.primary
                      : AppColors.light,
                  child: CircleAvatar(
                    radius: 25,
                    backgroundColor: selected ? AppColors.light : Colors.white,
                    foregroundColor: AppColors.dark,
                    child: const Icon(Icons.person_outline, size: 27),
                  ),
                ),
                const SizedBox(height: 6),
                Text(shortName, maxLines: 2, textAlign: TextAlign.center),
                Text(
                  '#${profile.id}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  final PatientProfile profile;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final phone = profile.phone?.trim() ?? '';
    final maskedPhone = phone.length > 6
        ? '${phone.substring(0, 3)}****${phone.substring(phone.length - 3)}'
        : '****';
    final isSelf = profile.relationship.trim().toLowerCase() == 'bản thân';

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? AppColors.primary : const Color(0xffdce9f5),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: const CircleAvatar(
          backgroundColor: AppColors.light,
          foregroundColor: AppColors.dark,
          child: Icon(Icons.badge_outlined),
        ),
        title: Text(
          profile.fullName.isEmpty ? 'Hồ sơ #${profile.id}' : profile.fullName,
          style: const TextStyle(
            color: AppColors.dark,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              Text('Mã hồ sơ #${profile.id}'),
              if (phone.isNotEmpty) Text(maskedPhone),
              if (profile.relationship.isNotEmpty)
                Text(
                  isSelf ? 'Tôi' : profile.relationship,
                  style: const TextStyle(color: AppColors.dark),
                ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.dark),
        onTap: onTap,
      ),
    );
  }
}

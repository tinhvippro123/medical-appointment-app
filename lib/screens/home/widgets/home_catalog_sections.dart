import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/department.dart';
import '../../../models/doctor.dart';
import '../../../models/order.dart';
import '../../../repositories/department_repository.dart';
import '../../../repositories/doctor_repository.dart';

class HomeCatalogSections extends StatefulWidget {
  const HomeCatalogSections({
    super.key,
    this.departmentRepository,
    this.doctorRepository,
  });

  final DepartmentRepository? departmentRepository;
  final DoctorRepository? doctorRepository;

  @override
  State<HomeCatalogSections> createState() => _HomeCatalogSectionsState();
}

class _HomeCatalogSectionsState extends State<HomeCatalogSections> {
  static const int _doctorPageSize = 4;

  late final DepartmentRepository _departmentRepo =
      widget.departmentRepository ?? DepartmentRepository();
  late final DoctorRepository _doctorRepo =
      widget.doctorRepository ?? DoctorRepository();

  List<Department> _departments = const [];
  bool _loadingDepartments = true;
  bool _departmentsFailed = false;

  List<Doctor> _doctors = const [];
  bool _loadingDoctors = true;
  bool _loadingMoreDoctors = false;
  bool _doctorsFailed = false;
  int _doctorPage = 1;
  int _doctorTotalCount = 0;
  bool _hasMoreDoctors = false;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
    _loadDoctors(reset: true);
  }

  Future<void> _loadDepartments() async {
    setState(() {
      _loadingDepartments = true;
      _departmentsFailed = false;
    });
    try {
      final list = await _departmentRepo.list();
      if (!mounted) return;
      setState(() {
        _departments = list;
        _loadingDepartments = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingDepartments = false;
        _departmentsFailed = true;
      });
    }
  }

  Future<void> _loadDoctors({required bool reset}) async {
    if (!reset && (_loadingDoctors || _loadingMoreDoctors || !_hasMoreDoctors)) {
      return;
    }

    final targetPage = reset ? 1 : _doctorPage + 1;
    setState(() {
      if (reset) {
        _loadingDoctors = true;
        _doctorsFailed = false;
      } else {
        _loadingMoreDoctors = true;
      }
    });

    try {
      final paged = await _doctorRepo.getDoctors(
        page: targetPage,
        pageSize: _doctorPageSize,
      );
      if (!mounted) return;
      setState(() {
        _doctorPage = paged.page;
        _doctorTotalCount = paged.totalCount;
        _hasMoreDoctors = paged.hasNextPage;
        _doctors = reset ? paged.items : [..._doctors, ...paged.items];
        _loadingDoctors = false;
        _loadingMoreDoctors = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (reset) {
          _doctorsFailed = true;
        }
        _loadingDoctors = false;
        _loadingMoreDoctors = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 24, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            title: 'Chuyên khoa khám',
            actionLabel: 'Xem tất cả',
            onAction: () => Navigator.of(context).pushNamed('/departments'),
          ),
          const SizedBox(height: 12),
          _buildDepartmentsBody(),
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Đội ngũ bác sĩ mới',
            actionLabel: 'Xem tất cả',
            onAction: () => Navigator.of(context).pushNamed('/doctors'),
          ),
          const SizedBox(height: 12),
          _buildDoctorsBody(),
        ],
      ),
    );
  }

  Widget _buildDepartmentsBody() {
    if (_loadingDepartments) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      );
    }

    if (_departmentsFailed) {
      return _CompactRetryCard(
        message: 'Chưa tải được danh sách chuyên khoa.',
        onRetry: _loadDepartments,
      );
    }

    if (_departments.isEmpty) {
      return const _CompactEmptyCard(message: 'Hiện chưa có chuyên khoa nào.');
    }

    return SingleChildScrollView(
      key: const ValueKey('home-departments-strip'),
      scrollDirection: Axis.horizontal,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < _departments.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              _HomeDepartmentCard(
                department: _departments[i],
                imageUrl: _departmentRepo.imageUrl(_departments[i].imageUrl),
                onTap: () => Navigator.of(
                  context,
                ).pushNamed('/doctors', arguments: _departments[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorsBody() {
    if (_loadingDoctors) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      );
    }

    if (_doctorsFailed && _doctors.isEmpty) {
      return _CompactRetryCard(
        message: 'Chưa tải được danh sách bác sĩ mới nhất.',
        onRetry: () => _loadDoctors(reset: true),
      );
    }

    if (_doctors.isEmpty) {
      return const _CompactEmptyCard(message: 'Hiện chưa có bác sĩ nào.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _doctors.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _HomeDoctorCard(
            doctor: _doctors[i],
            imageUrl: _doctorRepo.imageUrl(_doctors[i].avatarUrl),
            onTap: () => Navigator.of(
              context,
            ).pushNamed('/doctors/detail', arguments: _doctors[i].id),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Hiển thị ${_doctors.length} / $_doctorTotalCount bác sĩ',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        if (_hasMoreDoctors) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const ValueKey('home-doctors-load-more-btn'),
            onPressed: _loadingMoreDoctors
                ? null
                : () => _loadDoctors(reset: false),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: Color(0xffbfdbfe)),
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: _loadingMoreDoctors
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.expand_more_rounded, size: 20),
            label: Text(
              _loadingMoreDoctors ? 'Đang tải thêm...' : 'Xem thêm bác sĩ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            actionLabel,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _HomeDepartmentCard extends StatelessWidget {
  const _HomeDepartmentCard({
    required this.department,
    required this.imageUrl,
    required this.onTap,
  });

  final Department department;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fee = department.consultationFee;
    return SizedBox(
      width: 154,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('home-department-card-${department.id}'),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xffdfedf8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 68,
                    width: double.infinity,
                    color: AppColors.light,
                    child: imageUrl == null
                        ? const Icon(
                            Icons.local_hospital_outlined,
                            color: AppColors.primary,
                            size: 28,
                          )
                        : Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            excludeFromSemantics: true,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.local_hospital_outlined,
                              color: AppColors.primary,
                              size: 28,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  department.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                if (fee != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    Order.formatMoney(fee),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeDoctorCard extends StatelessWidget {
  const _HomeDoctorCard({
    required this.doctor,
    required this.imageUrl,
    required this.onTap,
  });

  final Doctor doctor;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayTitle =
        doctor.qualification != null && doctor.qualification!.trim().isNotEmpty
        ? '${doctor.qualification!.trim()} ${doctor.fullName}'
        : doctor.fullName;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('home-doctor-card-${doctor.id}'),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xffdfedf8)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 60,
                  height: 60,
                  color: AppColors.light,
                  child: imageUrl == null
                      ? const Icon(
                          Icons.person_rounded,
                          color: AppColors.primary,
                          size: 32,
                        )
                      : Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          excludeFromSemantics: true,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.person_rounded,
                            color: AppColors.primary,
                            size: 32,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      doctor.departmentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
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
                            '${doctor.experienceYears} năm KN',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        Text(
                          doctor.feeFormatted,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.dark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.muted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactRetryCard extends StatelessWidget {
  const _CompactRetryCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffdfedf8)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          Text(
            message,
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Tải lại'),
          ),
        ],
      ),
    );
  }
}

class _CompactEmptyCard extends StatelessWidget {
  const _CompactEmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffdfedf8)),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 13, color: AppColors.muted),
      ),
    );
  }
}

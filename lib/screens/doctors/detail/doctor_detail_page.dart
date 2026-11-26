import 'package:flutter/material.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../helpers/session_helper.dart';
import '../../../models/doctor.dart';
import '../../../models/doctor_day_off.dart';
import '../../../models/patient_profile.dart';
import '../../../repositories/doctor_repository.dart';
import '../../auth/login_page.dart';
import '../../booking/booking_logic.dart';
import '../../booking/booking_page.dart';
import 'widgets/related_doctor_card.dart';

/// Màn hình Chi tiết bác sĩ + Bác sĩ liên quan
class DoctorDetailPage extends StatefulWidget {
  const DoctorDetailPage({
    super.key,
    this.doctorId,
    this.repository,
    this.patient,
  });

  final int? doctorId;
  final DoctorRepository? repository;
  final PatientProfile? patient;

  @override
  State<DoctorDetailPage> createState() => _DoctorDetailPageState();
}

class _DoctorDetailPageState extends State<DoctorDetailPage> {
  late final DoctorRepository _repository;
  int? _doctorId;
  bool _initialized = false;

  int _currentRequestId = 0;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isNotFound = false;
  Doctor? _doctor;
  List<DoctorDayOff> _dayOffs = [];
  bool _loadingDayOffs = true;
  bool _dayOffsFailed = false;

  bool _isLoadingRelated = false;
  bool _isLoadingMoreRelated = false;
  String? _relatedErrorMessage;
  int _relatedPage = 1;
  bool _hasMoreRelated = false;
  List<Doctor> _relatedDoctors = [];
  final ScrollController _relatedScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? DoctorRepository();
    if (widget.doctorId != null) {
      _doctorId = widget.doctorId;
    }
    _relatedScrollController.addListener(_onRelatedScroll);
  }

  @override
  void dispose() {
    _relatedScrollController.removeListener(_onRelatedScroll);
    _relatedScrollController.dispose();
    super.dispose();
  }

  void _onRelatedScroll() {
    if (!_relatedScrollController.hasClients) return;
    if (_relatedScrollController.position.pixels >=
        _relatedScrollController.position.maxScrollExtent - 120) {
      _loadMoreRelatedDoctors();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      if (_doctorId == null) {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is int) {
          _doctorId = args;
        } else if (args is String) {
          _doctorId = int.tryParse(args);
        } else if (args is Doctor) {
          _doctorId = args.id;
        }
      }

      if (_doctorId != null) {
        _loadDoctorDetail();
      } else {
        setState(() {
          _isLoading = false;
          _isNotFound = true;
        });
      }
    }
  }

  Future<void> _loadDoctorDetail() async {
    if (_doctorId == null) return;
    final requestId = ++_currentRequestId;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isNotFound = false;
    });

    try {
      final doc = await _repository.getDoctorById(_doctorId!);
      if (!mounted || requestId != _currentRequestId) return;
      setState(() {
        _doctor = doc;
        _isLoading = false;
      });

      // Tải tiếp danh sách bác sĩ liên quan cùng khoa
      _loadRelatedDoctors(requestId);
      _loadDayOffs(requestId);
    } on ApiException catch (e) {
      if (!mounted || requestId != _currentRequestId) return;
      setState(() {
        _isLoading = false;
        if (e.statusCode == 404 || e.errorCode == 'DOCTOR_NOT_FOUND') {
          _isNotFound = true;
        } else {
          _errorMessage = e.displayMessage;
        }
      });
    } catch (_) {
      if (!mounted || requestId != _currentRequestId) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Đã có lỗi xảy ra. Vui lòng thử lại.';
      });
    }
  }

  Future<void> _loadDayOffs(int requestId) async {
    final doctorId = _doctorId;
    if (doctorId == null) return;
    setState(() {
      _loadingDayOffs = true;
      _dayOffsFailed = false;
    });

    final today = normalizeDateOnly(vietnamNow());
    try {
      final days = await _repository.getDoctorDayOffs(
        doctorId,
        from: today,
        to: today.add(const Duration(days: 60)),
      );
      if (!mounted || requestId != _currentRequestId) return;
      setState(() {
        _dayOffs = days;
        _loadingDayOffs = false;
      });
    } catch (_) {
      if (!mounted || requestId != _currentRequestId) return;
      setState(() {
        _dayOffsFailed = true;
        _loadingDayOffs = false;
      });
    }
  }

  Future<void> _loadRelatedDoctors(int requestId) async {
    if (_doctorId == null) return;

    setState(() {
      _isLoadingRelated = true;
      _isLoadingMoreRelated = false;
      _relatedErrorMessage = null;
      _relatedPage = 1;
      _hasMoreRelated = false;
    });

    try {
      final result = await _repository.getRelatedDoctors(
        _doctorId!,
        page: 1,
        pageSize: 5,
      );
      if (!mounted || requestId != _currentRequestId) return;
      setState(() {
        _relatedDoctors = result.items;
        _relatedPage = result.page;
        _hasMoreRelated = result.hasNextPage;
        _isLoadingRelated = false;
      });
    } catch (_) {
      if (!mounted || requestId != _currentRequestId) return;
      setState(() {
        _isLoadingRelated = false;
        _relatedErrorMessage = 'Không thể tải bác sĩ liên quan';
      });
    }
  }

  Future<void> _loadMoreRelatedDoctors() async {
    if (_doctorId == null ||
        _isLoadingRelated ||
        _isLoadingMoreRelated ||
        !_hasMoreRelated) {
      return;
    }
    final requestId = _currentRequestId;
    setState(() => _isLoadingMoreRelated = true);

    try {
      final result = await _repository.getRelatedDoctors(
        _doctorId!,
        page: _relatedPage + 1,
        pageSize: 5,
      );
      if (!mounted || requestId != _currentRequestId) return;
      setState(() {
        _relatedDoctors = [..._relatedDoctors, ...result.items];
        _relatedPage = result.page;
        _hasMoreRelated = result.hasNextPage;
        _isLoadingMoreRelated = false;
      });
    } catch (_) {
      if (!mounted || requestId != _currentRequestId) return;
      setState(() => _isLoadingMoreRelated = false);
    }
  }

  Future<void> _handleBooking() async {
    if (_doctor == null) return;

    final isLoggedIn = await SessionHepler.isLoggedIn();
    if (!mounted) return;

    if (!isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để đặt lịch khám')),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      return;
    }

    try {
      final navigator = Navigator.of(context);
      final patient = widget.patient;
      if (patient == null) {
        await navigator.pushNamed('/booking', arguments: _doctor!.id);
      } else {
        final doctorId = _doctor!.id;
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => BookingPage(doctorId: doctorId, patient: patient),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chức năng đang phát triển')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết bác sĩ'),
        elevation: 0,
      ),
      body: _buildBody(),
      bottomNavigationBar: _doctor != null ? _buildBottomBar() : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_isNotFound) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_off_rounded,
                size: 64,
                color: AppColors.muted,
              ),
              const SizedBox(height: 16),
              const Text(
                'Không tìm thấy thông tin bác sĩ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Bác sĩ không tồn tại hoặc đã ngừng hoạt động trong hệ thống.',
                style: TextStyle(fontSize: 14, color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Quay lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 60,
                color: Color(0xffef4444),
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _loadDoctorDetail,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    final doctor = _doctor!;
    final doctorTitle = doctor.qualification != null &&
            doctor.qualification!.trim().isNotEmpty
        ? '${doctor.qualification!.trim()} ${doctor.fullName}'
        : 'BS. ${doctor.fullName}';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(doctor, doctorTitle),
          const SizedBox(height: 20),
          _buildInfoSection(doctor),
          const SizedBox(height: 16),
          _buildRoomSection(doctor),
          const SizedBox(height: 16),
          _buildScheduleSection(doctor),
          const SizedBox(height: 16),
          _buildDayOffsSection(),
          const SizedBox(height: 20),
          _buildRelatedSection(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeader(Doctor doctor, String doctorTitle) {
    final avatarUrl = _repository.imageUrl(doctor.avatarUrl);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 90,
              height: 90,
              color: AppColors.light,
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.person_rounded,
                        size: 54,
                        color: AppColors.primary,
                      ),
                    )
                  : const Icon(
                      Icons.person_rounded,
                      size: 54,
                      color: AppColors.primary,
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctorTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.light,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    doctor.departmentName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(Doctor doctor) {
    return _buildCardWrapper(
      title: 'Thông tin bác sĩ',
      icon: Icons.badge_outlined,
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.medical_services_outlined,
            label: 'Chuyên khoa',
            value: doctor.departmentName,
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.workspace_premium_outlined,
            label: 'Kinh nghiệm',
            value: doctor.experienceYears > 0
                ? '${doctor.experienceYears} năm'
                : 'Chưa cập nhật',
            iconColor: const Color(0xfff59e0b),
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.payments_outlined,
            label: 'Phí khám',
            value: doctor.feeFormatted,
            valueColor: const Color(0xff0f766e),
            valueBold: true,
            iconColor: const Color(0xff10b981),
          ),
          if (doctor.phone != null && doctor.phone!.trim().isNotEmpty) ...[
            _buildDivider(),
            _buildInfoRow(
              icon: Icons.phone_outlined,
              label: 'Số điện thoại',
              value: doctor.phone!.trim(),
            ),
          ],
          if (doctor.email != null && doctor.email!.trim().isNotEmpty) ...[
            _buildDivider(),
            _buildInfoRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: doctor.email!.trim(),
            ),
          ],
          if (doctor.description != null &&
              doctor.description!.trim().isNotEmpty) ...[
            _buildDivider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Giới thiệu:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    doctor.description!.trim(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.text,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoomSection(Doctor doctor) {
    return _buildCardWrapper(
      title: 'Phòng khám',
      icon: Icons.meeting_room_outlined,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.light,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.domain_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              doctor.roomDetailDisplay,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: doctor.roomNumber != null &&
                        doctor.roomNumber!.trim().isNotEmpty
                    ? AppColors.text
                    : AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSection(Doctor doctor) {
    final grouped = doctor.groupedSchedules;

    return _buildCardWrapper(
      title: 'Lịch làm việc',
      icon: Icons.calendar_today_outlined,
      child: grouped.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Chưa có lịch làm việc',
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: AppColors.muted,
                ),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < grouped.length; i++) ...[
                  if (i > 0) _buildDivider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 85,
                          child: Text(
                            grouped[i].dayName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            grouped[i].timeSlotsDisplay,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildDayOffsSection() => _buildCardWrapper(
    title: 'Lịch nghỉ sắp tới',
    icon: Icons.event_busy_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_loadingDayOffs)
          const Text('Đang tải lịch nghỉ…')
        else if (_dayOffsFailed) ...[
          const Text('Không tải được lịch nghỉ.'),
          TextButton(
            onPressed: () => _loadDayOffs(_currentRequestId),
            child: const Text('Thử lại lịch nghỉ'),
          ),
        ] else if (_dayOffs.isEmpty)
          const Text('Chưa có lịch nghỉ trong 60 ngày tới.')
        else
          for (final day in _dayOffs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Text('${day.dayOfWeekLabel} · ${day.dateDisplay}'),
            ),
      ],
    ),
  );

  Widget _buildRelatedSection() {
    // Ẩn hoàn toàn section nếu danh sách rỗng và không có lỗi, không đang tải
    if (_relatedDoctors.isEmpty &&
        !_isLoadingRelated &&
        _relatedErrorMessage == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Bác sĩ liên quan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ),
            if (_hasMoreRelated)
              TextButton(
                key: const ValueKey('related-doctors-load-more-btn'),
                onPressed: _isLoadingMoreRelated
                    ? null
                    : _loadMoreRelatedDoctors,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _isLoadingMoreRelated ? 'Đang tải...' : 'Xem thêm',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingRelated)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_relatedErrorMessage != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xfffecaca)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xffef4444),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _relatedErrorMessage!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xffb91c1c),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _loadRelatedDoctors(_currentRequestId),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 175,
            child: ListView.separated(
              controller: _relatedScrollController,
              scrollDirection: Axis.horizontal,
              itemCount: _relatedDoctors.length + (_hasMoreRelated ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                if (index >= _relatedDoctors.length) {
                  return InkWell(
                    onTap: _isLoadingMoreRelated
                        ? null
                        : _loadMoreRelatedDoctors,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xffdfedf8)),
                      ),
                      child: Center(
                        child: _isLoadingMoreRelated
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    color: AppColors.primary,
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Tải thêm',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  );
                }
                final rel = _relatedDoctors[index];
                return RelatedDoctorCard(
                  doctor: rel,
                  imageUrl: _repository.imageUrl(rel.avatarUrl),
                  onTap: () {
                    final navigator = Navigator.of(context);
                    final patient = widget.patient;
                    if (patient == null) {
                      navigator.pushReplacementNamed(
                        '/doctors/detail',
                        arguments: rel.id,
                      );
                    } else {
                      navigator.pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => DoctorDetailPage(
                            doctorId: rel.id,
                            patient: patient,
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0d000000),
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
        border: Border(top: BorderSide(color: Color(0xffe2e8f0))),
      ),
      child: FilledButton.icon(
        onPressed: _handleBooking,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.calendar_month_rounded, size: 20),
        label: const Text(
          'Đặt lịch khám',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildCardWrapper({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
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
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? iconColor,
    Color? valueColor,
    bool valueBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor ?? AppColors.muted),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: valueColor ?? AppColors.text,
              fontWeight: valueBold ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Divider(height: 1, thickness: 1, color: Color(0xfff1f5f9)),
    );
  }
}

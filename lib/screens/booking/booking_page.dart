import 'package:flutter/material.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../helpers/session_helper.dart';
import '../../models/doctor.dart';
import '../../models/patient_profile.dart';
import '../../repositories/cart_repository.dart';
import '../../repositories/doctor_repository.dart';
import '../../repositories/patient_profile_repository.dart';
import '../auth/login_page.dart';
import 'booking_logic.dart';
import 'widgets/booking_doctor_summary.dart';
import 'widgets/booking_patient_profile_section.dart';
import 'widgets/booking_slot_grid.dart';

/// Màn hình Chọn ngày giờ đặt khám cho bệnh nhân.
class BookingPage extends StatefulWidget {
  const BookingPage({
    super.key,
    this.doctorId,
    this.patient,
    this.doctorRepository,
    this.cartRepository,
    this.patientProfileRepository,
    this.nowProvider,
    this.isLoggedIn,
  });

  final int? doctorId;
  final PatientProfile? patient;
  final DoctorRepository? doctorRepository;
  final CartRepository? cartRepository;
  final PatientProfileRepository? patientProfileRepository;
  final DateTime Function()? nowProvider;
  final Future<bool> Function()? isLoggedIn;

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  late final DoctorRepository _doctorRepository;
  late final CartRepository _cartRepository;
  late final PatientProfileRepository _patientProfileRepository;
  final TextEditingController _noteController = TextEditingController();

  int? _doctorId;
  bool _initialized = false;
  int _currentRequestId = 0;

  bool _isLoading = true;
  bool _isNotFound = false;
  String? _errorMessage;
  Doctor? _doctor;

  DateTime _firstDate = normalizeDateOnly(vietnamNow());
  DateTime _lastDate = normalizeDateOnly(
    vietnamNow(),
  ).add(const Duration(days: 60));
  Set<DateTime> _dayOffDates = const {};
  String? _dayOffWarning;
  DateTime? _firstSelectableDate;
  DateTime? _selectedDate;
  String? _selectedSlot;

  bool _isLoadingProfiles = false;
  bool _requiresLogin = false;
  String? _profilesError;
  List<PatientProfile> _profiles = const [];
  int? _selectedProfileId;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _doctorRepository = widget.doctorRepository ?? DoctorRepository();
    _cartRepository = widget.cartRepository ?? CartRepository();
    _patientProfileRepository =
        widget.patientProfileRepository ?? PatientProfileRepository();
    if (widget.doctorId != null) {
      _doctorId = widget.doctorId;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
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

    if (_doctorId != null && _doctorId! > 0) {
      _loadBookingData();
    } else {
      setState(() {
        _isLoading = false;
        _isNotFound = true;
      });
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  DateTime _currentNow() => vietnamNow(widget.nowProvider?.call());

  Future<bool> _checkLoggedIn() =>
      (widget.isLoggedIn ?? SessionHepler.isLoggedIn)();

  Future<void> _loadBookingData() async {
    if (_doctorId == null) return;
    final requestId = ++_currentRequestId;

    setState(() {
      _isLoading = true;
      _isNotFound = false;
      _errorMessage = null;
      _dayOffWarning = null;
    });

    try {
      final doctor = await _doctorRepository.getDoctorById(_doctorId!);
      if (!mounted || requestId != _currentRequestId) return;

      final nowVn = _currentNow();
      final firstDate = normalizeDateOnly(nowVn);
      final lastDate = DateTime(
        firstDate.year,
        firstDate.month,
        firstDate.day + 60,
      );

      var dayOffDates = <DateTime>{};
      String? dayOffWarning;

      if (doctor.schedules.isNotEmpty) {
        try {
          final dayOffs = await _doctorRepository.getDoctorDayOffs(
            doctor.id,
            from: firstDate,
            to: lastDate,
          );
          dayOffDates = dayOffs.map((e) => e.dateOnly).toSet();
        } catch (_) {
          dayOffWarning =
              'Không tải được ngày nghỉ của bác sĩ. Vui lòng kiểm tra lại khi đặt.';
        }
      }

      if (!mounted || requestId != _currentRequestId) return;

      final firstSelectable = findFirstSelectableDate(
        schedules: doctor.schedules,
        dayOffDates: dayOffDates,
        firstDate: firstDate,
        lastDate: lastDate,
      );

      setState(() {
        _doctor = doctor;
        _firstDate = firstDate;
        _lastDate = lastDate;
        _dayOffDates = dayOffDates;
        _dayOffWarning = dayOffWarning;
        _firstSelectableDate = firstSelectable;
        _selectedDate = firstSelectable;
        _selectedSlot = null;
        _isLoading = false;
      });

      _loadProfiles(requestId: requestId);
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

  Future<void> _loadProfiles({int? requestId}) async {
    final activeRequestId = requestId ?? _currentRequestId;

    setState(() {
      _isLoadingProfiles = true;
      _profilesError = null;
      _requiresLogin = false;
    });

    final loggedIn = await _checkLoggedIn();
    if (!mounted || activeRequestId != _currentRequestId) return;

    if (!loggedIn) {
      setState(() {
        _isLoadingProfiles = false;
        _requiresLogin = true;
        _profiles = const [];
        _selectedProfileId = null;
      });
      return;
    }

    try {
      final fetched = await _patientProfileRepository.getProfiles();
      if (!mounted || activeRequestId != _currentRequestId) return;

      final list = List<PatientProfile>.from(fetched);
      final preferredPatient = widget.patient;
      if (preferredPatient != null &&
          !list.any((p) => p.id == preferredPatient.id)) {
        list.insert(0, preferredPatient);
      }

      setState(() {
        _profiles = list;
        _isLoadingProfiles = false;
        _requiresLogin = false;
        if (preferredPatient != null) {
          _selectedProfileId = preferredPatient.id;
        } else if (list.isEmpty) {
          _selectedProfileId = null;
        } else if (_selectedProfileId == null ||
            !list.any((p) => p.id == _selectedProfileId)) {
          _selectedProfileId = list.first.id;
        }
      });
    } on ApiException catch (e) {
      if (!mounted || activeRequestId != _currentRequestId) return;
      setState(() {
        _isLoadingProfiles = false;
        if (e.statusCode == 401) {
          _requiresLogin = true;
          _profiles = const [];
          _selectedProfileId = null;
        } else {
          _profilesError = mapBookingErrorMessage(e);
        }
      });
    } catch (_) {
      if (!mounted || activeRequestId != _currentRequestId) return;
      setState(() {
        _isLoadingProfiles = false;
        _profilesError = 'Không thể tải danh sách hồ sơ bệnh nhân.';
      });
    }
  }

  Future<void> _openLoginPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
    if (!mounted) return;
    if (await _checkLoggedIn()) {
      await _loadProfiles();
    }
  }

  bool get _canSubmit {
    if (_isSubmitting || _doctor == null) return false;
    if (_firstSelectableDate == null ||
        _selectedDate == null ||
        _selectedSlot == null) {
      return false;
    }
    if (_requiresLogin) {
      // Cho phép bấm để kiểm tra token và chuyển sang đăng nhập theo luồng chuẩn
      return true;
    }
    return !_isLoadingProfiles &&
        _profilesError == null &&
        _profiles.isNotEmpty &&
        _selectedProfileId != null;
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting || _doctor == null || _selectedDate == null || _selectedSlot == null) {
      return;
    }

    final loggedIn = await _checkLoggedIn();
    if (!mounted) return;

    if (!loggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để đặt lịch khám')),
      );
      await _openLoginPage();
      return;
    }

    if (_selectedProfileId == null) {
      if (_profiles.isEmpty && !_isLoadingProfiles) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bạn chưa có hồ sơ bệnh nhân. Hãy tạo hồ sơ trước khi đặt lịch.',
            ),
          ),
        );
      }
      return;
    }

    final noteText = _noteController.text.trim();
    if (noteText.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ghi chú không được vượt quá 500 ký tự.'),
          backgroundColor: Color(0xffef4444),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _cartRepository.addItem(
        doctorId: _doctor!.id,
        patientProfileId: _selectedProfileId!,
        appointmentDate: _selectedDate!,
        timeSlot: _selectedSlot!,
        note: noteText.isEmpty ? null : noteText,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã thêm vào giỏ hàng'),
          backgroundColor: Color(0xff10b981),
        ),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        setState(() => _requiresLogin = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
            ),
            backgroundColor: Color(0xffef4444),
          ),
        );
        await _openLoginPage();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mapBookingErrorMessage(e)),
          backgroundColor: const Color(0xffef4444),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mapBookingErrorMessage(e)),
          backgroundColor: const Color(0xffef4444),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _doctor != null
        ? 'Đặt lịch · ${_doctor!.fullName}'
        : 'Đặt lịch khám';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          overflow: TextOverflow.ellipsis,
        ),
        elevation: 0,
      ),
      body: _buildBody(),
      bottomNavigationBar: _doctor != null ? _buildBottomBar() : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
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
                onPressed: _loadBookingData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    final doctor = _doctor!;
    final hasSchedules = doctor.schedules.isNotEmpty;
    final hasSelectableDates = _firstSelectableDate != null;

    final List<BookingTimeSlot> slots = _selectedDate != null
        ? generateHourlySlotsForDate(
            date: _selectedDate!,
            schedules: doctor.schedules,
            now: _currentNow(),
          )
        : const [];

    final String emptySlotMessage;
    if (_selectedDate != null &&
        _selectedDate!.year == _firstDate.year &&
        _selectedDate!.month == _firstDate.month &&
        _selectedDate!.day == _firstDate.day &&
        hasAnyScheduleForDate(_selectedDate!, doctor.schedules)) {
      emptySlotMessage =
          'Hôm nay không còn khung giờ trống. Vui lòng chọn ngày khác.';
    } else {
      emptySlotMessage = 'Bác sĩ không có lịch làm việc vào ngày này.';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookingDoctorSummary(
                doctor: doctor,
                imageUrl: _doctorRepository.imageUrl(doctor.avatarUrl),
              ),
              const SizedBox(height: 16),
              BookingPatientProfileSection(
                isLoading: _isLoadingProfiles,
                requiresLogin: _requiresLogin,
                profiles: _profiles,
                selectedProfileId: _selectedProfileId,
                errorMessage: _profilesError,
                enabled: !_isSubmitting,
                onChanged: (val) => setState(() => _selectedProfileId = val),
                onRetry: () => _loadProfiles(),
                onLogin: _openLoginPage,
              ),
              const SizedBox(height: 16),
              if (!hasSchedules || !hasSelectableDates)
                _buildEmptyScheduleCard(
                  message: !hasSchedules
                      ? 'Bác sĩ chưa có lịch làm việc'
                      : 'Bác sĩ chưa có lịch làm việc khả dụng trong 60 ngày tới',
                )
              else ...[
                _buildCalendarSection(doctor),
                const SizedBox(height: 16),
                _buildSlotSection(slots, emptySlotMessage),
                const SizedBox(height: 16),
                _buildNoteSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyScheduleCard({required String message}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.event_busy_outlined,
            size: 48,
            color: AppColors.muted,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Vui lòng quay lại sau hoặc chọn bác sĩ khác.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarSection(Doctor doctor) {
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
              Icon(
                Icons.calendar_month_outlined,
                size: 20,
                color: AppColors.primary,
              ),
              SizedBox(width: 8),
              Text(
                'Chọn ngày khám',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          if (_dayOffWarning != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xfffffbeb),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xfffde68a)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: Color(0xffd97706),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _dayOffWarning!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xff92400e),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          CalendarDatePicker(
            initialDate: _selectedDate ?? _firstSelectableDate!,
            firstDate: _firstDate,
            lastDate: _lastDate,
            currentDate: _firstDate,
            selectableDayPredicate: (day) => isBookingDaySelectable(
              day: day,
              schedules: doctor.schedules,
              dayOffDates: _dayOffDates,
              firstDate: _firstDate,
              lastDate: _lastDate,
            ),
            onDateChanged: (newDate) {
              setState(() {
                _selectedDate = normalizeDateOnly(newDate);
                _selectedSlot = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSlotSection(
    List<BookingTimeSlot> slots,
    String emptySlotMessage,
  ) {
    final dateTitle = _selectedDate != null
        ? 'Khung giờ khám · ${formatDisplayDate(_selectedDate!)}'
        : 'Khung giờ khám';

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
              const Icon(
                Icons.access_time_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dateTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          BookingSlotGrid(
            slots: slots,
            selectedSlot: _selectedSlot,
            emptyMessage: emptySlotMessage,
            enabled: !_isSubmitting,
            onSlotSelected: (slot) {
              setState(() => _selectedSlot = slot);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNoteSection() {
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
              Icon(
                Icons.edit_note_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              SizedBox(width: 8),
              Text(
                'Ghi chú (tùy chọn)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('booking-note-field'),
            controller: _noteController,
            enabled: !_isSubmitting,
            maxLength: 500,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Triệu chứng hoặc lưu ý cho bác sĩ...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
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
      child: FilledButton(
        key: const ValueKey('booking-submit-button'),
        onPressed: _canSubmit ? _handleSubmit : null,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSubmitting
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Đang thêm...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              )
            : const Text(
                'Thêm vào giỏ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}

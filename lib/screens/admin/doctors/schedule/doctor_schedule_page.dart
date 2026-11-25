import 'package:flutter/material.dart';
import 'package:medical_appointment_app/core/theme/app_theme.dart';
import 'package:medical_appointment_app/models/doctor.dart';
import 'package:medical_appointment_app/models/doctor_day_off.dart';
import 'package:medical_appointment_app/repositories/doctor_day_off_repository.dart';
import 'package:medical_appointment_app/repositories/doctor_schedule_repository.dart';
import 'package:medical_appointment_app/screens/admin/doctors/schedule/doctor_schedule_logic.dart';
import 'package:medical_appointment_app/screens/admin/doctors/schedule/widgets/day_off_form_sheet.dart';
import 'package:medical_appointment_app/screens/admin/doctors/schedule/widgets/schedule_form_sheet.dart';

/// Tham số truyền qua route '/admin/doctors/schedules'
class DoctorScheduleRouteArgs {
  final int doctorId;
  final String? doctorName;

  const DoctorScheduleRouteArgs({
    required this.doctorId,
    this.doctorName,
  });
}

/// Màn hình Admin quản lý Lịch làm việc và Ngày nghỉ phép của một bác sĩ
class DoctorSchedulePage extends StatefulWidget {
  const DoctorSchedulePage({
    super.key,
    required this.doctorId,
    this.doctorName,
    this.scheduleRepository,
    this.dayOffRepository,
    this.now,
  });

  final int? doctorId;
  final String? doctorName;
  final DoctorScheduleRepository? scheduleRepository;
  final DoctorDayOffRepository? dayOffRepository;
  final DateTime? now;

  @override
  State<DoctorSchedulePage> createState() => _DoctorSchedulePageState();
}

class _DoctorSchedulePageState extends State<DoctorSchedulePage>
    with SingleTickerProviderStateMixin {
  late final DoctorScheduleRepository _scheduleRepository =
      widget.scheduleRepository ?? DoctorScheduleRepository();
  late final DoctorDayOffRepository _dayOffRepository =
      widget.dayOffRepository ?? DoctorDayOffRepository();

  late final TabController _tabController;

  List<DoctorSchedule> _schedules = [];
  bool _isLoadingSchedules = true;
  String? _schedulesError;
  final Set<int> _deletingScheduleIds = {};

  List<DoctorDayOff> _dayOffs = [];
  bool _isLoadingDayOffs = true;
  String? _dayOffsError;
  final Set<int> _deletingDayOffIds = {};

  bool get _hasValidDoctorId =>
      widget.doctorId != null && widget.doctorId! > 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);

    if (_hasValidDoctorId) {
      _loadAll();
    } else {
      _isLoadingSchedules = false;
      _isLoadingDayOffs = false;
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadSchedules(), _loadDayOffs()]);
  }

  Future<void> _loadSchedules() async {
    if (!_hasValidDoctorId) return;
    setState(() {
      _isLoadingSchedules = true;
      _schedulesError = null;
    });

    try {
      final list = await _scheduleRepository.getSchedules(widget.doctorId!);
      if (!mounted) return;
      setState(() {
        _schedules = list;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _schedulesError = extractScheduleErrorMessage(
          e,
          fallback: 'Không thể tải lịch làm việc. Vui lòng thử lại.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingSchedules = false);
      }
    }
  }

  Future<void> _loadDayOffs() async {
    if (!_hasValidDoctorId) return;
    setState(() {
      _isLoadingDayOffs = true;
      _dayOffsError = null;
    });

    try {
      final list = await _dayOffRepository.getDayOffs(widget.doctorId!);
      if (!mounted) return;
      final sorted = List<DoctorDayOff>.from(list)
        ..sort((a, b) => a.dateOnly.compareTo(b.dateOnly));
      setState(() {
        _dayOffs = sorted;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dayOffsError = extractScheduleErrorMessage(
          e,
          fallback: 'Không thể tải danh sách ngày nghỉ. Vui lòng thử lại.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingDayOffs = false);
      }
    }
  }

  Future<void> _openScheduleForm({DoctorSchedule? schedule}) async {
    if (!_hasValidDoctorId) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ScheduleFormSheet(
        doctorId: widget.doctorId!,
        scheduleRepository: _scheduleRepository,
        schedule: schedule,
      ),
    );

    if (saved == true && mounted) {
      _showSuccessSnackBar(
        schedule != null
            ? 'Cập nhật lịch làm việc thành công.'
            : 'Thêm lịch làm việc thành công.',
      );
      await _loadSchedules();
    }
  }

  Future<void> _openDayOffForm() async {
    if (!_hasValidDoctorId) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DayOffFormSheet(
        doctorId: widget.doctorId!,
        dayOffRepository: _dayOffRepository,
        now: widget.now,
      ),
    );

    if (saved == true && mounted) {
      _showSuccessSnackBar('Thêm ngày nghỉ thành công.');
      await _loadDayOffs();
    }
  }

  Future<bool> _showDeleteConfirmDialog({
    required String title,
    required String message,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffef4444),
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _confirmAndDeleteSchedule(DoctorSchedule schedule) async {
    if (_deletingScheduleIds.contains(schedule.id)) return;

    final confirmed = await _showDeleteConfirmDialog(
      title: 'Xác nhận xóa',
      message:
          'Bạn có chắc chắn muốn xóa khung giờ ${schedule.timeRangeDisplay} (${schedule.dayName})?',
    );
    if (!confirmed || !mounted) return;

    setState(() => _deletingScheduleIds.add(schedule.id));
    try {
      await _scheduleRepository.deleteSchedule(schedule.id);
      if (!mounted) return;
      _showSuccessSnackBar('Xóa lịch làm việc thành công.');
      await _loadSchedules();
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(
        extractScheduleErrorMessage(
          e,
          fallback: 'Không thể xóa lịch làm việc. Vui lòng thử lại.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingScheduleIds.remove(schedule.id));
      }
    }
  }

  Future<void> _confirmAndDeleteDayOff(DoctorDayOff dayOff) async {
    if (!_hasValidDoctorId || _deletingDayOffIds.contains(dayOff.id)) return;

    final confirmed = await _showDeleteConfirmDialog(
      title: 'Xác nhận xóa',
      message: 'Bạn có chắc chắn muốn xóa ngày nghỉ ${dayOff.dateDisplay}?',
    );
    if (!confirmed || !mounted) return;

    setState(() => _deletingDayOffIds.add(dayOff.id));
    try {
      await _dayOffRepository.deleteDayOff(widget.doctorId!, dayOff.id);
      if (!mounted) return;
      _showSuccessSnackBar('Xóa ngày nghỉ thành công.');
      await _loadDayOffs();
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(
        extractScheduleErrorMessage(
          e,
          fallback: 'Không thể xóa ngày nghỉ. Vui lòng thử lại.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingDayOffIds.remove(dayOff.id));
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xff10b981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xffef4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String get _displayDoctorName {
    final trimmed = widget.doctorName?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
    if (_hasValidDoctorId) return 'Bác sĩ #${widget.doctorId}';
    return 'Bác sĩ';
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasValidDoctorId) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Lịch làm việc & Ngày nghỉ',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 54,
                  color: Color(0xffef4444),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Không tìm thấy thông tin bác sĩ để quản lý lịch làm việc.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: AppColors.text),
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Quay lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lịch làm việc & Ngày nghỉ',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            Text(
              _displayDoctorName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.muted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const ValueKey('refresh-schedule-page-button'),
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Tải lại',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(
              key: ValueKey('schedules-tab'),
              icon: Icon(Icons.schedule_rounded, size: 18),
              text: 'Lịch làm việc',
            ),
            Tab(
              key: ValueKey('day-offs-tab'),
              icon: Icon(Icons.event_busy_rounded, size: 18),
              text: 'Ngày nghỉ',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSchedulesTab(),
          _buildDayOffsTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              key: const ValueKey('add-schedule-fab'),
              onPressed: () => _openScheduleForm(),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Thêm lịch',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          : FloatingActionButton.extended(
              key: const ValueKey('add-day-off-fab'),
              onPressed: _openDayOffForm,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Thêm ngày nghỉ',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
    );
  }

  Widget _buildErrorState({
    required String message,
    required VoidCallback onRetry,
    Key? retryKey,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 54,
              color: Color(0xffef4444),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.text,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: retryKey,
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onRefresh,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.light,
                borderRadius: BorderRadius.circular(38),
              ),
              child: Icon(icon, size: 38, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Tải lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchedulesTab() {
    if (_isLoadingSchedules) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_schedulesError != null) {
      return _buildErrorState(
        message: _schedulesError!,
        onRetry: _loadSchedules,
        retryKey: const ValueKey('schedules-retry-button'),
      );
    }
    if (_schedules.isEmpty) {
      return _buildEmptyState(
        icon: Icons.calendar_today_outlined,
        title: 'Chưa có lịch làm việc',
        subtitle: 'Bấm "Thêm lịch" bên dưới để tạo khung giờ làm việc.',
        onRefresh: _loadSchedules,
      );
    }

    final grouped = GroupedDoctorSchedule.groupAndSort(_schedules);

    return RefreshIndicator(
      onRefresh: _loadSchedules,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: grouped.length,
        itemBuilder: (context, index) {
          final group = grouped[index];
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header ngày: "Thứ 2: 07:00-11:30, 13:30-17:00"
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.light,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          group.dayName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            group.fullDisplay,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Color(0xfff1f5f9)),
                  const SizedBox(height: 8),

                  // Từng khung giờ trong ngày (bấm để sửa, swipe hoặc bấm nút để xóa)
                  for (var i = 0; i < group.slots.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _buildScheduleSlotRow(group.slots[i]),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScheduleSlotRow(DoctorSchedule slot) {
    final isDeleting = _deletingScheduleIds.contains(slot.id);

    return Dismissible(
      key: ValueKey('schedule-dismiss-${slot.id}'),
      direction: isDeleting
          ? DismissDirection.none
          : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xfffee2e2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Color(0xffdc2626),
        ),
      ),
      confirmDismiss: (_) async {
        await _confirmAndDeleteSchedule(slot);
        return false;
      },
      child: Material(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: ValueKey('schedule-item-${slot.id}'),
          onTap: isDeleting ? null : () => _openScheduleForm(schedule: slot),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slot.timeRangeDisplay,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tối đa ${slot.maxPatients} bệnh nhân',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isDeleting)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else ...[
                  const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    key: ValueKey('delete-schedule-${slot.id}'),
                    onPressed: () => _confirmAndDeleteSchedule(slot),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    tooltip: 'Xóa lịch làm việc',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayOffsTab() {
    if (_isLoadingDayOffs) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_dayOffsError != null) {
      return _buildErrorState(
        message: _dayOffsError!,
        onRetry: _loadDayOffs,
        retryKey: const ValueKey('day-offs-retry-button'),
      );
    }
    if (_dayOffs.isEmpty) {
      return _buildEmptyState(
        icon: Icons.event_busy_outlined,
        title: 'Chưa có ngày nghỉ nào',
        subtitle: 'Bấm "Thêm ngày nghỉ" bên dưới để đăng ký ngày nghỉ phép.',
        onRefresh: _loadDayOffs,
      );
    }

    final today = vietnamToday(widget.now);

    return RefreshIndicator(
      onRefresh: _loadDayOffs,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _dayOffs.length,
        itemBuilder: (context, index) {
          final dayOff = _dayOffs[index];
          return _buildDayOffCard(dayOff, today);
        },
      ),
    );
  }

  Widget _buildDayOffCard(DoctorDayOff dayOff, DateTime today) {
    final isDeleting = _deletingDayOffIds.contains(dayOff.id);
    final dateOnly = dayOff.dateOnly;
    final isToday = dateOnly == today;
    final isPast = dateOnly.isBefore(today);
    final statusLabel = isToday ? 'Hôm nay' : (isPast ? 'Đã qua' : 'Sắp tới');
    final statusBg = isToday
        ? const Color(0xfffef3c7)
        : (isPast ? const Color(0xfff1f5f9) : AppColors.light);
    final statusFg = isToday
        ? const Color(0xffb45309)
        : (isPast ? AppColors.muted : AppColors.primary);

    final reasonText =
        dayOff.reason != null && dayOff.reason!.trim().isNotEmpty
            ? dayOff.reason!.trim()
            : 'Không có lý do';

    return Dismissible(
      key: ValueKey('day-off-dismiss-${dayOff.id}'),
      direction: isDeleting
          ? DismissDirection.none
          : DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xfffee2e2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Color(0xffdc2626),
        ),
      ),
      confirmDismiss: (_) async {
        await _confirmAndDeleteDayOff(dayOff);
        return false;
      },
      child: Card(
        key: ValueKey('day-off-item-${dayOff.id}'),
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.light,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.event_busy_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${dayOff.dayOfWeekLabel}, ${dayOff.dateDisplay}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusFg,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reasonText,
                      style: TextStyle(
                        fontSize: 13,
                        color: dayOff.reason != null &&
                                dayOff.reason!.trim().isNotEmpty
                            ? AppColors.text
                            : AppColors.muted,
                        fontStyle: dayOff.reason != null &&
                                dayOff.reason!.trim().isNotEmpty
                            ? FontStyle.normal
                            : FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              if (isDeleting)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  key: ValueKey('delete-day-off-${dayOff.id}'),
                  onPressed: () => _confirmAndDeleteDayOff(dayOff),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                    size: 22,
                  ),
                  tooltip: 'Xóa ngày nghỉ',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

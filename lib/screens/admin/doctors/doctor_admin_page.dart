import 'package:flutter/material.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/doctor.dart';
import '../../../../repositories/department_repository.dart';
import '../../../../repositories/doctor_day_off_repository.dart';
import '../../../../repositories/doctor_repository.dart';
import '../../../../repositories/doctor_schedule_repository.dart';
import '../../../../repositories/room_repository.dart';
import 'doctor_form_page.dart';
import 'schedule/doctor_schedule_page.dart';
import 'widgets/doctor_admin_card.dart';

class DoctorAdminPage extends StatefulWidget {
  const DoctorAdminPage({
    super.key,
    this.doctorRepository,
    this.departmentRepository,
    this.roomRepository,
    this.scheduleRepository,
    this.dayOffRepository,
  });

  final DoctorRepository? doctorRepository;
  final DepartmentRepository? departmentRepository;
  final RoomRepository? roomRepository;
  final DoctorScheduleRepository? scheduleRepository;
  final DoctorDayOffRepository? dayOffRepository;

  @override
  State<DoctorAdminPage> createState() => _DoctorAdminPageState();
}

class _DoctorAdminPageState extends State<DoctorAdminPage> {
  late final DoctorRepository _doctorRepository =
      widget.doctorRepository ?? DoctorRepository();
  late final DepartmentRepository _departmentRepository =
      widget.departmentRepository ?? DepartmentRepository();
  late final RoomRepository _roomRepository =
      widget.roomRepository ?? RoomRepository();

  final ScrollController _scrollController = ScrollController();

  List<Doctor> _doctors = [];
  bool _isLoading = true;
  bool _isLoadMore = false;
  String? _errorMessage;
  String? _loadMoreError;
  int _currentPage = 1;
  bool _hasNextPage = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadPage(1);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 150) {
      if (_hasNextPage && !_isLoadMore && !_isLoading && _loadMoreError == null) {
        _loadMore();
      }
    }
  }

  Future<void> _loadPage(int page) async {
    final activeRequestId = ++_requestId;
    setState(() {
      _isLoading = page == 1;
      _errorMessage = null;
      _loadMoreError = null;
      _isLoadMore = false;
    });

    try {
      final paged = await _doctorRepository.getDoctors(page: page, pageSize: 10);
      if (!mounted || activeRequestId != _requestId) return;
      setState(() {
        _currentPage = paged.page;
        _hasNextPage = paged.hasNextPage;
        if (page == 1) {
          _doctors = List<Doctor>.from(paged.items);
        } else {
          _doctors.addAll(paged.items);
        }
      });
    } catch (e) {
      if (!mounted || activeRequestId != _requestId) return;
      final message = e is ApiException
          ? e.displayMessage
          : 'Không thể tải danh sách bác sĩ. Vui lòng kiểm tra mạng.';
      setState(() => _errorMessage = message);
    } finally {
      if (mounted && activeRequestId == _requestId) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadMore || !_hasNextPage) return;

    final activeRequestId = _requestId;
    setState(() {
      _isLoadMore = true;
      _loadMoreError = null;
    });

    try {
      final nextPage = _currentPage + 1;
      final paged = await _doctorRepository.getDoctors(
        page: nextPage,
        pageSize: 10,
      );

      if (!mounted || activeRequestId != _requestId) return;
      setState(() {
        _currentPage = paged.page;
        _hasNextPage = paged.hasNextPage;
        _doctors.addAll(paged.items);
      });
    } catch (e) {
      if (!mounted || activeRequestId != _requestId) return;
      final message = e is ApiException
          ? e.displayMessage
          : 'Không thể tải thêm bác sĩ.';
      setState(() => _loadMoreError = message);
    } finally {
      if (mounted && activeRequestId == _requestId) {
        setState(() => _isLoadMore = false);
      }
    }
  }

  Future<void> _openForm({Doctor? doctor}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DoctorFormPage(
          doctor: doctor,
          doctorRepository: _doctorRepository,
          departmentRepository: _departmentRepository,
          roomRepository: _roomRepository,
        ),
      ),
    );

    if (result == true) {
      _loadPage(1);
    }
  }

  Future<void> _confirmDelete(Doctor doctor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc chắn muốn xóa bác sĩ "${doctor.fullName}"?\nThao tác này sẽ ngừng hoạt động của bác sĩ.',
        ),
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

    if (confirmed != true) return;

    try {
      await _doctorRepository.deleteDoctor(doctor.id);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Xóa bác sĩ thành công.'),
          backgroundColor: Color(0xff10b981),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadPage(1);
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException
          ? e.displayMessage
          : 'Không thể xóa bác sĩ. Vui lòng thử lại.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xffef4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
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
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.text,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => _loadPage(1),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_doctors.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.light,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Icon(
                  Icons.people_outline_rounded,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Chưa có bác sĩ nào trong hệ thống',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bấm nút "+" bên dưới để thêm bác sĩ mới.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () => _loadPage(1),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Tải lại danh sách'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadPage(1),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(top: 10, bottom: 90),
        itemCount: _doctors.length + (_hasNextPage ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _doctors.length) {
            if (_loadMoreError != null) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    Text(
                      _loadMoreError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xffdc2626),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton.icon(
                      key: const ValueKey('doctor-admin-load-more-retry'),
                      onPressed: _loadMore,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Thử tải thêm'),
                    ),
                  ],
                ),
              );
            }
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          final doctor = _doctors[index];
          return DoctorAdminCard(
            doctor: doctor,
            imageUrl: _doctorRepository.imageUrl(doctor.avatarUrl),
            onTap: () => _openForm(doctor: doctor),
            onDelete: () => _confirmDelete(doctor),
            onSchedule: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DoctorSchedulePage(
                    doctorId: doctor.id,
                    doctorName: doctor.fullName,
                    scheduleRepository: widget.scheduleRepository,
                    dayOffRepository: widget.dayOffRepository,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Quản lý Bác sĩ',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: () => _loadPage(1),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Tải lại',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('add-doctor-fab'),
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Thêm bác sĩ',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

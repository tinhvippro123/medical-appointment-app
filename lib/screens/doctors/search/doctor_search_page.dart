import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/doctor.dart';
import '../../../models/department.dart';
import '../../../models/patient_profile.dart';
import '../../../repositories/doctor_repository.dart';
import '../../booking/booking_logic.dart';
import '../../booking/booking_page.dart';
import '../detail/doctor_detail_page.dart';
import 'widgets/doctor_search_card.dart';

/// Màn hình tìm kiếm bác sĩ theo tên dành cho bệnh nhân
class DoctorSearchPage extends StatefulWidget {
  const DoctorSearchPage({
    super.key,
    this.repository,
    this.initialKeyword,
    this.department,
    this.browse = false,
    this.patient,
    this.bookingDate,
  });

  final DoctorRepository? repository;
  final String? initialKeyword;
  final Department? department;
  final bool browse;
  final PatientProfile? patient;
  final DateTime? bookingDate;

  @override
  State<DoctorSearchPage> createState() => _DoctorSearchPageState();
}

class _DoctorSearchPageState extends State<DoctorSearchPage> {
  late final DoctorRepository _repository;
  late final TextEditingController _searchController;
  final ScrollController _scrollController = ScrollController();

  Timer? _debounceTimer;
  int _currentRequestId = 0;
  bool _initialized = false;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _currentPage = 1;
  bool _hasNextPage = false;
  List<Doctor> _doctors = [];

  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? DoctorRepository();
    _searchController = TextEditingController(
      text: widget.initialKeyword ?? '',
    );
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final routeArg = ModalRoute.of(context)?.settings.arguments;
      if (_searchController.text.isEmpty &&
          routeArg is String &&
          routeArg.isNotEmpty) {
        _searchController.text = routeArg;
      }

      // Bắt đầu tìm kiếm với từ khóa ban đầu (hoặc rỗng theo hành vi backend: trả về tất cả bác sĩ đang hoạt động)
      // Tìm ngay lập tức, không chờ debounce lần đầu
      _performSearch(isNewKeyword: true);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading &&
          !_isLoadingMore &&
          _hasNextPage &&
          _errorMessage == null) {
        _performSearch(isNewKeyword: false);
      }
    }
  }

  void _onSearchChanged(String text) {
    setState(() {}); // cập nhật hiển thị nút xóa text
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(isNewKeyword: true);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {});
    _debounceTimer?.cancel();
    _performSearch(isNewKeyword: true);
  }

  Future<void> _performSearch({required bool isNewKeyword}) async {
    if (!isNewKeyword &&
        (_isLoading ||
            _isLoadingMore ||
            !_hasNextPage ||
            (_debounceTimer?.isActive ?? false))) {
      return;
    }
    // Tăng mã yêu cầu để bỏ qua các kết quả của request cũ
    final requestId = ++_currentRequestId;

    if (isNewKeyword) {
      setState(() {
        _isLoading = true;
        _isLoadingMore = false;
        _errorMessage = null;
        _currentPage = 1;
        _hasNextPage = false;
        _doctors = [];
      });
    } else {
      setState(() {
        _isLoadingMore = true;
        _errorMessage = null;
      });
    }

    try {
      final keyword = _searchController.text.trim();
      final pageToLoad = isNewKeyword ? 1 : _currentPage + 1;

      final departmentId = widget.department?.id;
      final result = await (widget.browse && keyword.isEmpty
          ? departmentId == null
                ? _repository.getDoctors(page: pageToLoad, pageSize: _pageSize)
                : _repository.getDepartmentDoctors(
                    departmentId,
                    page: pageToLoad,
                    pageSize: _pageSize,
                  )
          : _repository.searchDoctors(
              keyword: keyword.isEmpty ? null : keyword,
              departmentId: departmentId,
              page: pageToLoad,
              pageSize: _pageSize,
            ));

      // Nếu người dùng đã gõ từ khóa khác (mã yêu cầu đã thay đổi) hoặc widget đã unmount, bỏ qua kết quả cũ
      if (!mounted || requestId != _currentRequestId) return;

      setState(() {
        _currentPage = result.page;
        _hasNextPage = result.hasNextPage;
        if (isNewKeyword) {
          _doctors = result.items;
        } else {
          _doctors = [..._doctors, ...result.items];
        }
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = null;
      });
    } on ApiException catch (e) {
      if (!mounted || requestId != _currentRequestId) return;
      setState(() {
        _errorMessage = e.displayMessage;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted || requestId != _currentRequestId) return;
      setState(() {
        _errorMessage = 'Đã có lỗi xảy ra. Vui lòng thử lại.';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _navigateToDetail(int doctorId) {
    final navigator = Navigator.of(context);
    final patient = widget.patient;
    final bookingDate = widget.bookingDate;
    if (bookingDate != null) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => BookingPage(
            doctorId: doctorId,
            patient: patient,
            initialDate: bookingDate,
            doctorRepository: _repository,
          ),
        ),
      );
      return;
    }
    if (patient == null) {
      navigator.pushNamed('/doctors/detail', arguments: doctorId);
      return;
    }
    navigator.push(MaterialPageRoute(builder: (_) => DoctorDetailPage(
      doctorId: doctorId, patient: patient,
    )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Quay lại',
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xffcbd5e1)),
            ),
            child: TextField(
              controller: _searchController,
              autofocus: !widget.browse && widget.department == null,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              onSubmitted: (_) {
                _debounceTimer?.cancel();
                _performSearch(isNewKeyword: true);
              },
              style: const TextStyle(fontSize: 15, color: AppColors.text),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm bác sĩ theo tên...',
                hintStyle: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        tooltip: 'Xóa từ khóa',
                        onPressed: _clearSearch,
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.browse || widget.department != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                widget.department?.name ?? 'Danh sách bác sĩ',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          if (widget.bookingDate != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Ngày khám · ${formatDisplayDate(widget.bookingDate!)}'),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    // 1. Trạng thái Loading ban đầu
    if (_isLoading && _doctors.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // 2. Trạng thái Lỗi khi chưa có dữ liệu
    if (_errorMessage != null && _doctors.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xffef4444),
                size: 54,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.text,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _performSearch(isNewKeyword: true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    // 3. Trạng thái Rỗng
    if (_doctors.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.person_search_outlined,
                color: AppColors.muted,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Không tìm thấy bác sĩ nào',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchController.text.trim().isEmpty && widget.browse
                    ? widget.department == null
                          ? 'Hiện chưa có bác sĩ trong danh sách.'
                          : 'Chuyên khoa này chưa có bác sĩ.'
                    : 'Thử tìm kiếm với từ khóa khác',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ],
          ),
        ),
      );
    }

    // 4. Trạng thái Thành công có danh sách
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: _doctors.length + (_hasNextPage ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _doctors.length) {
          if (!_isLoadingMore) {
            return Center(
              child: TextButton(
                onPressed: () => _performSearch(isNewKeyword: false),
                child: Text(
                  _errorMessage == null
                      ? 'Xem thêm bác sĩ'
                      : 'Tải thêm thất bại. Thử lại',
                ),
              ),
            );
          }
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          );
        }

        final doctor = _doctors[index];
        return DoctorSearchCard(
          doctor: doctor,
          imageUrl: _repository.imageUrl(doctor.avatarUrl),
          onTap: () => _navigateToDetail(doctor.id),
        );
      },
    );
  }
}

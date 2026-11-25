import 'package:flutter/material.dart';
import 'package:medical_appointment_app/core/network/api_exception.dart';
import 'package:medical_appointment_app/core/theme/app_theme.dart';
import 'package:medical_appointment_app/helpers/session_helper.dart';
import 'package:medical_appointment_app/models/order.dart';
import 'package:medical_appointment_app/repositories/admin_order_repository.dart';
import 'package:medical_appointment_app/screens/admin/orders/admin_order_detail_page.dart';
import 'package:medical_appointment_app/screens/admin/orders/widgets/order_status_chip.dart';

/// Màn hình quản lý danh sách đơn đặt lịch dành cho Quản trị viên (ADMIN)
class AdminOrderPage extends StatefulWidget {
  const AdminOrderPage({
    super.key,
    this.repository,
    this.isAdminChecker,
    this.pickDateRange,
  });

  final AdminOrderRepository? repository;
  final Future<bool> Function()? isAdminChecker;
  final Future<DateTimeRange?> Function(
    BuildContext context,
    DateTimeRange? initialRange,
  )? pickDateRange;

  @override
  State<AdminOrderPage> createState() => _AdminOrderPageState();
}

class _AdminOrderPageState extends State<AdminOrderPage> {
  late final AdminOrderRepository _repository =
      widget.repository ?? AdminOrderRepository();

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  static const int _pageSize = 10;
  static const List<String?> _filterOptions = [
    null,
    OrderStatus.pending,
    OrderStatus.confirmed,
    OrderStatus.completed,
    OrderStatus.cancelled,
  ];

  bool _isCheckingAccess = true;
  bool _isAuthorized = false;

  List<Order> _orders = [];
  String? _selectedStatus;
  String _appliedKeyword = '';
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _isLoading = true;
  bool _isLoadMore = false;
  bool _loadMoreFailed = false;
  String? _errorMessage;
  int _currentPage = 1;
  bool _hasNextPage = false;
  int _requestId = 0;

  bool get _hasActiveFilters =>
      _selectedStatus != null ||
      _appliedKeyword.isNotEmpty ||
      _fromDate != null ||
      _toDate != null;

  static String _formatDisplayDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString().padLeft(4, '0');
    return '$d/$m/$y';
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initAccessAndLoad();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initAccessAndLoad() async {
    final isAdmin = await (widget.isAdminChecker ?? SessionHepler.isAdmin)();
    if (!mounted) return;

    setState(() {
      _isCheckingAccess = false;
      _isAuthorized = isAdmin;
    });

    if (isAdmin) {
      await _loadPage(1);
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 150) {
      if (_hasNextPage && !_isLoadMore && !_isLoading && !_loadMoreFailed) {
        _loadMore();
      }
    }
  }

  Future<void> _loadPage(int page) async {
    if (!_isAuthorized) return;
    final reqId = ++_requestId;

    setState(() {
      _isLoading = page == 1;
      _isLoadMore = false;
      _loadMoreFailed = false;
      _errorMessage = null;
    });

    try {
      final paged = await _repository.getOrders(
        page: page,
        pageSize: _pageSize,
        status: _selectedStatus,
        keyword: _appliedKeyword,
        fromDate: _fromDate,
        toDate: _toDate,
      );
      if (!mounted || reqId != _requestId) return;

      setState(() {
        _currentPage = paged.page;
        _hasNextPage = paged.hasNextPage;
        if (page == 1) {
          _orders = paged.items;
        } else {
          _orders = [..._orders, ...paged.items];
        }
      });
    } on ApiException catch (e) {
      if (!mounted || reqId != _requestId) return;
      setState(() => _errorMessage = e.displayMessage);
    } catch (_) {
      if (!mounted || reqId != _requestId) return;
      setState(
        () => _errorMessage =
            'Không thể tải danh sách đơn đặt lịch. Vui lòng kiểm tra mạng.',
      );
    } finally {
      if (mounted && reqId == _requestId) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadMore || !_hasNextPage || !_isAuthorized) return;
    final reqId = _requestId;

    setState(() {
      _isLoadMore = true;
      _loadMoreFailed = false;
    });

    try {
      final paged = await _repository.getOrders(
        page: _currentPage + 1,
        pageSize: _pageSize,
        status: _selectedStatus,
        keyword: _appliedKeyword,
        fromDate: _fromDate,
        toDate: _toDate,
      );
      if (!mounted || reqId != _requestId) return;

      setState(() {
        _currentPage = paged.page;
        _hasNextPage = paged.hasNextPage;
        _orders = [..._orders, ...paged.items];
      });
    } catch (_) {
      if (!mounted || reqId != _requestId) return;
      setState(() => _loadMoreFailed = true);
    } finally {
      if (mounted && reqId == _requestId) {
        setState(() => _isLoadMore = false);
      }
    }
  }

  void _onSelectStatusFilter(String? status) {
    if (_selectedStatus == status && _errorMessage == null) return;
    setState(() {
      _selectedStatus = status;
      _orders = [];
      _currentPage = 1;
      _hasNextPage = false;
    });
    _loadPage(1);
  }

  void _applyKeywordSearch() {
    FocusScope.of(context).unfocus();
    final trimmed = _searchController.text.trim();
    if (_appliedKeyword == trimmed && _errorMessage == null) {
      return;
    }
    setState(() {
      _appliedKeyword = trimmed;
      _orders = [];
      _currentPage = 1;
      _hasNextPage = false;
    });
    _loadPage(1);
  }

  void _clearKeywordSearch() {
    final hadApplied = _appliedKeyword.isNotEmpty;
    _searchController.clear();
    setState(() {
      if (hadApplied) {
        _appliedKeyword = '';
        _orders = [];
        _currentPage = 1;
        _hasNextPage = false;
      }
    });
    if (hadApplied) {
      _loadPage(1);
    }
  }

  Future<void> _onPickDateRange() async {
    FocusScope.of(context).unfocus();
    final initialRange = (_fromDate != null && _toDate != null)
        ? DateTimeRange(start: _fromDate!, end: _toDate!)
        : null;

    final picked = widget.pickDateRange != null
        ? await widget.pickDateRange!(context, initialRange)
        : await showDialog<DateTimeRange>(
            context: context,
            builder: (_) => _AdminDateRangeDialog(initialRange: initialRange),
          );

    if (picked == null || !mounted) {
      return;
    }

    final nextFrom = DateTime(
      picked.start.year,
      picked.start.month,
      picked.start.day,
    );
    final nextTo = DateTime(
      picked.end.year,
      picked.end.month,
      picked.end.day,
    );

    if (_fromDate == nextFrom && _toDate == nextTo && _errorMessage == null) {
      return;
    }

    setState(() {
      _fromDate = nextFrom;
      _toDate = nextTo;
      _orders = [];
      _currentPage = 1;
      _hasNextPage = false;
    });
    await _loadPage(1);
  }

  void _clearDateFilter() {
    if (_fromDate == null && _toDate == null) {
      return;
    }
    setState(() {
      _fromDate = null;
      _toDate = null;
      _orders = [];
      _currentPage = 1;
      _hasNextPage = false;
    });
    _loadPage(1);
  }

  void _resetAllFilters() {
    _searchController.clear();
    setState(() {
      _selectedStatus = null;
      _appliedKeyword = '';
      _fromDate = null;
      _toDate = null;
      _orders = [];
      _currentPage = 1;
      _hasNextPage = false;
    });
    _loadPage(1);
  }

  Future<void> _openDetail(Order order) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminOrderDetailPage(
          orderId: order.id,
          initialOrder: order,
          repository: _repository,
          isAdminChecker: widget.isAdminChecker,
        ),
      ),
    );

    if (changed == true && mounted) {
      await _loadPage(1);
    }
  }

  Widget _buildFilterBar() {
    final hasDateFilter = _fromDate != null && _toDate != null;
    final showClearKeyword =
        _searchController.text.isNotEmpty || _appliedKeyword.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xffe2e8f0)),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('admin-order-search-field'),
                    controller: _searchController,
                    maxLength: 100,
                    textInputAction: TextInputAction.search,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _applyKeywordSearch(),
                    style: const TextStyle(fontSize: 14, color: AppColors.text),
                    decoration: InputDecoration(
                      hintText: 'Tìm tên, SĐT hoặc #mã đơn...',
                      hintStyle: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.muted,
                      ),
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xfff8fafc),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: AppColors.muted,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showClearKeyword)
                            IconButton(
                              key: const ValueKey('admin-order-clear-search'),
                              tooltip: 'Xóa từ khóa',
                              visualDensity: VisualDensity.compact,
                              onPressed: _clearKeywordSearch,
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: AppColors.muted,
                              ),
                            ),
                          IconButton(
                            key: const ValueKey('admin-order-submit-search'),
                            tooltip: 'Tìm kiếm',
                            visualDensity: VisualDensity.compact,
                            onPressed: _applyKeywordSearch,
                            icon: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 19,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xffdfedf8)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xffdfedf8)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.3,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Lọc theo khoảng ngày',
                  child: Material(
                    color: hasDateFilter
                        ? AppColors.light
                        : const Color(0xfff8fafc),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      key: const ValueKey('admin-order-date-filter-btn'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: _onPickDateRange,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hasDateFilter
                                ? AppColors.primary
                                : const Color(0xffdfedf8),
                          ),
                        ),
                        child: Icon(
                          Icons.date_range_rounded,
                          size: 20,
                          color: hasDateFilter
                              ? AppColors.primary
                              : AppColors.text,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (hasDateFilter)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                key: const ValueKey('admin-order-active-date-chip'),
                padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
                decoration: BoxDecoration(
                  color: AppColors.light,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xffbfdbfe)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.event_available_rounded,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Từ ${_formatDisplayDate(_fromDate!)} đến ${_formatDisplayDate(_toDate!)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Tooltip(
                      message: 'Xóa lọc ngày',
                      child: InkWell(
                        key: const ValueKey('admin-order-clear-date'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: _clearDateFilter,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _filterOptions.map((status) {
                final isSelected = _selectedStatus == status;
                final label =
                    status == null ? 'Tất cả' : OrderStatus.label(status);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: ValueKey('order-filter-${status ?? 'all'}'),
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (_) => _onSelectStatusFilter(status),
                    selectedColor: AppColors.light,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? AppColors.primary : AppColors.text,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primary
                          : const Color(0xffcbd5e1),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnauthorized() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 56,
              color: Color(0xffef4444),
            ),
            const SizedBox(height: 16),
            const Text(
              'Bạn không có quyền truy cập',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Chỉ Quản trị viên (ADMIN) mới được phép quản lý đơn đặt lịch.',
              style: TextStyle(fontSize: 14, color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
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

  Widget _buildOrderCard(Order order) {
    return Card(
      key: ValueKey('order-card-${order.id}'),
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: () => _openDetail(order),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Đơn #${order.id}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                  const Spacer(),
                  OrderStatusChip(status: order.status),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order.customerDisplay,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 15,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Ngày đặt: ${order.createdAtFormatted}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, thickness: 0.8),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '${order.paymentMethodLabel} • ${order.paymentStatusLabel}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    order.totalAmountFormatted,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isCheckingAccess || _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isAuthorized) {
      return _buildUnauthorized();
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

    if (_orders.isEmpty) {
      final String statusNote;
      if (_hasActiveFilters) {
        statusNote = _selectedStatus != null &&
                _appliedKeyword.isEmpty &&
                _fromDate == null &&
                _toDate == null
            ? 'Không có đơn đặt lịch ở trạng thái "${OrderStatus.label(_selectedStatus!)}".'
            : 'Không tìm thấy đơn đặt lịch phù hợp với bộ lọc hiện tại.';
      } else {
        statusNote = 'Hiện chưa có đơn đặt lịch nào trong hệ thống.';
      }

      return RefreshIndicator(
        onRefresh: () => _loadPage(1),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 48),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.light,
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: const Icon(
                    Icons.event_note_outlined,
                    size: 40,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Chưa có đơn đặt lịch nào',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  statusNote,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    if (_hasActiveFilters)
                      OutlinedButton.icon(
                        key: const ValueKey('admin-order-reset-filters'),
                        onPressed: _resetAllFilters,
                        icon: const Icon(
                          Icons.filter_alt_off_rounded,
                          size: 18,
                        ),
                        label: const Text('Xóa bộ lọc'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => _loadPage(1),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Tải lại danh sách'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadPage(1),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: _orders.length + (_hasNextPage ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _orders.length) {
            if (_loadMoreFailed) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: TextButton.icon(
                    onPressed: _loadMore,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Tải thêm thất bại. Thử lại'),
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
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          return _buildOrderCard(_orders[index]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Quản lý Lịch hẹn',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_isAuthorized)
            IconButton(
              onPressed: _isLoading ? null : () => _loadPage(1),
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Tải lại',
            ),
        ],
      ),
      body: Column(
        children: [
          if (_isAuthorized) _buildFilterBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }
}

class _AdminDateRangeDialog extends StatefulWidget {
  const _AdminDateRangeDialog({this.initialRange});

  final DateTimeRange? initialRange;

  @override
  State<_AdminDateRangeDialog> createState() => _AdminDateRangeDialogState();
}

class _AdminDateRangeDialogState extends State<_AdminDateRangeDialog> {
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = widget.initialRange;
    if (initial != null) {
      _startDate = DateTime(
        initial.start.year,
        initial.start.month,
        initial.start.day,
      );
      _endDate = DateTime(
        initial.end.year,
        initial.end.month,
        initial.end.day,
      );
    } else {
      _startDate = today.subtract(const Duration(days: 6));
      _endDate = today;
    }
  }

  static String _fmtDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString().padLeft(4, '0');
    return '$day/$month/$year';
  }

  void _applyPreset(DateTime start, DateTime end) {
    setState(() {
      _startDate = DateTime(start.year, start.month, start.day);
      _endDate = DateTime(end.year, end.month, end.day);
    });
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Chọn ngày bắt đầu',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _startDate = DateTime(picked.year, picked.month, picked.day);
      if (_endDate.isBefore(_startDate)) {
        _endDate = _startDate;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Chọn ngày kết thúc',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _endDate = DateTime(picked.year, picked.month, picked.day);
      if (_startDate.isAfter(_endDate)) {
        _startDate = _endDate;
      }
    });
  }

  Widget _buildDateField({
    required Key fieldKey,
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: fieldKey,
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xffdfedf8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _fmtDate(value),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = today.subtract(const Duration(days: 6));
    final firstOfMonth = DateTime(today.year, today.month, 1);

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.date_range_rounded,
                    size: 22,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lọc theo khoảng ngày',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    key: const ValueKey('date-preset-today'),
                    label: const Text('Hôm nay'),
                    backgroundColor: const Color(0xfff8fafc),
                    side: const BorderSide(color: Color(0xffdfedf8)),
                    labelStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                    onPressed: () => _applyPreset(today, today),
                  ),
                  ActionChip(
                    key: const ValueKey('date-preset-7days'),
                    label: const Text('7 ngày qua'),
                    backgroundColor: const Color(0xfff8fafc),
                    side: const BorderSide(color: Color(0xffdfedf8)),
                    labelStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                    onPressed: () => _applyPreset(sevenDaysAgo, today),
                  ),
                  ActionChip(
                    key: const ValueKey('date-preset-month'),
                    label: const Text('Tháng này'),
                    backgroundColor: const Color(0xfff8fafc),
                    side: const BorderSide(color: Color(0xffdfedf8)),
                    labelStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                    onPressed: () => _applyPreset(firstOfMonth, today),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildDateField(
                    fieldKey: const ValueKey('date-range-pick-start'),
                    label: 'Từ ngày',
                    value: _startDate,
                    onTap: _pickStartDate,
                  ),
                  const SizedBox(width: 10),
                  _buildDateField(
                    fieldKey: const ValueKey('date-range-pick-end'),
                    label: 'Đến ngày',
                    value: _endDate,
                    onTap: _pickEndDate,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const ValueKey('date-range-apply-btn'),
                    onPressed: () => Navigator.of(context).pop(
                      DateTimeRange(start: _startDate, end: _endDate),
                    ),
                    child: const Text('Áp dụng'),
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

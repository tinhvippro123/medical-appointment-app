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
  static final DateTime _minDate = DateTime(2024, 1, 1);
  static const List<String> _weekDaysVi = [
    'T2',
    'T3',
    'T4',
    'T5',
    'T6',
    'T7',
    'CN',
  ];

  late final TextEditingController _startController;
  late final TextEditingController _endController;

  DateTime? _startDate;
  DateTime? _endDate;
  late DateTime _displayedMonth;
  int _rangeClickStep = 0;
  String? _validationError;

  DateTime get _maxDate => DateTime.now().add(const Duration(days: 365));

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
    _displayedMonth = DateTime(_endDate!.year, _endDate!.month, 1);
    _startController = TextEditingController(text: _fmtDate(_startDate!));
    _endController = TextEditingController(text: _fmtDate(_endDate!));
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  static String _fmtDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString().padLeft(4, '0');
    return '$day/$month/$year';
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime? _parseDdMmYyyy(String raw) {
    final trimmed = raw.trim();
    final parts = trimmed.split(RegExp(r'[/-]'));
    if (parts.length != 3) {
      return null;
    }
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) {
      return null;
    }
    if (year < 2024 ||
        year > 2100 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31) {
      return null;
    }
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  void _applyPreset(DateTime start, DateTime end) {
    FocusScope.of(context).unfocus();
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    setState(() {
      _startDate = s;
      _endDate = e;
      _displayedMonth = DateTime(e.year, e.month, 1);
      _startController.text = _fmtDate(s);
      _endController.text = _fmtDate(e);
      _rangeClickStep = 0;
      _validationError = null;
    });
  }

  void _onStartTextChanged(String value) {
    final parsed = _parseDdMmYyyy(value);
    setState(() {
      _validationError = null;
      if (parsed != null) {
        _startDate = parsed;
        _displayedMonth = DateTime(parsed.year, parsed.month, 1);
      }
    });
  }

  void _onEndTextChanged(String value) {
    final parsed = _parseDdMmYyyy(value);
    setState(() {
      _validationError = null;
      if (parsed != null) {
        _endDate = parsed;
        _displayedMonth = DateTime(parsed.year, parsed.month, 1);
      }
    });
  }

  void _onSelectCalendarDay(DateTime day) {
    FocusScope.of(context).unfocus();
    setState(() {
      _validationError = null;
      if (_rangeClickStep == 0 || _startDate == null) {
        _startDate = day;
        _endDate = day;
        _startController.text = _fmtDate(day);
        _endController.text = _fmtDate(day);
        _rangeClickStep = 1;
      } else {
        if (day.isBefore(_startDate!)) {
          _endDate = _startDate;
          _startDate = day;
        } else {
          _endDate = day;
        }
        _startController.text = _fmtDate(_startDate!);
        _endController.text = _fmtDate(_endDate!);
        _rangeClickStep = 0;
      }
    });
  }

  void _changeMonth(int offset) {
    final next = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + offset,
      1,
    );
    if (next.isBefore(DateTime(_minDate.year, _minDate.month, 1))) {
      return;
    }
    final maxMonth = DateTime(_maxDate.year, _maxDate.month, 1);
    if (next.isAfter(maxMonth)) {
      return;
    }
    setState(() => _displayedMonth = next);
  }

  void _submit() {
    final parsedStart = _parseDdMmYyyy(_startController.text);
    final parsedEnd = _parseDdMmYyyy(_endController.text);

    if (parsedStart == null || parsedEnd == null) {
      setState(() {
        _validationError =
            'Định dạng ngày không hợp lệ (nhập dd/MM/yyyy, VD: 20/11/2026).';
      });
      return;
    }

    if (parsedStart.isAfter(parsedEnd)) {
      setState(() {
        _validationError = 'Ngày bắt đầu không được lớn hơn ngày kết thúc.';
      });
      return;
    }

    Navigator.of(context).pop(DateTimeRange(start: parsedStart, end: parsedEnd));
  }

  Widget _buildPresetChip({
    required Key chipKey,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? AppColors.light : const Color(0xfff8fafc),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: chipKey,
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : const Color(0xffdfedf8),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? AppColors.primary : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateInput({
    required Key inputKey,
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 5),
          TextField(
            key: inputKey,
            controller: controller,
            keyboardType: TextInputType.datetime,
            onTap: onTap,
            onChanged: onChanged,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
            decoration: InputDecoration(
              hintText: 'dd/MM/yyyy',
              hintStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.muted,
              ),
              isDense: true,
              filled: true,
              fillColor: const Color(0xfff8fafc),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xffdfedf8)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xffdfedf8)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVietnameseCalendar(DateTime today) {
    final firstOfMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month,
      1,
    );
    final leadingBlanks = firstOfMonth.weekday - 1;
    final daysInMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    ).day;
    final totalCells = ((leadingBlanks + daysInMonth + 6) ~/ 7) * 7;
    final weekCount = totalCells ~/ 7;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffdfedf8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Tháng trước',
                onPressed: () => _changeMonth(-1),
                icon: const Icon(Icons.chevron_left_rounded, size: 22),
              ),
              Expanded(
                child: Text(
                  'Tháng ${_displayedMonth.month}, ${_displayedMonth.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Tháng sau',
                onPressed: () => _changeMonth(1),
                icon: const Icon(Icons.chevron_right_rounded, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: _weekDaysVi.map((label) {
              final isSunday = label == 'CN';
              return Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isSunday
                          ? const Color(0xffef4444)
                          : AppColors.muted,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          for (var week = 0; week < weekCount; week++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: List.generate(7, (dow) {
                  final cellIndex = week * 7 + dow;
                  final dayNum = cellIndex - leadingBlanks + 1;
                  if (dayNum < 1 || dayNum > daysInMonth) {
                    return const Expanded(child: SizedBox(height: 34));
                  }

                  final date = DateTime(
                    _displayedMonth.year,
                    _displayedMonth.month,
                    dayNum,
                  );
                  final isDisabled =
                      date.isBefore(_minDate) || date.isAfter(_maxDate);
                  final isStart =
                      _startDate != null && _isSameDay(date, _startDate!);
                  final isEnd = _endDate != null && _isSameDay(date, _endDate!);
                  final isEndpoint = isStart || isEnd;
                  final isInRange = _startDate != null &&
                      _endDate != null &&
                      date.isAfter(_startDate!) &&
                      date.isBefore(_endDate!);
                  final isToday = _isSameDay(date, today);

                  Color bgColor = Colors.transparent;
                  Color textColor = AppColors.text;
                  if (isEndpoint) {
                    bgColor = AppColors.primary;
                    textColor = Colors.white;
                  } else if (isInRange) {
                    bgColor = AppColors.light;
                    textColor = AppColors.primary;
                  } else if (isDisabled) {
                    textColor = const Color(0xffcbd5e1);
                  }

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: isDisabled
                          ? null
                          : () => _onSelectCalendarDay(date),
                      child: Container(
                        height: 34,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(9),
                          border: isToday && !isEndpoint
                              ? Border.all(color: AppColors.primary)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$dayNum',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isEndpoint || isInRange || isToday
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = today.subtract(const Duration(days: 6));
    final firstOfMonth = DateTime(today.year, today.month, 1);

    final isTodayPreset = _startDate != null &&
        _endDate != null &&
        _isSameDay(_startDate!, today) &&
        _isSameDay(_endDate!, today);
    final is7DaysPreset = _startDate != null &&
        _endDate != null &&
        _isSameDay(_startDate!, sevenDaysAgo) &&
        _isSameDay(_endDate!, today);
    final isMonthPreset = _startDate != null &&
        _endDate != null &&
        _isSameDay(_startDate!, firstOfMonth) &&
        _isSameDay(_endDate!, today);

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.date_range_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lọc theo khoảng ngày',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildPresetChip(
                    chipKey: const ValueKey('date-preset-today'),
                    label: 'Hôm nay',
                    isSelected: isTodayPreset,
                    onTap: () => _applyPreset(today, today),
                  ),
                  _buildPresetChip(
                    chipKey: const ValueKey('date-preset-7days'),
                    label: '7 ngày qua',
                    isSelected: is7DaysPreset,
                    onTap: () => _applyPreset(sevenDaysAgo, today),
                  ),
                  _buildPresetChip(
                    chipKey: const ValueKey('date-preset-month'),
                    label: 'Tháng này',
                    isSelected: isMonthPreset,
                    onTap: () => _applyPreset(firstOfMonth, today),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildDateInput(
                    inputKey: const ValueKey('date-range-start-input'),
                    label: 'Từ ngày',
                    controller: _startController,
                    onTap: () => _rangeClickStep = 0,
                    onChanged: _onStartTextChanged,
                  ),
                  const SizedBox(width: 8),
                  _buildDateInput(
                    inputKey: const ValueKey('date-range-end-input'),
                    label: 'Đến ngày',
                    controller: _endController,
                    onTap: () => _rangeClickStep = 1,
                    onChanged: _onEndTextChanged,
                  ),
                ],
              ),
              if (_validationError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _validationError!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xffdc2626),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              _buildVietnameseCalendar(today),
              const SizedBox(height: 14),
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
                    onPressed: _submit,
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

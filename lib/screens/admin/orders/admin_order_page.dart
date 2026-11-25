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
  });

  final AdminOrderRepository? repository;
  final Future<bool> Function()? isAdminChecker;

  @override
  State<AdminOrderPage> createState() => _AdminOrderPageState();
}

class _AdminOrderPageState extends State<AdminOrderPage> {
  late final AdminOrderRepository _repository =
      widget.repository ?? AdminOrderRepository();

  final ScrollController _scrollController = ScrollController();

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
  bool _isLoading = true;
  bool _isLoadMore = false;
  bool _loadMoreFailed = false;
  String? _errorMessage;
  int _currentPage = 1;
  bool _hasNextPage = false;
  int _requestId = 0;

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
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: _filterOptions.map((status) {
            final isSelected = _selectedStatus == status;
            final label = status == null ? 'Tất cả' : OrderStatus.label(status);
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
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
      final statusNote = _selectedStatus == null
          ? 'Hiện chưa có đơn đặt lịch nào trong hệ thống.'
          : 'Không có đơn đặt lịch ở trạng thái "${OrderStatus.label(_selectedStatus!)}".';

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
                OutlinedButton.icon(
                  onPressed: () => _loadPage(1),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Tải lại danh sách'),
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

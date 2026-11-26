import 'package:flutter/material.dart';
import 'package:medical_appointment_app/core/network/api_exception.dart';
import 'package:medical_appointment_app/core/theme/app_theme.dart';
import 'package:medical_appointment_app/helpers/session_helper.dart';
import 'package:medical_appointment_app/models/order.dart';
import 'package:medical_appointment_app/repositories/admin_order_repository.dart';
import 'package:medical_appointment_app/screens/admin/orders/widgets/order_status_chip.dart';

/// Màn hình chi tiết đơn đặt lịch và cập nhật trạng thái dành cho Quản trị viên (ADMIN)
class AdminOrderDetailPage extends StatefulWidget {
  const AdminOrderDetailPage({
    super.key,
    required this.orderId,
    this.initialOrder,
    this.repository,
    this.isAdminChecker,
  });

  final int orderId;
  final Order? initialOrder;
  final AdminOrderRepository? repository;
  final Future<bool> Function()? isAdminChecker;

  @override
  State<AdminOrderDetailPage> createState() => _AdminOrderDetailPageState();
}

class _AdminOrderDetailPageState extends State<AdminOrderDetailPage> {
  late final AdminOrderRepository _repository =
      widget.repository ?? AdminOrderRepository();

  bool _isCheckingAccess = true;
  bool _isAuthorized = false;
  bool _isLoading = true;
  bool _isUpdating = false;
  bool _hasUpdated = false;
  String? _errorMessage;
  Order? _order;
  String? _selectedNextStatus;

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder;
    _initAccessAndLoad();
  }

  Future<void> _initAccessAndLoad() async {
    final isAdmin = await (widget.isAdminChecker ?? SessionHepler.isAdmin)();
    if (!mounted) return;

    setState(() {
      _isCheckingAccess = false;
      _isAuthorized = isAdmin;
    });

    if (isAdmin) {
      await _loadDetail();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final order = await _repository.getOrderById(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _selectedNextStatus = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.displayMessage);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage =
            'Không thể tải chi tiết đơn đặt lịch. Vui lòng thử lại.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onStatusSelected(String? nextStatus) async {
    final currentOrder = _order;
    if (nextStatus == null || _isUpdating || currentOrder == null) return;

    final allowed = OrderStatus.allowedNextStatuses(currentOrder.status);
    if (!allowed.contains(nextStatus)) return;

    setState(() => _selectedNextStatus = nextStatus);

    String? cancellationReason;
    if (nextStatus == OrderStatus.cancelled) {
      cancellationReason = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _CancellationReasonDialog(),
      );
      if (!mounted) return;
      if (cancellationReason == null || cancellationReason.trim().isEmpty) {
        setState(() => _selectedNextStatus = null);
        return;
      }
    }

    final confirmed = await _showConfirmDialog(
      orderId: currentOrder.id,
      currentStatus: currentOrder.status,
      nextStatus: nextStatus,
      cancellationReason: cancellationReason,
    );
    if (!mounted) return;

    if (confirmed != true) {
      setState(() => _selectedNextStatus = null);
      return;
    }

    setState(() => _isUpdating = true);

    try {
      final updated = await _repository.updateOrderStatus(
        currentOrder.id,
        status: nextStatus,
        cancellationReason: cancellationReason,
      );
      if (!mounted) return;

      setState(() {
        _order = updated;
        _hasUpdated = true;
        _selectedNextStatus = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật trạng thái đơn đặt lịch thành công.'),
          backgroundColor: Color(0xff10b981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _selectedNextStatus = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.displayMessage),
          backgroundColor: const Color(0xffef4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _selectedNextStatus = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể cập nhật trạng thái đơn đặt lịch. Vui lòng thử lại.',
          ),
          backgroundColor: Color(0xffef4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<bool?> _showConfirmDialog({
    required int orderId,
    required String currentStatus,
    required String nextStatus,
    String? cancellationReason,
  }) {
    var submitted = false;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận đổi trạng thái'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bạn có chắc chắn muốn chuyển đơn #$orderId từ "${OrderStatus.label(currentStatus)}" sang "${OrderStatus.label(nextStatus)}"?',
            ),
            if (cancellationReason != null &&
                cancellationReason.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xfffef2f2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xfffecaca)),
                ),
                child: Text(
                  'Lý do hủy: ${cancellationReason.trim()}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xffb91c1c),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const ValueKey('confirm-status-change-button'),
            onPressed: () {
              if (submitted) return;
              submitted = true;
              Navigator.of(ctx).pop(true);
            },
            style: FilledButton.styleFrom(
              backgroundColor: nextStatus == OrderStatus.cancelled
                  ? const Color(0xffdc2626)
                  : AppColors.primary,
            ),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  void _popWithResult() {
    if (_isUpdating) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(_hasUpdated);
    }
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
              'Chỉ Quản trị viên (ADMIN) mới được phép xem và cập nhật đơn đặt lịch.',
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
                onPressed: _loadDetail,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    final order = _order;
    if (order == null) {
      return const Center(
        child: Text(
          'Không tìm thấy thông tin đơn đặt lịch',
          style: TextStyle(fontSize: 16, color: AppColors.muted),
        ),
      );
    }

    final allowedNext = order.allowedNextStatuses;

    return RefreshIndicator(
      onRefresh: _loadDetail,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSummaryCard(order),
            const SizedBox(height: 16),
            _buildStatusUpdateCard(order, allowedNext),
            const SizedBox(height: 16),
            _buildOrderDetailsCard(order),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(Order order) {
    final reason = order.cancellationReason?.trim();
    final txId = order.transactionId?.trim();

    return Container(
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
              Expanded(
                child: Text(
                  'Đơn hàng #${order.id}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
              ),
              OrderStatusChip(status: order.status),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xfff1f5f9)),
          const SizedBox(height: 12),
          _infoRow(
            icon: Icons.person_outline_rounded,
            label: 'Khách hàng',
            value: order.customerDisplay,
          ),
          _infoRow(
            icon: Icons.access_time_rounded,
            label: 'Ngày đặt',
            value: order.createdAtFormatted,
          ),
          if (order.updatedAt != null)
            _infoRow(
              icon: Icons.update_rounded,
              label: 'Cập nhật lúc',
              value: order.updatedAtFormatted,
            ),
          _infoRow(
            icon: Icons.payment_outlined,
            label: 'Phương thức thanh toán',
            value: order.paymentMethodLabel,
          ),
          _infoRow(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Trạng thái thanh toán',
            value: order.paymentStatusLabel,
            valueColor: order.isPaid
                ? const Color(0xff059669)
                : const Color(0xffd97706),
          ),
          if (txId != null && txId.isNotEmpty)
            _infoRow(
              icon: Icons.receipt_long_outlined,
              label: 'Mã giao dịch',
              value: txId,
            ),
          const SizedBox(height: 6),
          const Divider(height: 1, color: Color(0xfff1f5f9)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Tổng tiền',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const Spacer(),
              Text(
                order.totalAmountFormatted,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xfffef2f2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xfffecaca)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: Color(0xffdc2626),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lý do hủy: $reason',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xff991b1b),
                        fontWeight: FontWeight.w500,
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

  Widget _buildStatusUpdateCard(Order order, List<String> allowedNext) {
    return Container(
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
                Icons.swap_horiz_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              SizedBox(width: 8),
              Text(
                'Cập nhật trạng thái đơn',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (allowedNext.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xfff8fafc),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xffe2e8f0)),
              ),
              child: Text(
                'Đơn hàng đang ở trạng thái "${order.statusLabel}", không thể chuyển trạng thái tiếp.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else ...[
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'Chuyển sang trạng thái',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: const ValueKey('order-status-dropdown'),
                  isExpanded: true,
                  value: _selectedNextStatus,
                  hint: const Text('Chọn trạng thái tiếp theo'),
                  items: allowedNext
                      .map(
                        (status) => DropdownMenuItem<String>(
                          value: status,
                          child: Text(OrderStatus.label(status)),
                        ),
                      )
                      .toList(),
                  onChanged: _isUpdating ? null : _onStatusSelected,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Lưu ý: Đơn thanh toán trực tuyến cần thanh toán trước khi xác nhận; đơn tiền mặt sẽ tự chuyển Đã thanh toán khi Hoàn thành.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            if (_isUpdating) ...[
              const SizedBox(height: 12),
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Đang cập nhật trạng thái...',
                    style: TextStyle(fontSize: 13, color: AppColors.primary),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildOrderDetailsCard(Order order) {
    final details = order.orderDetails;

    return Container(
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
                Icons.medical_services_outlined,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Chi tiết lịch khám (${details.length})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (details.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Đơn hàng chưa có chi tiết lịch khám.',
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: AppColors.muted,
                ),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < details.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _buildOrderDetailItem(details[i]),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildOrderDetailItem(OrderDetail item) {
    final note = item.note?.trim();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.light,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'STT #${item.queueNumber}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.doctorFullName.isEmpty
                      ? 'Bác sĩ #${item.doctorId}'
                      : item.doctorFullName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              OrderStatusChip(status: item.status, compact: true),
            ],
          ),
          const SizedBox(height: 8),
          _detailLine(
            Icons.local_hospital_outlined,
            '${item.departmentName} • ${item.roomDisplay}',
          ),
          const SizedBox(height: 4),
          _detailLine(
            Icons.badge_outlined,
            'Người khám: ${item.patientProfileFullName}',
          ),
          const SizedBox(height: 4),
          _detailLine(
            Icons.calendar_today_outlined,
            '${item.appointmentDateFormatted} • ${item.timeSlot}',
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 4),
            _detailLine(Icons.note_outlined, 'Ghi chú: $note'),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Phí khám:',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const Spacer(),
              Text(
                item.feeFormatted,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.muted),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailLine(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.muted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: AppColors.text),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _isUpdating) return;
        _popWithResult();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: Navigator.of(context).canPop()
              ? BackButton(onPressed: _isUpdating ? null : _popWithResult)
              : null,
          title: Text(
            'Chi tiết đơn #${widget.orderId}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          actions: [
            if (_isAuthorized)
              IconButton(
                onPressed: _isLoading || _isUpdating ? null : _loadDetail,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Tải lại',
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }
}

/// Dialog nhập lý do hủy đơn đặt lịch (bắt buộc nhập khi chọn Cancelled)
class _CancellationReasonDialog extends StatefulWidget {
  const _CancellationReasonDialog();

  @override
  State<_CancellationReasonDialog> createState() =>
      _CancellationReasonDialogState();
}

class _CancellationReasonDialogState extends State<_CancellationReasonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_submitted) return;
    if (_formKey.currentState?.validate() != true) return;
    _submitted = true;
    Navigator.of(context).pop(_reasonController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Lý do hủy đơn'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: const ValueKey('cancellation-reason-field'),
          controller: _reasonController,
          autofocus: true,
          maxLines: 3,
          maxLength: 500,
          decoration: InputDecoration(
            labelText: 'Lý do hủy *',
            hintText: 'Nhập lý do hủy đơn đặt lịch...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: (value) {
            final trimmed = value?.trim() ?? '';
            if (trimmed.isEmpty) {
              return 'Vui lòng nhập lý do hủy';
            }
            if (trimmed.length > 500) {
              return 'Lý do hủy không được vượt quá 500 ký tự';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          key: const ValueKey('cancellation-reason-submit-button'),
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xffdc2626),
          ),
          child: const Text('Tiếp tục'),
        ),
      ],
    );
  }
}

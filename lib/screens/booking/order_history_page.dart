import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../models/paged_result.dart';
import '../../models/payment_models.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/payment_repository.dart';
import '../admin/orders/widgets/order_status_chip.dart';
import '../payment/online_payment_page.dart';
import 'widgets/appointment_ticket.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key, this.repository});

  final OrderRepository? repository;

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  late final _repository = widget.repository ?? OrderRepository();
  late Future<PagedResult<Order>> _orders = _repository.list();

  void _loadPage(int page) {
    setState(() => _orders = _repository.list(page: page));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<PagedResult<Order>>(
    future: _orders,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      final result = snapshot.data;
      if (result == null) {
        return _LoadError(
          message: 'Không tải được lịch sử khám.',
          onRetry: () => _loadPage(1),
        );
      }
      if (result.items.isEmpty) {
        return const Center(child: Text('Bạn chưa có lịch hẹn nào.'));
      }
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final order in result.items)
                Card(
                  color: Colors.white,
                  child: ListTile(
                    title: Text(
                      'Đơn #${order.id} · ${order.createdAtFormatted}',
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OrderStatusChip(status: order.status),
                          Text('${order.appointmentCount} lịch hẹn'),
                          Text(order.totalAmountFormatted),
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _OrderDetailPage(
                          id: order.id,
                          repository: _repository,
                        ),
                      ),
                    ),
                  ),
                ),
              if (result.hasPreviousPage || result.hasNextPage)
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    if (result.hasPreviousPage)
                      TextButton(
                        onPressed: () => _loadPage(result.page - 1),
                        child: const Text('Trang trước'),
                      ),
                    Text('Trang ${result.page}'),
                    if (result.hasNextPage)
                      TextButton(
                        onPressed: () => _loadPage(result.page + 1),
                        child: const Text('Trang sau'),
                      ),
                  ],
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _OrderDetailPage extends StatefulWidget {
  const _OrderDetailPage({required this.id, required this.repository});

  final int id;
  final OrderRepository repository;

  @override
  State<_OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<_OrderDetailPage> {
  late Future<Order> _order = widget.repository.detail(widget.id);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Phiếu khám bệnh')),
    body: SafeArea(
      child: FutureBuilder<Order>(
        future: _order,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final order = snapshot.data;
          if (order != null) return OrderInfo(order: order);
          return _LoadError(
            message: 'Không tải được chi tiết lịch khám.',
            onRetry: () =>
                setState(() => _order = widget.repository.detail(widget.id)),
          );
        },
      ),
    ),
  );
}

/// Dùng chung cho kết quả checkout và chi tiết trong lịch sử khám.
class OrderInfo extends StatefulWidget {
  const OrderInfo({
    super.key,
    required this.order,
    this.action,
    this.paymentRepository,
  });

  final Order order;
  final Widget? action;
  final PaymentRepository? paymentRepository;

  @override
  State<OrderInfo> createState() => _OrderInfoState();
}

class _OrderInfoState extends State<OrderInfo> {
  late Order _order = widget.order;

  @override
  void didUpdateWidget(covariant OrderInfo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order != widget.order) {
      _order = widget.order;
    }
  }

  String? get _onlineMethod {
    final method = _order.paymentMethodLabel;
    return method == 'VNPay' || method == 'VietQR' ? method : null;
  }

  Future<void> _openOnlinePayment() async {
    final method =
        _onlineMethod ??
        await showDialog<String>(
          context: context,
          builder: (context) => SimpleDialog(
            title: const Text('Chọn phương thức thanh toán'),
            children: [
              for (final option in ['VietQR', 'VNPay'])
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, option),
                  child: Text(option),
                ),
            ],
          ),
        );
    if (method == null || !mounted) return;

    final result = await Navigator.of(context).push<PaymentResult>(
      MaterialPageRoute(
        builder: (_) => OnlinePaymentPage(
          order: _order,
          method: method,
          repository: widget.paymentRepository,
        ),
      ),
    );

    if (result != null && result.success && mounted) {
      setState(() {
        _order = _order.copyWith(
          paymentMethod: result.paymentMethod,
          paymentStatus: result.paymentStatus,
          transactionId: result.transactionId,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPayOnline =
        !_order.isPaid && _order.status != OrderStatus.cancelled;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    title: Text(
                      'Đơn #${_order.id} · ${_order.totalAmountFormatted}',
                    ),
                    subtitle: Text(
                      '${_order.paymentMethodLabel} · ${_order.paymentStatusLabel}',
                    ),
                    trailing: OrderStatusChip(
                      status: _order.status,
                      compact: true,
                    ),
                  ),
                  if (_order.isPaid &&
                      _order.transactionId != null &&
                      _order.transactionId!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        'Mã giao dịch: ${_order.transactionId}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xff059669),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (canPayOnline)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: FilledButton.tonalIcon(
                        key: const ValueKey('open-online-payment-btn'),
                        onPressed: _openOnlinePayment,
                        icon: const Icon(Icons.payment_rounded, size: 19),
                        label: Text(
                          _onlineMethod == null
                              ? 'Thanh toán trực tuyến'
                              : 'Thanh toán qua $_onlineMethod',
                        ),
                      ),
                    ),
                ],
              ),
            ),
            for (final item in _order.orderDetails)
              AppointmentTicket(appointment: item),
            if (widget.action != null) ...[
              const SizedBox(height: 12),
              widget.action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        TextButton(onPressed: onRetry, child: const Text('Thử lại')),
      ],
    ),
  );
}

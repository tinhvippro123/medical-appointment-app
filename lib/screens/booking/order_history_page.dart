import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/order.dart';
import '../../models/paged_result.dart';
import '../../repositories/order_repository.dart';
import '../admin/orders/widgets/order_status_chip.dart';

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
    appBar: AppBar(title: const Text('Chi tiết lịch khám')),
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
class OrderInfo extends StatelessWidget {
  const OrderInfo({super.key, required this.order, this.action});

  final Order order;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.white,
            child: ListTile(
              title: Text('Đơn #${order.id} · ${order.totalAmountFormatted}'),
              subtitle: Text(
                '${order.paymentMethodLabel} · ${order.paymentStatusLabel}',
              ),
              trailing: OrderStatusChip(status: order.status, compact: true),
            ),
          ),
          for (final item in order.orderDetails)
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STT #${item.queueNumber} · ${item.doctorFullName}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(item.roomDisplay),
                    Text('${item.appointmentDateFormatted} · ${item.timeSlot}'),
                    Text('Người khám: ${item.patientProfileFullName}'),
                    Text('Phí khám: ${item.feeFormatted}'),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _showTicketQr(context, item.id),
                      icon: const Icon(Icons.qr_code_2),
                      label: const Text('Mã QR'),
                    ),
                  ],
                ),
              ),
            ),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    ),
  );

  void _showTicketQr(BuildContext context, int id) {
    final code = 'TICKET-$id';
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mã QR lịch khám'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 200,
              child: QrImageView(
                data: code,
                backgroundColor: Colors.white,
                semanticsLabel: 'Mã QR $code',
              ),
            ),
            SelectableText(code),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
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

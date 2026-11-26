import 'package:flutter/material.dart';
import 'package:medical_appointment_app/models/order.dart';

/// Bảng màu hiển thị cho từng trạng thái đơn đặt lịch
class OrderStatusStyle {
  const OrderStatusStyle({
    required this.label,
    required this.backgroundColor,
    required this.borderColor,
    required this.foregroundColor,
    required this.icon,
  });

  final String label;
  final Color backgroundColor;
  final Color borderColor;
  final Color foregroundColor;
  final IconData icon;
}

/// Widget chip hiển thị trạng thái đơn đặt lịch với màu sắc phân biệt rõ ràng:
/// Pending = vàng, Confirmed = xanh, Completed = xám, Cancelled = đỏ.
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({
    super.key,
    required this.status,
    this.compact = false,
  });

  final String status;
  final bool compact;

  static OrderStatusStyle styleFor(String status) {
    switch (OrderStatus.normalize(status)) {
      case OrderStatus.pending:
        return const OrderStatusStyle(
          label: 'Chờ xác nhận',
          backgroundColor: Color(0xfffef3c7),
          borderColor: Color(0xfffde68a),
          foregroundColor: Color(0xffb45309),
          icon: Icons.schedule_rounded,
        );
      case OrderStatus.confirmed:
        return const OrderStatusStyle(
          label: 'Đã xác nhận',
          backgroundColor: Color(0xffdbeafe),
          borderColor: Color(0xffbfdbfe),
          foregroundColor: Color(0xff1d4ed8),
          icon: Icons.verified_outlined,
        );
      case OrderStatus.completed:
        return const OrderStatusStyle(
          label: 'Hoàn thành',
          backgroundColor: Color(0xfff1f5f9),
          borderColor: Color(0xffcbd5e1),
          foregroundColor: Color(0xff475569),
          icon: Icons.task_alt_rounded,
        );
      case OrderStatus.cancelled:
        return const OrderStatusStyle(
          label: 'Đã hủy',
          backgroundColor: Color(0xfffee2e2),
          borderColor: Color(0xfffecaca),
          foregroundColor: Color(0xffdc2626),
          icon: Icons.cancel_outlined,
        );
      default:
        return OrderStatusStyle(
          label: OrderStatus.label(status),
          backgroundColor: const Color(0xfff1f5f9),
          borderColor: const Color(0xffcbd5e1),
          foregroundColor: const Color(0xff475569),
          icon: Icons.info_outline_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = styleFor(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            style.icon,
            size: compact ? 13 : 14,
            color: style.foregroundColor,
          ),
          const SizedBox(width: 5),
          Text(
            style.label,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: style.foregroundColor,
            ),
          ),
        ],
      ),
    );
  }
}

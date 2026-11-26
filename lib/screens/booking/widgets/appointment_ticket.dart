import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/health_center_info.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/order.dart';

class AppointmentTicket extends StatelessWidget {
  const AppointmentTicket({super.key, required this.appointment});

  final OrderDetail appointment;

  String get _ticketCode => 'TICKET-${appointment.id}';

  Widget _qrCode(double size) => SizedBox.square(
    dimension: size,
    child: QrImageView(
      data: _ticketCode,
      backgroundColor: Colors.white,
      semanticsLabel: 'Mã QR $_ticketCode',
    ),
  );

  void _showQr(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mã QR lịch khám'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [_qrCode(200), SelectableText(_ticketCode)],
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Card(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xffdfedf8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: AppColors.dark,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PHIẾU KHÁM BỆNH',
                    style: theme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    healthCenterName,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    healthCenterAddress,
                    style: TextStyle(color: AppColors.light),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _TicketValue(
                      label: 'Số thứ tự',
                      value: appointment.queueNumber > 0
                          ? '${appointment.queueNumber}'
                          : '—',
                      emphasized: true,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (appointment.departmentName.isNotEmpty)
                            Text(
                              appointment.departmentName,
                              style: theme.titleMedium,
                            ),
                          Text(
                            appointment.roomDisplay,
                            style: theme.titleLarge?.copyWith(
                              color: AppColors.dark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _TicketValue(
                        label: 'Ngày khám',
                        value: appointment.appointmentDateFormatted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _TicketValue(
                        label: 'Giờ dự kiến',
                        value: appointment.timeSlot.isEmpty
                            ? 'Chưa cập nhật'
                            : appointment.timeSlot,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TicketLine(
                            'Người khám',
                            appointment.patientProfileFullName,
                          ),
                          _TicketLine('Bác sĩ', appointment.doctorFullName),
                          _TicketLine('Mã phiếu', _ticketCode),
                          _TicketLine('Phí khám', appointment.feeFormatted),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => _showQr(context),
                      child: Column(
                        children: [_qrCode(88), const Text('Mã QR')],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketValue extends StatelessWidget {
  const _TicketValue({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.light,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Text(label, textAlign: TextAlign.center),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.dark,
            fontSize: emphasized ? 32 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

class _TicketLine extends StatelessWidget {
  const _TicketLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text.rich(
      TextSpan(
        text: '$label: ',
        style: const TextStyle(color: AppColors.muted),
        children: [
          TextSpan(
            text: value.isEmpty ? 'Chưa cập nhật' : value,
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

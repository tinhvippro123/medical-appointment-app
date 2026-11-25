import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../models/doctor.dart';
import '../../models/patient_profile.dart';
import '../../models/payment_models.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/payment_repository.dart';
import '../payment/online_payment_page.dart';
import 'booking_logic.dart';
import 'order_history_page.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({
    super.key,
    required this.doctor,
    required this.patient,
    required this.date,
    required this.slot,
    required this.note,
    this.repository,
    this.paymentRepository,
  });

  final Doctor doctor;
  final PatientProfile patient;
  final DateTime date;
  final String slot;
  final String note;
  final OrderRepository? repository;
  final PaymentRepository? paymentRepository;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  late final _repository = widget.repository ?? OrderRepository();
  String _paymentMethod = 'Cash';
  bool _submitting = false;

  Future<void> _confirm() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final order = await _repository.checkout(
        doctorId: widget.doctor.id,
        patientProfileId: widget.patient.id,
        date: widget.date,
        slot: widget.slot,
        note: widget.note,
        paymentMethod: _paymentMethod,
      );
      if (!mounted) return;
      var finalOrder = order;
      if (_paymentMethod == 'VietQR' || _paymentMethod == 'VNPay') {
        final paymentResult = await Navigator.of(context).push<PaymentResult>(
          MaterialPageRoute(
            builder: (_) => OnlinePaymentPage(
              order: order,
              method: _paymentMethod,
              repository: widget.paymentRepository,
            ),
          ),
        );
        if (!mounted) return;
        if (paymentResult != null && paymentResult.success) {
          finalOrder = order.copyWith(
            paymentMethod: paymentResult.paymentMethod,
            paymentStatus: paymentResult.paymentStatus,
            transactionId: paymentResult.transactionId,
          );
        }
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Đặt lịch thành công!')),
            body: SafeArea(
              child: OrderInfo(
                order: finalOrder,
                paymentRepository: widget.paymentRepository,
                action: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Về trang chủ'),
                ),
              ),
            ),
          ),
        ),
        (route) => route.isFirst || route.settings.name == '/home',
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException
          ? error.displayMessage
          : 'Không thể đặt lịch. Vui lòng thử lại.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_submitting,
    child: Scaffold(
      appBar: AppBar(title: const Text('Thanh toán')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Align(
            alignment: Alignment.center,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _confirm,
                  child: Text(
                    _submitting ? 'Đang đặt lịch…' : 'Xác nhận đặt lịch',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: Colors.white,
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(widget.doctor.fullName),
                        subtitle: Text(
                          '${widget.patient.displayLabel}\n'
                          '${formatDisplayDate(widget.date)} · ${widget.slot}',
                        ),
                      ),
                      ListTile(
                        title: const Text('Tổng tiền'),
                        subtitle: Text(widget.doctor.feeFormatted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  color: Colors.white,
                  child: RadioGroup<String>(
                    groupValue: _paymentMethod,
                    onChanged: (value) {
                      if (value != null) setState(() => _paymentMethod = value);
                    },
                    child: Column(
                      children: [
                        const ListTile(title: Text('Phương thức thanh toán')),
                        RadioListTile(
                          value: 'Cash',
                          enabled: !_submitting,
                          title: const Text('Tiền mặt tại quầy'),
                        ),
                        RadioListTile(
                          value: 'VNPay',
                          enabled: !_submitting,
                          title: const Text('VNPay'),
                        ),
                        RadioListTile(
                          value: 'VietQR',
                          enabled: !_submitting,
                          title: const Text('VietQR'),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _paymentMethod == 'Cash'
                        ? 'Thanh toán trực tiếp tại quầy tiếp nhận khi đến khám.'
                        : 'Sau khi bấm xác nhận, màn hình thanh toán $_paymentMethod sẽ mở ngay để bạn hoàn tất giao dịch.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

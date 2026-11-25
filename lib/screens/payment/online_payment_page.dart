import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../models/order.dart';
import '../../models/payment_models.dart';
import '../../repositories/payment_repository.dart';

class OnlinePaymentPage extends StatefulWidget {
  const OnlinePaymentPage({
    super.key,
    required this.order,
    this.initialMethod,
    this.repository,
  });

  final Order order;
  final String? initialMethod;
  final PaymentRepository? repository;

  @override
  State<OnlinePaymentPage> createState() => _OnlinePaymentPageState();
}

class _OnlinePaymentPageState extends State<OnlinePaymentPage> {
  late final PaymentRepository _repository =
      widget.repository ?? PaymentRepository();

  late String _selectedMethod =
      (widget.initialMethod ?? widget.order.paymentMethod)
                  .trim()
                  .toLowerCase() ==
              'vnpay'
          ? 'VNPay'
          : 'VietQR';

  bool _isLoadingSession = true;
  bool _isSubmitting = false;
  String? _loadError;

  VietQrSession? _vietQrSession;
  VnPaySession? _vnPaySession;
  PaymentResult? _paymentResult;

  @override
  void initState() {
    super.initState();
    _initPaymentSession();
  }

  Future<void> _initPaymentSession() async {
    setState(() {
      _isLoadingSession = true;
      _loadError = null;
      _paymentResult = null;
    });

    try {
      if (_selectedMethod == 'VNPay') {
        final session = await _repository.createVnPay(widget.order.id);
        if (!mounted) return;
        setState(() => _vnPaySession = session);
      } else {
        final session = await _repository.createVietQr(widget.order.id);
        if (!mounted) return;
        setState(() => _vietQrSession = session);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.displayMessage);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _loadError =
            'Không thể khởi tạo phiên thanh toán. Vui lòng kiểm tra kết nối mạng.',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingSession = false);
      }
    }
  }

  void _switchMethod(String method) {
    if (_selectedMethod == method || _isSubmitting) return;
    setState(() => _selectedMethod = method);
    _initPaymentSession();
  }

  Future<void> _completePayment({required bool simulateFailure}) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      PaymentResult result;
      if (_selectedMethod == 'VNPay' && _vnPaySession != null) {
        final url = simulateFailure
            ? _vnPaySession!.callbackCancelUrl
            : _vnPaySession!.callbackSuccessUrl;
        result = await _repository.verifyVnPayCallbackUrl(url);
      } else {
        result = await _repository.confirmPayment(
          orderId: widget.order.id,
          provider: _selectedMethod,
          simulateFailure: simulateFailure,
        );
      }

      if (!mounted) return;
      setState(() => _paymentResult = result);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(e.displayMessage),
            backgroundColor: const Color(0xffef4444),
          ),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Xác thực giao dịch thất bại. Vui lòng thử lại.'),
            backgroundColor: Color(0xffef4444),
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _copyText(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Đã sao chép $label')));
  }

  Widget _buildMethodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xfff1f5f9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _MethodTab(
              tabKey: const ValueKey('payment-tab-vietqr'),
              label: 'Chuyển khoản VietQR',
              icon: Icons.qr_code_scanner_rounded,
              selected: _selectedMethod == 'VietQR',
              onTap: () => _switchMethod('VietQR'),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _MethodTab(
              tabKey: const ValueKey('payment-tab-vnpay'),
              label: 'Cổng VNPay',
              icon: Icons.account_balance_wallet_outlined,
              selected: _selectedMethod == 'VNPay',
              onTap: () => _switchMethod('VNPay'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVietQrView(VietQrSession session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xffdfedf8)),
          ),
          child: Column(
            children: [
              const Text(
                'Quét mã QR bằng ứng dụng Ngân hàng',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xffe2e8f0)),
                ),
                child: SizedBox.square(
                  dimension: 210,
                  child: QrImageView(
                    key: const ValueKey('vietqr-code-widget'),
                    data: session.qrData,
                    backgroundColor: Colors.white,
                    semanticsLabel: 'Mã thanh toán VietQR ${session.txnRef}',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _InfoLine(label: 'Ngân hàng', value: session.bankName),
              _InfoLine(
                label: 'Số tài khoản',
                value: session.accountNo,
                onCopy: () => _copyText(session.accountNo, 'số tài khoản'),
              ),
              _InfoLine(label: 'Chủ tài khoản', value: session.accountName),
              _InfoLine(
                label: 'Số tiền',
                value: session.amountFormatted,
                highlight: true,
              ),
              _InfoLine(
                label: 'Nội dung CK',
                value: session.transferContent,
                onCopy: () =>
                    _copyText(session.transferContent, 'nội dung chuyển khoản'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const ValueKey('payment-confirm-success-btn'),
          onPressed: _isSubmitting
              ? null
              : () => _completePayment(simulateFailure: false),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: AppColors.primary,
          ),
          icon: const Icon(Icons.check_circle_outline_rounded),
          label: Text(
            _isSubmitting
                ? 'Đang xác thực giao dịch...'
                : 'Tôi đã chuyển khoản thành công',
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          key: const ValueKey('payment-simulate-fail-btn'),
          onPressed: _isSubmitting
              ? null
              : () => _completePayment(simulateFailure: true),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
          ),
          child: const Text('Hủy giao dịch / Chưa thanh toán'),
        ),
      ],
    );
  }

  Widget _buildVnPayView(VnPaySession session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xffdfedf8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.light,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.verified_user_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cổng thanh toán VNPay Sandbox',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Xác thực chữ ký số chuẩn HMAC-SHA512',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _InfoLine(label: 'Mã đơn khám', value: '#${session.orderId}'),
              _InfoLine(label: 'Mã tham chiếu', value: session.txnRef),
              _InfoLine(
                label: 'Số tiền thanh toán',
                value: session.amountFormatted,
                highlight: true,
              ),
              _InfoLine(label: 'Ngân hàng thử nghiệm', value: 'NCB Sandbox'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xfff8fafc),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xffe2e8f0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        session.paymentUrl,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Sao chép liên kết VNPay',
                      onPressed: () =>
                          _copyText(session.paymentUrl, 'liên kết VNPay'),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const ValueKey('payment-confirm-success-btn'),
          onPressed: _isSubmitting
              ? null
              : () => _completePayment(simulateFailure: false),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: AppColors.primary,
          ),
          icon: const Icon(Icons.lock_open_rounded),
          label: Text(
            _isSubmitting
                ? 'Đang xử lý callback VNPay...'
                : 'Xác nhận thanh toán qua VNPay',
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          key: const ValueKey('payment-simulate-fail-btn'),
          onPressed: _isSubmitting
              ? null
              : () => _completePayment(simulateFailure: true),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
          ),
          child: const Text('Hủy giao dịch VNPay'),
        ),
      ],
    );
  }

  Widget _buildResultView(PaymentResult result) {
    final isSuccess = result.success;
    final accentColor = isSuccess
        ? const Color(0xff10b981)
        : const Color(0xffef4444);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xffdfedf8)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSuccess
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    size: 44,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isSuccess
                      ? 'Thanh toán thành công!'
                      : 'Thanh toán chưa hoàn tất',
                  key: const ValueKey('payment-result-title'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  result.message,
                  style: const TextStyle(fontSize: 14, color: AppColors.muted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _InfoLine(label: 'Mã đơn đặt lịch', value: '#${result.orderId}'),
                _InfoLine(label: 'Phương thức', value: result.paymentMethod),
                _InfoLine(
                  label: 'Số tiền',
                  value: widget.order.totalAmountFormatted,
                  highlight: true,
                ),
                if (result.transactionId != null &&
                    result.transactionId!.isNotEmpty)
                  _InfoLine(
                    label: 'Mã giao dịch',
                    value: result.transactionId!,
                  ),
                const SizedBox(height: 20),
                if (isSuccess)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('payment-done-return-btn'),
                      onPressed: () => Navigator.of(context).pop(result),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Hoàn tất & Xem phiếu khám'),
                    ),
                  )
                else ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('payment-retry-btn'),
                      onPressed: _initPaymentSession,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Thử thanh toán lại'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      child: const Text('Quay lại phiếu khám'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Thanh toán Đơn #${widget.order.id}'),
      ),
      body: SafeArea(
        child: _paymentResult != null
            ? _buildResultView(_paymentResult!)
            : _isLoadingSession
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_loadError!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _initPaymentSession,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildMethodSelector(),
                      const SizedBox(height: 16),
                      if (_selectedMethod == 'VNPay' && _vnPaySession != null)
                        _buildVnPayView(_vnPaySession!)
                      else if (_vietQrSession != null)
                        _buildVietQrView(_vietQrSession!),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _MethodTab extends StatelessWidget {
  const _MethodTab({
    required this.tabKey,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final Key tabKey;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        key: tabKey,
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? AppColors.primary : AppColors.muted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? AppColors.primary : AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
    this.highlight = false,
    this.onCopy,
  });

  final String label;
  final String value;
  final bool highlight;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13.5, color: AppColors.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: highlight ? 16 : 13.5,
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                color: highlight ? AppColors.primary : AppColors.text,
              ),
            ),
          ),
          if (onCopy != null) ...[
            const SizedBox(width: 4),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onCopy,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

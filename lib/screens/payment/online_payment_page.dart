import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../models/order.dart';
import '../../models/payment_models.dart';
import '../../repositories/payment_repository.dart';

enum _VnPayStep { cardInput, otpVerify }

class _VnPayBankOption {
  const _VnPayBankOption({required this.code, required this.name});

  final String code;
  final String name;
}

class OnlinePaymentPage extends StatefulWidget {
  const OnlinePaymentPage({
    super.key,
    required this.order,
    required this.method,
    this.repository,
  });

  final Order order;
  final String method;
  final PaymentRepository? repository;

  @override
  State<OnlinePaymentPage> createState() => _OnlinePaymentPageState();
}

class _OnlinePaymentPageState extends State<OnlinePaymentPage> {
  static const List<_VnPayBankOption> _banks = [
    _VnPayBankOption(code: 'NCB', name: 'Ngân hàng Quốc Dân (NCB)'),
    _VnPayBankOption(code: 'VCB', name: 'Vietcombank'),
    _VnPayBankOption(code: 'BIDV', name: 'BIDV'),
    _VnPayBankOption(code: 'CTG', name: 'VietinBank'),
    _VnPayBankOption(code: 'MB', name: 'MB Bank'),
  ];

  late final PaymentRepository _repository =
      widget.repository ?? PaymentRepository();

  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cardHolderController = TextEditingController();
  final TextEditingController _issueDateController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _isLoadingSession = true;
  bool _isSubmitting = false;
  String? _loadError;

  VnPaySession? _vnPaySession;
  PaymentResult? _paymentResult;
  _VnPayStep _step = _VnPayStep.cardInput;
  String _selectedBankCode = 'NCB';

  String? _cardNumberError;
  String? _cardHolderError;
  String? _issueDateError;
  String? _otpError;

  @override
  void initState() {
    super.initState();
    _initPaymentSession();
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _issueDateController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _initPaymentSession() async {
    setState(() {
      _isLoadingSession = true;
      _loadError = null;
      _paymentResult = null;
      _step = _VnPayStep.cardInput;
      _otpController.clear();
      _otpError = null;
    });

    try {
      final session = await _repository.createVnPay(widget.order.id);
      if (!mounted) return;
      setState(() => _vnPaySession = session);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.displayMessage);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _loadError =
            'Không thể khởi tạo phiên thanh toán VNPay. Vui lòng kiểm tra kết nối mạng.',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingSession = false);
      }
    }
  }

  String get _digitsOnlyCardNumber =>
      _cardNumberController.text.replaceAll(RegExp(r'\D'), '');

  String get _maskedCardNumber {
    final digits = _digitsOnlyCardNumber;
    if (digits.length < 8) return digits;
    final prefix = digits.substring(0, 4);
    final suffix = digits.substring(digits.length - 4);
    return '$prefix **** **** $suffix';
  }

  String get _selectedBankName {
    for (final bank in _banks) {
      if (bank.code == _selectedBankCode) return bank.name;
    }
    return _selectedBankCode;
  }

  void _fillSandboxSampleCard() {
    setState(() {
      _selectedBankCode = 'NCB';
      _cardNumberController.text = '9704198526191432198';
      _cardHolderController.text = 'NGUYEN VAN A';
      _issueDateController.text = '07/15';
      _cardNumberError = null;
      _cardHolderError = null;
      _issueDateError = null;
    });
  }

  void _continueToOtpStep() {
    FocusScope.of(context).unfocus();

    final digits = _digitsOnlyCardNumber;
    final holder = _cardHolderController.text.trim().toUpperCase();
    final issueDate = _issueDateController.text.trim();

    String? cardErr;
    String? holderErr;
    String? dateErr;

    if (digits.length < 16 || digits.length > 19) {
      cardErr = 'Vui lòng nhập số thẻ ATM hợp lệ (từ 16 đến 19 chữ số).';
    }

    if (holder.length < 3) {
      holderErr = 'Vui lòng nhập họ tên chủ thẻ (in hoa không dấu).';
    }

    final issueMatch = RegExp(r'^(0[1-9]|1[0-2])\/(\d{2})$').firstMatch(
      issueDate,
    );
    if (issueMatch == null) {
      dateErr = 'Ngày phát hành không hợp lệ (định dạng MM/YY, ví dụ 07/15).';
    }

    setState(() {
      _cardNumberError = cardErr;
      _cardHolderError = holderErr;
      _issueDateError = dateErr;
    });

    if (cardErr != null || holderErr != null || dateErr != null) {
      return;
    }

    _cardHolderController.text = holder;
    setState(() {
      _otpController.clear();
      _otpError = null;
      _step = _VnPayStep.otpVerify;
    });
  }

  Future<void> _submitOtpAndPay() async {
    if (_isSubmitting || _vnPaySession == null) return;
    FocusScope.of(context).unfocus();

    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _otpError = 'Vui lòng nhập đủ 6 chữ số mã OTP.');
      return;
    }
    if (otp != '123456') {
      setState(
        () => _otpError =
            'Mã OTP không chính xác! (Mã thử nghiệm VNPay Sandbox: 123456)',
      );
      return;
    }

    setState(() {
      _otpError = null;
      _isSubmitting = true;
    });

    await _executeCallback(simulateFailure: false);
  }

  Future<void> _cancelPayment() async {
    if (_isSubmitting || _vnPaySession == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);
    await _executeCallback(simulateFailure: true);
  }

  Future<void> _executeCallback({required bool simulateFailure}) async {
    try {
      final session = _vnPaySession!;
      final url = simulateFailure
          ? session.callbackCancelUrl
          : session.callbackSuccessUrl;
      final result = await _repository.verifyVnPayCallbackUrl(url);
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

  Widget _buildGatewaySummaryCard(VnPaySession session) {
    return Container(
      padding: const EdgeInsets.all(18),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xfff1f5f9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xffe2e8f0)),
                ),
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                    children: [
                      TextSpan(
                        text: 'VN',
                        style: TextStyle(color: Color(0xffdc2626)),
                      ),
                      TextSpan(
                        text: 'PAY',
                        style: TextStyle(color: Color(0xff005baa)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cổng thanh toán VNPay',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Thẻ nội địa & Tài khoản ngân hàng · HMAC-SHA512',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          const _InfoLine(
            label: 'Đơn vị thụ hưởng',
            value: 'TRUNG TÂM Y TẾ HIỆP PHƯỚC',
          ),
          _InfoLine(label: 'Mã đơn khám', value: '#${session.orderId}'),
          _InfoLine(label: 'Mã tham chiếu', value: session.txnRef),
          _InfoLine(
            label: 'Số tiền thanh toán',
            value: session.amountFormatted,
            highlight: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCardInputStep(VnPaySession session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildGatewaySummaryCard(session),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xffdfedf8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '1. Chọn ngân hàng nội địa',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final bank in _banks)
                    ChoiceChip(
                      key: ValueKey('vnpay-bank-${bank.code}'),
                      label: Text(bank.code),
                      selected: _selectedBankCode == bank.code,
                      onSelected: _isSubmitting
                          ? null
                          : (_) => setState(() => _selectedBankCode = bank.code),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Đang chọn: $_selectedBankName',
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '2. Nhập thông tin thẻ ATM',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('vnpay-fill-sample-btn'),
                    onPressed: _isSubmitting ? null : _fillSandboxSampleCard,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.bolt_rounded, size: 16),
                    label: const Text(
                      'Thẻ mẫu Sandbox',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('vnpay-card-number-field'),
                controller: _cardNumberController,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(19),
                ],
                onChanged: (_) {
                  if (_cardNumberError != null) {
                    setState(() => _cardNumberError = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Số thẻ ATM nội địa *',
                  hintText: 'Nhập 16 - 19 chữ số trên mặt thẻ...',
                  prefixIcon: const Icon(Icons.credit_card_rounded),
                  errorText: _cardNumberError,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('vnpay-card-holder-field'),
                controller: _cardHolderController,
                enabled: !_isSubmitting,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) {
                  if (_cardHolderError != null) {
                    setState(() => _cardHolderError = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Tên chủ thẻ (không dấu) *',
                  hintText: 'VD: NGUYEN VAN A',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  errorText: _cardHolderError,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('vnpay-issue-date-field'),
                controller: _issueDateController,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.number,
                inputFormatters: [_MmYyInputFormatter()],
                onChanged: (_) {
                  if (_issueDateError != null) {
                    setState(() => _issueDateError = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Ngày phát hành (MM/YY) *',
                  hintText: 'VD: 07/15',
                  prefixIcon: const Icon(Icons.calendar_month_outlined),
                  errorText: _issueDateError,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xfff8fafc),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xffe2e8f0)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Thẻ test VNPay Sandbox: Số thẻ 9704198526191432198 · Chủ thẻ NGUYEN VAN A · Ngày phát hành 07/15 · OTP 123456',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const ValueKey('vnpay-card-continue-btn'),
          onPressed: _isSubmitting ? null : _continueToOtpStep,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: AppColors.primary,
          ),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Tiếp tục xác thực OTP'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          key: const ValueKey('payment-simulate-fail-btn'),
          onPressed: _isSubmitting ? null : _cancelPayment,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
          ),
          child: const Text('Hủy giao dịch VNPay'),
        ),
      ],
    );
  }

  Widget _buildOtpVerifyStep(VnPaySession session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildGatewaySummaryCard(session),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xffdfedf8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Xác thực giao dịch (OTP)',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Nhập mã xác thực OTP gồm 6 chữ số do $_selectedBankName gửi đến số điện thoại chủ thẻ.',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xfff8fafc),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xffe2e8f0)),
                ),
                child: Column(
                  children: [
                    _InfoLine(label: 'Ngân hàng', value: _selectedBankName),
                    _InfoLine(label: 'Số thẻ', value: _maskedCardNumber),
                    _InfoLine(
                      label: 'Chủ thẻ',
                      value: _cardHolderController.text.trim(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('vnpay-otp-field'),
                controller: _otpController,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 6,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                onChanged: (_) {
                  if (_otpError != null) {
                    setState(() => _otpError = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Mã OTP xác thực (6 chữ số) *',
                  hintText: '123456',
                  hintStyle: const TextStyle(
                    letterSpacing: 4,
                    color: Color(0xffcbd5e1),
                  ),
                  prefixIcon: const Icon(Icons.shield_outlined),
                  errorText: _otpError,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Môi trường thử nghiệm VNPay Sandbox: nhập mã OTP 123456 để hoàn tất.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const ValueKey('payment-confirm-success-btn'),
          onPressed: _isSubmitting ? null : _submitOtpAndPay,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: AppColors.primary,
          ),
          icon: const Icon(Icons.verified_user_outlined),
          label: Text(
            _isSubmitting
                ? 'Đang xác thực chữ ký VNPay...'
                : 'Xác nhận thanh toán',
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('vnpay-back-to-card-btn'),
                onPressed: _isSubmitting
                    ? null
                    : () => setState(() => _step = _VnPayStep.cardInput),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
                child: const Text('Sửa thông tin thẻ'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('payment-simulate-fail-btn'),
                onPressed: _isSubmitting ? null : _cancelPayment,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  foregroundColor: const Color(0xffef4444),
                ),
                child: const Text('Hủy giao dịch'),
              ),
            ),
          ],
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
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
                _InfoLine(
                  label: 'Mã đơn đặt lịch',
                  value: '#${result.orderId}',
                ),
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
        title: Text('Thanh toán VNPay · Đơn #${widget.order.id}'),
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
                      if (_vnPaySession != null)
                        _step == _VnPayStep.cardInput
                            ? _buildCardInputStep(_vnPaySession!)
                            : _buildOtpVerifyStep(_vnPaySession!),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _MmYyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final clipped = digits.length > 4 ? digits.substring(0, 4) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < clipped.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(clipped[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13.5, color: AppColors.muted),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: highlight ? 15.5 : 13.5,
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                color: highlight ? AppColors.primary : AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/community_logo.dart';
import '../../helpers/form_validators.dart';
import '../../models/auth_models.dart';
import '../../repositories/auth_repository.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({
    super.key,
    required this.email,
    this.initialDevOtp,
    this.authRepository,
  });

  final String email;
  final String? initialDevOtp;
  final AuthRepository? authRepository;

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();

  late final AuthRepository _authRepo =
      widget.authRepository ?? AuthRepository();

  bool _isLoading = false;
  late String? _devOtpHint = widget.initialDevOtp;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authRepo.verifyEmailRequest(
        VerifyEmailRequest(
          email: widget.email.trim(),
          otp: _otpController.text.trim(),
        ),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Xác thực email thành công! Tài khoản đã được kích hoạt, hãy đăng nhập.',
            ),
            backgroundColor: Color(0xff10b981),
            behavior: SnackBarBehavior.floating,
          ),
        );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: const Color(0xffef4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _isLoading = true);

    try {
      final result = await _authRepo.resendVerificationOtpRequest(widget.email);
      if (!mounted) {
        return;
      }

      setState(() => _devOtpHint = result.devOtp);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: const Color(0xff10b981),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: const Color(0xffef4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.text,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ),
                const Center(child: CommunityLogo(size: 64)),
                const SizedBox(height: 14),
                const Text(
                  'Y TẾ HIỆP PHƯỚC',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Hệ thống đặt lịch khám bệnh thông minh',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Xác Thực Email',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Nhập mã OTP 6 chữ số đã gửi tới ${widget.email}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.muted,
                    height: 1.4,
                  ),
                ),
                if (_devOtpHint != null && _devOtpHint!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    key: const ValueKey('verify-email-dev-otp-box'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.light,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xffbfdbfe)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Mã OTP thử nghiệm: $_devOtpHint',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                TextFormField(
                  key: const ValueKey('verify-email-otp-field'),
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'Mã OTP (6 chữ số)',
                    hintText: 'Nhập mã 6 số từ email',
                    counterText: '',
                    prefixIcon: const Icon(
                      Icons.mark_email_read_outlined,
                      color: AppColors.primary,
                    ),
                    filled: true,
                    fillColor: const Color(0xfff8fafc),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.8,
                      ),
                    ),
                  ),
                  validator: FormValidators.validateOtp6,
                ),
                const SizedBox(height: 24),
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xff349ff0), Color(0xff2369d5)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xff2369d5).withValues(alpha: 0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: const ValueKey('verify-email-submit-btn'),
                      borderRadius: BorderRadius.circular(14),
                      onTap: _isLoading ? null : _verifyEmail,
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'XÁC THỰC TÀI KHOẢN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    key: const ValueKey('verify-email-resend-btn'),
                    onPressed: _isLoading ? null : _resendOtp,
                    child: const Text('Không nhận được mã? Gửi lại OTP'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

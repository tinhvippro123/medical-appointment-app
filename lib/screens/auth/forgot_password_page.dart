import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/community_logo.dart';
import '../../helpers/form_validators.dart';
import '../../models/auth_models.dart';
import '../../repositories/auth_repository.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.authRepository});

  final AuthRepository? authRepository;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late final AuthRepository _authRepo =
      widget.authRepository ?? AuthRepository();

  bool _isOtpStep = false;
  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _devOtpHint;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_isOtpStep) {
      final emailError = FormValidators.validateRequiredEmail(
        _emailController.text,
      );
      if (emailError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(emailError),
            backgroundColor: const Color(0xffef4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    } else if (!_emailFormKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _authRepo.forgotPasswordRequest(
        ForgotPasswordRequest(email: _emailController.text.trim()),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isOtpStep = true;
        _devOtpHint = result.devOtp;
      });

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
      ScaffoldMessenger.of(context).showSnackBar(
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

  Future<void> _resetPassword() async {
    if (!_resetFormKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authRepo.resetPasswordRequest(
        ResetPasswordRequest(
          email: _emailController.text.trim(),
          otp: _otpController.text.trim(),
          newPassword: _newPasswordController.text,
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
              'Đặt lại mật khẩu thành công! Vui lòng đăng nhập bằng mật khẩu mới.',
            ),
            backgroundColor: Color(0xff10b981),
            behavior: SnackBarBehavior.floating,
          ),
        );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
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

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.primary),
      suffixIcon: suffixIcon,
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
        borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required Key buttonKey,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: buttonKey,
          borderRadius: BorderRadius.circular(14),
          onTap: _isLoading ? null : onPressed,
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
                : Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStep() {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Quên Mật Khẩu',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Nhập địa chỉ email gắn với tài khoản để nhận mã xác thực 6 chữ số',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 24),
          TextFormField(
            key: const ValueKey('forgot-password-email-field'),
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDecoration(
              label: 'Địa chỉ Email',
              hint: 'Ví dụ: benhnhan@gmail.com',
              icon: Icons.email_outlined,
            ),
            validator: FormValidators.validateRequiredEmail,
          ),
          const SizedBox(height: 24),
          _buildPrimaryButton(
            buttonKey: const ValueKey('forgot-password-send-otp-btn'),
            label: 'GỬI MÃ OTP',
            onPressed: _sendOtp,
          ),
        ],
      ),
    );
  }

  Widget _buildResetStep() {
    return Form(
      key: _resetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Đặt Lại Mật Khẩu',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Mã xác thực đã gửi tới ${_emailController.text.trim()}',
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
              key: const ValueKey('forgot-password-dev-otp-box'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
          const SizedBox(height: 20),
          TextFormField(
            key: const ValueKey('forgot-password-otp-field'),
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: _inputDecoration(
              label: 'Mã OTP (6 chữ số)',
              hint: 'Nhập mã 6 số từ email',
              icon: Icons.pin_outlined,
            ).copyWith(counterText: ''),
            validator: FormValidators.validateOtp6,
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('forgot-password-new-password-field'),
            controller: _newPasswordController,
            obscureText: _obscureNewPassword,
            decoration: _inputDecoration(
              label: 'Mật khẩu mới',
              hint: 'Từ 6 đến 50 ký tự',
              icon: Icons.lock_outline_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNewPassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: AppColors.muted,
                ),
                onPressed: () => setState(
                  () => _obscureNewPassword = !_obscureNewPassword,
                ),
              ),
            ),
            validator: (v) =>
                FormValidators.validatePassword(v, label: 'Mật khẩu mới'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('forgot-password-confirm-password-field'),
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: _inputDecoration(
              label: 'Xác nhận mật khẩu mới',
              icon: Icons.lock_reset_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: AppColors.muted,
                ),
                onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                ),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'Vui lòng xác nhận mật khẩu mới';
              }
              if (v != _newPasswordController.text) {
                return 'Mật khẩu xác nhận không khớp';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          _buildPrimaryButton(
            buttonKey: const ValueKey('forgot-password-submit-reset-btn'),
            label: 'ĐẶT LẠI MẬT KHẨU',
            onPressed: _resetPassword,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                key: const ValueKey('forgot-password-change-email-btn'),
                onPressed: _isLoading
                    ? null
                    : () => setState(() {
                        _isOtpStep = false;
                        _otpController.clear();
                      }),
                child: const Text('Đổi email khác'),
              ),
              TextButton(
                key: const ValueKey('forgot-password-resend-otp-btn'),
                onPressed: _isLoading ? null : _sendOtp,
                child: const Text('Gửi lại mã OTP'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
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
                  onPressed: () => Navigator.pop(context),
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
              if (_isOtpStep) _buildResetStep() else _buildEmailStep(),
            ],
          ),
        ),
      ),
    );
  }
}

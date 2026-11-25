import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/community_logo.dart';
import '../../helpers/form_validators.dart';
import '../../helpers/session_helper.dart';
import '../../models/auth_models.dart';
import '../../repositories/auth_repository.dart';
import '../admin/admin_dashboard_page.dart';
import '../home/home_page.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.authRepository});

  final AuthRepository? authRepository;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  late final AuthRepository _authRepo =
      widget.authRepository ?? AuthRepository();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final request = LoginRequest(
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
      );

      final user = await _authRepo.loginRequest(request);
      final isAdmin = user?.isAdmin ?? await SessionHepler.isAdmin();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAdmin
                ? 'Đăng nhập thành công! Chào mừng Quản trị viên.'
                : 'Đăng nhập thành công! Chào mừng bạn.',
          ),
          backgroundColor: const Color(0xff10b981),
          behavior: SnackBarBehavior.floating,
        ),
      );

      final destination = isAdmin
          ? AdminDashboardPage(currentUser: user, authRepository: _authRepo)
          : const HomePage();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => destination),
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

  Future<void> _openSocialLogin(String provider) async {
    if (_isLoading) return;
    final result = await showDialog<SocialLoginResult>(
      context: context,
      builder: (_) => _SocialLoginDialog(
        provider: provider,
        authRepository: _authRepo,
      ),
    );

    if (result == null || !mounted) return;

    final user = await SessionHepler.getCurrentUser();
    final isAdmin = user?.isAdmin ?? await SessionHepler.isAdmin();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: const Color(0xff10b981),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final destination = isAdmin
        ? AdminDashboardPage(currentUser: user, authRepository: _authRepo)
        : const HomePage();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 24.0,
            vertical: 20.0,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
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
                  'Đăng Nhập',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Vui lòng nhập số điện thoại để tiếp tục',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                const SizedBox(height: 22),

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Số điện thoại',
                    hintText: 'Ví dụ: 0912345678',
                    prefixIcon: const Icon(
                      Icons.phone_iphone_rounded,
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
                  validator: FormValidators.validatePhone,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    hintText: 'Nhập mật khẩu của bạn',
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.primary,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: AppColors.muted,
                      ),
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
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
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Vui lòng nhập mật khẩu';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    key: const ValueKey('login-forgot-password-link'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ForgotPasswordPage(
                            authRepository: _authRepo,
                          ),
                        ),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Quên mật khẩu?',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

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
                      borderRadius: BorderRadius.circular(14),
                      onTap: _isLoading ? null : _login,
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
                                'ĐĂNG NHẬP',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade200)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Hoặc đăng nhập bằng',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade200)),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _SocialButton(
                        buttonKey: const ValueKey('social-login-google-btn'),
                        label: 'Gmail',
                        badgeText: 'G',
                        badgeBg: const Color(0xfffee2e2),
                        badgeFg: const Color(0xffea4335),
                        onTap: () => _openSocialLogin('Google'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SocialButton(
                        buttonKey: const ValueKey('social-login-facebook-btn'),
                        label: 'Facebook',
                        badgeText: 'f',
                        badgeBg: const Color(0xff1877f2),
                        badgeFg: Colors.white,
                        onTap: () => _openSocialLogin('Facebook'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SocialButton(
                        buttonKey: const ValueKey('social-login-zalo-btn'),
                        label: 'Zalo',
                        badgeText: 'Z',
                        badgeBg: const Color(0xff0068ff),
                        badgeFg: Colors.white,
                        onTap: () => _openSocialLogin('Zalo'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    const Text(
                      'Chưa có tài khoản? ',
                      style: TextStyle(color: AppColors.muted, fontSize: 14),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterPage(),
                          ),
                        );
                      },
                      child: const Text(
                        'Đăng ký ngay',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.buttonKey,
    required this.label,
    required this.badgeText,
    required this.badgeBg,
    required this.badgeFg,
    required this.onTap,
  });

  final Key buttonKey;
  final String label;
  final String badgeText;
  final Color badgeBg;
  final Color badgeFg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: buttonKey,
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
        side: const BorderSide(color: Color(0xffe2e8f0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xfff8fafc),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: badgeBg,
                shape: BoxShape.circle,
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  color: badgeFg,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialLoginDialog extends StatefulWidget {
  const _SocialLoginDialog({
    required this.provider,
    required this.authRepository,
  });

  final String provider;
  final AuthRepository authRepository;

  @override
  State<_SocialLoginDialog> createState() => _SocialLoginDialogState();
}

class _SocialLoginDialogState extends State<_SocialLoginDialog> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  bool _submitting = false;
  String? _errorText;

  bool get _isZalo => widget.provider == 'Zalo';
  bool get _isGoogle => widget.provider == 'Google';

  Color get _brandColor => switch (widget.provider) {
    'Google' => const Color(0xffea4335),
    'Facebook' => const Color(0xff1877f2),
    _ => const Color(0xff0068ff),
  };

  String get _dialogTitle => switch (widget.provider) {
    'Google' => 'Đăng nhập bằng Gmail',
    'Facebook' => 'Đăng nhập với Facebook',
    _ => 'Đăng nhập qua Zalo',
  };

  @override
  void dispose() {
    _identifierController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final identifier = _identifierController.text.trim();
    final fullName = _nameController.text.trim();

    if (identifier.isEmpty) {
      setState(() {
        _errorText = _isZalo
            ? 'Vui lòng nhập số điện thoại Zalo.'
            : 'Vui lòng nhập địa chỉ email tài khoản ${widget.provider}.';
      });
      return;
    }

    if (_isZalo) {
      if (!RegExp(r'^0\d{9}$').hasMatch(identifier)) {
        setState(() {
          _errorText = 'Số điện thoại Zalo phải gồm 10 chữ số bắt đầu bằng 0.';
        });
        return;
      }
    } else {
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(identifier)) {
        setState(() {
          _errorText = 'Vui lòng nhập địa chỉ email hợp lệ.';
        });
        return;
      }
    }

    if (fullName.length < 2) {
      setState(() => _errorText = 'Vui lòng nhập tên hiển thị (từ 2 ký tự).');
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    final prefix = _isGoogle
        ? 'gg'
        : _isZalo
        ? 'zl'
        : 'fb';

    try {
      final res = await widget.authRepository.socialLoginRequest(
        SocialLoginRequest(
          provider: widget.provider,
          providerUserId: '${prefix}_${identifier.toLowerCase()}',
          fullName: fullName,
          email: _isZalo ? null : identifier.toLowerCase(),
          phone: _isZalo ? identifier : null,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(res);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorText = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: _brandColor.withValues(alpha: 0.14),
                    child: Text(
                      _isGoogle ? 'G' : (_isZalo ? 'Z' : 'f'),
                      style: TextStyle(
                        color: _brandColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _dialogTitle,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _isZalo
                    ? 'Xác nhận tài khoản Zalo để liên kết và đăng nhập vào Y tế Hiệp Phước.'
                    : 'Chọn tài khoản ${widget.provider} để đăng nhập nhanh vào Y tế Hiệp Phước.',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('social-identifier-field'),
                controller: _identifierController,
                enabled: !_submitting,
                keyboardType: _isZalo
                    ? TextInputType.phone
                    : TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: _isZalo
                      ? 'Số điện thoại Zalo *'
                      : (_isGoogle
                            ? 'Địa chỉ Gmail *'
                            : 'Email tài khoản Facebook *'),
                  hintText: _isZalo
                      ? 'VD: 0987654321'
                      : 'VD: benhnhan@gmail.com',
                  prefixIcon: Icon(
                    _isZalo
                        ? Icons.phone_android_rounded
                        : Icons.alternate_email_rounded,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('social-fullname-field'),
                controller: _nameController,
                enabled: !_submitting,
                decoration: const InputDecoration(
                  labelText: 'Tên hiển thị *',
                  hintText: 'VD: Nguyễn Minh An',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorText!,
                  style: const TextStyle(
                    color: Color(0xffdc2626),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                key: const ValueKey('social-confirm-submit-btn'),
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: _brandColor,
                  minimumSize: const Size.fromHeight(46),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text('Tiếp tục với ${widget.provider}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

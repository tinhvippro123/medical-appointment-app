import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/community_logo.dart';
import '../../helpers/form_validators.dart';
import '../../helpers/session_helper.dart';
import '../../models/auth_models.dart';
import '../../repositories/auth_repository.dart';
import '../../services/social_auth_service.dart';
import '../admin/admin_dashboard_page.dart';
import '../home/home_page.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.authRepository,
    this.socialAuthGateway,
  });

  final AuthRepository? authRepository;
  final SocialAuthGateway? socialAuthGateway;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  late final AuthRepository _authRepo =
      widget.authRepository ?? AuthRepository();
  late final SocialAuthGateway _socialGateway =
      widget.socialAuthGateway ?? const NativeSocialAuthGateway();

  bool _isLoading = false;
  String? _loadingSocialProvider;
  bool _obscurePassword = true;

  bool get _isBusy => _isLoading || _loadingSocialProvider != null;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    if (_isBusy || !_formKey.currentState!.validate()) {
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

  Future<void> _handleSocialLogin(String provider) async {
    if (_isBusy) return;
    setState(() => _loadingSocialProvider = provider);

    try {
      final socialRequest = await _socialGateway.authenticate(provider);
      if (socialRequest == null || !mounted) {
        return;
      }

      final result = await _authRepo.socialLoginRequest(socialRequest);
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: const Color(0xffef4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingSocialProvider = null);
      }
    }
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
                  validator: FormValidators.validatePassword,
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
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _isBusy ? null : _login,
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
                        loading: _loadingSocialProvider == 'Google',
                        enabled: !_isBusy,
                        onTap: () => _handleSocialLogin('Google'),
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
                        loading: _loadingSocialProvider == 'Facebook',
                        enabled: !_isBusy,
                        onTap: () => _handleSocialLogin('Facebook'),
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
                        loading: _loadingSocialProvider == 'Zalo',
                        enabled: !_isBusy,
                        onTap: () => _handleSocialLogin('Zalo'),
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
                      onTap: _isBusy
                          ? null
                          : () {
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
    required this.loading,
    required this.enabled,
    required this.onTap,
  });

  final Key buttonKey;
  final String label;
  final String badgeText;
  final Color badgeBg;
  final Color badgeFg;
  final bool loading;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: buttonKey,
      onPressed: enabled ? onTap : null,
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
            if (loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
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

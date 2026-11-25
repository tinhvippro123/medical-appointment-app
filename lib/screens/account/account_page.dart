import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/community_logo.dart';
import '../../helpers/session_helper.dart';
import '../../models/auth_models.dart';
import '../../models/user_role_models.dart';
import '../../repositories/auth_repository.dart';
import '../admin/admin_dashboard_page.dart';
import '../auth/forgot_password_page.dart';
import '../auth/login_page.dart';
import 'change_password_page.dart';
import 'legal_document_page.dart';
import 'personal_info_page.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({
    super.key,
    this.currentUser,
    this.authRepository,
    this.onOpenHistory,
    this.onOpenBills,
  });

  final SessionUser? currentUser;
  final AuthRepository? authRepository;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenBills;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  static const String _notifPrefKey = 'pref_receive_notifications';

  late final AuthRepository _authRepo =
      widget.authRepository ?? AuthRepository();

  SessionUser? _user;
  bool _loading = true;
  bool _loggingOut = false;
  bool _receiveNotifications = true;
  String? _successBannerMessage;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _loadNotificationPref();
    if (widget.currentUser != null) {
      _user = widget.currentUser;
      _loading = false;
    } else {
      _loadUser();
    }
  }

  @override
  void didUpdateWidget(covariant AccountPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentUser != oldWidget.currentUser) {
      _user = widget.currentUser;
      _loading = false;
    }
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadNotificationPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _receiveNotifications = prefs.getBool(_notifPrefKey) ?? true;
    });
  }

  Future<void> _toggleNotification(bool value) async {
    setState(() => _receiveNotifications = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifPrefKey, value);
  }

  Future<void> _loadUser() async {
    final user = await SessionHepler.getCurrentUser();
    if (!mounted) {
      return;
    }
    setState(() {
      _user = user;
      _loading = false;
    });
  }

  void _showTopSuccessToast(String message) {
    _bannerTimer?.cancel();
    setState(() => _successBannerMessage = message);
    _bannerTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _successBannerMessage = null);
      }
    });
  }

  Future<void> _openPersonalInfoWithPasswordCheck(SessionUser user) async {
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _PasswordVerifyDialog(authRepository: _authRepo),
    );

    if (verified != true || !mounted) {
      return;
    }

    final updatedProfile = await Navigator.of(context).push<MyProfile>(
      MaterialPageRoute(
        builder: (_) => PersonalInfoPage(
          initialUser: user,
          authRepository: _authRepo,
        ),
      ),
    );

    if (updatedProfile != null && mounted) {
      final refreshedUser = await SessionHepler.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _user = refreshedUser ??
            SessionUser(
              userId: updatedProfile.id,
              fullName: updatedProfile.fullName,
              phone: updatedProfile.phone,
              roleKey: updatedProfile.roleKey,
            );
      });
      _showTopSuccessToast('Cập nhật thông tin thành công.');
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất khỏi tài khoản này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _loggingOut = true);
    await _authRepo.logoutRequest(clearRemoteCart: false);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final user = _user;
    if (user == null) {
      return _buildGuestView();
    }

    final cleanName = user.fullName.trim();
    final maskedPhone = maskPhoneNumber(user.phone);

    return ColoredBox(
      color: const Color(0xfff4f7fb),
      child: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              _UmcCurvedHeader(
                fullName: cleanName,
                maskedPhone: maskedPhone,
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (user.isAdmin) ...[
                          _GroupCard(
                            children: [
                              _MenuRow(
                                icon: Icons.admin_panel_settings_rounded,
                                title: 'Mở trang Quản trị (Admin)',
                                onTap: () =>
                                    Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => AdminDashboardPage(
                                      currentUser: user,
                                      authRepository: _authRepo,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                        ],

                        const _GroupHeading('Tài khoản'),
                        const SizedBox(height: 8),
                        _GroupCard(
                          children: [
                            _MenuRow(
                              rowKey: const ValueKey('account-personal-info-row'),
                              icon: Icons.person_rounded,
                              title: 'Thông tin cá nhân',
                              onTap: () =>
                                  _openPersonalInfoWithPasswordCheck(user),
                            ),
                            const _MenuDivider(),
                            _MenuRow(
                              rowKey: const ValueKey('account-change-pw-row'),
                              icon: Icons.vpn_key_rounded,
                              title: 'Thay đổi mật khẩu',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChangePasswordPage(
                                    authRepository: _authRepo,
                                  ),
                                ),
                              ),
                            ),
                            const _MenuDivider(),
                            _MenuRow(
                              icon: Icons.assignment_ind_rounded,
                              title: 'Hồ sơ bệnh nhân',
                              onTap: () => Navigator.of(
                                context,
                              ).pushNamed('/patient-profiles'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        const _GroupHeading('Cài đặt'),
                        const SizedBox(height: 8),
                        _GroupCard(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  const _BlueIconBox(
                                    icon: Icons.notifications_rounded,
                                  ),
                                  const SizedBox(width: 14),
                                  const Expanded(
                                    child: Text(
                                      'Nhận thông báo',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.text,
                                      ),
                                    ),
                                  ),
                                  Switch(
                                    value: _receiveNotifications,
                                    activeThumbColor: const Color(0xff0b57d0),
                                    onChanged: _toggleNotification,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        const _GroupHeading('Thông tin pháp lý'),
                        const SizedBox(height: 8),
                        _GroupCard(
                          children: [
                            _MenuRow(
                              icon: Icons.description_rounded,
                              title: 'Điều khoản dịch vụ',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      LegalDocumentPage.termsOfService(),
                                ),
                              ),
                            ),
                            const _MenuDivider(),
                            _MenuRow(
                              icon: Icons.description_rounded,
                              title: 'Chính sách bảo mật',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      LegalDocumentPage.privacyPolicy(),
                                ),
                              ),
                            ),
                            const _MenuDivider(),
                            _MenuRow(
                              icon: Icons.description_rounded,
                              title: 'Quy định sử dụng',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      LegalDocumentPage.usageRules(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        const _GroupHeading('Ứng dụng'),
                        const SizedBox(height: 8),
                        const _GroupCard(
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  _BlueIconBox(
                                    icon: Icons.rocket_launch_outlined,
                                  ),
                                  SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      'Phiên bản',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.text,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'v1.0.0',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xff64748b),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        _GroupCard(
                          borderColor: const Color(0xfffde2e2),
                          children: [
                            InkWell(
                              key: const ValueKey('account-logout-row'),
                              onTap: _loggingOut ? null : _logout,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: const Color(0xfffee2e2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: _loggingOut
                                          ? const Padding(
                                              padding: EdgeInsets.all(10),
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Color(0xffef4444),
                                              ),
                                            )
                                          : const Icon(
                                              Icons.logout_rounded,
                                              size: 20,
                                              color: Color(0xffef4444),
                                            ),
                                    ),
                                    const SizedBox(width: 14),
                                    const Expanded(
                                      child: Text(
                                        'Đăng xuất',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.text,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Color(0xff94a3b8),
                                    ),
                                  ],
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
            ],
          ),

          // Thông báo nổi phía trên (giống ảnh 10 UMC Care)
          if (_successBannerMessage != null)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Material(
                      elevation: 6,
                      shadowColor: Colors.black26,
                      color: const Color(0xfff0fdf4),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        key: const ValueKey('account-top-success-banner'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xffbbf7d0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xffdcfce7),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Color(0xff16a34a),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Thông báo',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _successBannerMessage!,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      color: Color(0xff475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () =>
                                  setState(() => _successBannerMessage = null),
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: const BoxDecoration(
                                  color: Color(0xffe2e8f0),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 15,
                                  color: Color(0xff64748b),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGuestView() {
    return ColoredBox(
      color: const Color(0xfff4f7fb),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const _UmcCurvedHeader(
            fullName: 'Y tế Hiệp Phước',
            maskedPhone: 'Chưa đăng nhập tài khoản',
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Đăng nhập để quản lý thông tin cá nhân và lịch khám',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xff0b57d0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () =>
                              Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                            (route) => false,
                          ),
                          child: const Text(
                            'Đăng nhập ngay',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UmcCurvedHeader extends StatelessWidget {
  const _UmcCurvedHeader({
    required this.fullName,
    required this.maskedPhone,
  });

  final String fullName;
  final String maskedPhone;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff2c8cf4), Color(0xff0f62d6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -45,
            top: -35,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            right: -35,
            bottom: -45,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.24),
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CommunityLogo(size: 44),
                            SizedBox(height: 2),
                            Text(
                              'HIỆP PHƯỚC',
                              style: TextStyle(
                                fontSize: 7.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xff0f62d6),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (fullName.isNotEmpty) ...[
                      Text(
                        fullName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      maskedPhone,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xffe8f2ff),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordVerifyDialog extends StatefulWidget {
  const _PasswordVerifyDialog({required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<_PasswordVerifyDialog> createState() => _PasswordVerifyDialogState();
}

class _PasswordVerifyDialogState extends State<_PasswordVerifyDialog> {
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final pw = _passwordController.text;
    if (pw.isEmpty) {
      setState(() => _errorText = 'Vui lòng nhập mật khẩu');
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      await widget.authRepository.verifyPasswordRequest(pw);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = '$e');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 36),
                    child: Text(
                      'NHẬP MẬT KHẨU',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.of(context).pop(false),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: Color(0xfff1f5f9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Color(0xff64748b),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xffeef2f6)),
              const SizedBox(height: 16),
              const Text(
                'Để tiếp tục, vui lòng nhập mật khẩu để xác thực bạn là chủ tài khoản',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xff475569),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('verify-owner-password-field'),
                controller: _passwordController,
                obscureText: _obscure,
                autofocus: true,
                onSubmitted: (_) => _verify(),
                decoration: InputDecoration(
                  hintText: 'Nhập mật khẩu...',
                  hintStyle: const TextStyle(color: Color(0xff94a3b8)),
                  errorText: _errorText,
                  filled: true,
                  fillColor: const Color(0xfff8fafc),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: const Color(0xff94a3b8),
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xffe2e8f0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xffe2e8f0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xff0b57d0),
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop(false);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ForgotPasswordPage(
                          authRepository: widget.authRepository,
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'Quên mật khẩu?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff0b57d0),
                      decoration: TextDecoration.underline,
                      decorationColor: Color(0xff0b57d0),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: FilledButton(
                  key: const ValueKey('verify-owner-continue-btn'),
                  onPressed: _submitting ? null : _verify,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xff0b57d0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                      : const Text(
                          'Tiếp tục',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
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

class _GroupHeading extends StatelessWidget {
  const _GroupHeading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: Color(0xff64748b),
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.children,
    this.borderColor,
  });

  final List<Widget> children;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _BlueIconBox extends StatelessWidget {
  const _BlueIconBox({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xffeaf2ff),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        size: 20,
        color: const Color(0xff0b57d0),
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 0.8,
      indent: 66,
      color: Color(0xfff1f5f9),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    this.rowKey,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final Key? rowKey;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: rowKey,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            _BlueIconBox(icon: icon),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xff94a3b8),
            ),
          ],
        ),
      ),
    );
  }
}

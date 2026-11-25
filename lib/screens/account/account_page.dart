import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../helpers/session_helper.dart';
import '../../models/user_role_models.dart';
import '../../repositories/auth_repository.dart';
import '../admin/admin_dashboard_page.dart';
import '../auth/login_page.dart';
import '../booking/order_history_page.dart';
import '../home/widgets/home_header.dart';
import 'change_password_page.dart';

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
  late final AuthRepository _authRepo =
      widget.authRepository ?? AuthRepository();

  SessionUser? _user;
  bool _loading = true;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
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

  void _openCenterInfoDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trung tâm Y tế Xã Hiệp Phước'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hệ thống đặt lịch khám bệnh trực tuyến.'),
            SizedBox(height: 8),
            Text(
              'Giờ làm việc và thông tin liên hệ chi tiết được hiển thị tại Trang chủ.',
              style: TextStyle(color: AppColors.muted),
            ),
          ],
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

  void _openHistory() {
    if (widget.onOpenHistory != null) {
      widget.onOpenHistory!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Lịch sử khám')),
          body: const SafeArea(child: OrderHistoryPage()),
        ),
      ),
    );
  }

  void _openBills() {
    if (widget.onOpenBills != null) {
      widget.onOpenBills!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const FeaturePlaceholder(
          title: 'Hóa đơn',
          icon: Icons.receipt_long_outlined,
        ),
      ),
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

    final displayName = user.fullName.trim().isNotEmpty
        ? user.fullName.trim()
        : 'Người dùng';
    final initial = displayName[0].toUpperCase();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _AccountGradientHeader(
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.phone.isNotEmpty ? user.phone : 'Chưa cập nhật SĐT',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xffd6ebff),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        user.roleDisplayName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (user.isAdmin) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xffeaf5ff),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xffbfdbfe)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => AdminDashboardPage(
                                currentUser: user,
                                authRepository: _authRepo,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.admin_panel_settings_outlined,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Mở trang Quản trị (Admin)',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.text,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  const _SectionTitle('Tiện ích khám bệnh'),
                  const SizedBox(height: 10),
                  _SectionCard(
                    children: [
                      _AccountMenuRow(
                        icon: Icons.folder_shared_outlined,
                        title: 'Hồ sơ bệnh nhân',
                        onTap: () =>
                            Navigator.of(context).pushNamed('/patient-profiles'),
                      ),
                      const Divider(height: 1, color: Color(0xffeaf1f8)),
                      _AccountMenuRow(
                        icon: Icons.history_rounded,
                        title: 'Lịch sử đặt khám',
                        onTap: _openHistory,
                      ),
                      const Divider(height: 1, color: Color(0xffeaf1f8)),
                      _AccountMenuRow(
                        icon: Icons.receipt_long_outlined,
                        title: 'Hóa đơn thanh toán',
                        onTap: _openBills,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const _SectionTitle('Cài đặt tài khoản'),
                  const SizedBox(height: 10),
                  _SectionCard(
                    children: [
                      _AccountMenuRow(
                        icon: Icons.lock_outline_rounded,
                        title: 'Đổi mật khẩu',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ChangePasswordPage(authRepository: _authRepo),
                          ),
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xffeaf1f8)),
                      _AccountMenuRow(
                        icon: Icons.local_hospital_outlined,
                        title: 'Trung tâm Y tế Xã Hiệp Phước',
                        onTap: _openCenterInfoDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _loggingOut ? null : _logout,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xfffef2f2),
                        foregroundColor: const Color(0xffdc2626),
                        side: const BorderSide(color: Color(0xfffecaca)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: _loggingOut
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xffdc2626),
                              ),
                            )
                          : const Icon(Icons.logout_rounded),
                      label: const Text(
                        'Đăng xuất',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Y tế Hiệp Phước • Phiên bản 1.0.0',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuestView() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const _AccountGradientHeader(
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.person_outline_rounded,
                  size: 30,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chào mừng đến Y tế Hiệp Phước',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Đăng nhập để đặt lịch khám và theo dõi hồ sơ',
                      style: TextStyle(fontSize: 13, color: Color(0xffd6ebff)),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
                  border: Border.all(color: const Color(0xffdfedf8)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: .04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Bạn chưa đăng nhập',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xff349ff0), Color(0xff2369d5)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                            (route) => false,
                          ),
                          child: const Center(
                            child: Text(
                              'Đăng nhập ngay',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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
    );
  }
}

class _AccountGradientHeader extends StatelessWidget {
  const _AccountGradientHeader({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff349ff0), Color(0xff2369d5)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          const Positioned(
            right: 26,
            top: 14,
            child: Icon(Icons.add_rounded, size: 36, color: Color(0x187fffff)),
          ),
          const Positioned(
            right: 78,
            bottom: 12,
            child: Icon(Icons.add_rounded, size: 22, color: Color(0x147fffff)),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tài khoản',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  child,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xffdfedf8)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _AccountMenuRow extends StatelessWidget {
  const _AccountMenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.light,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
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

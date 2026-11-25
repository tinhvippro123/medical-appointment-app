import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/community_logo.dart';
import '../../helpers/session_helper.dart';
import '../../models/user_role_models.dart';
import '../../repositories/auth_repository.dart';
import '../account/change_password_page.dart';
import '../auth/login_page.dart';
import '../home/home_page.dart';
import 'departments/department_admin_page.dart';
import 'roles/role_admin_page.dart';
import 'users/user_admin_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key, this.currentUser, this.authRepository});

  final SessionUser? currentUser;
  final AuthRepository? authRepository;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late final AuthRepository _authRepo =
      widget.authRepository ?? AuthRepository();

  SessionUser? _user;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _user = widget.currentUser;
    if (_user == null) {
      _loadUser();
    }
  }

  Future<void> _loadUser() async {
    final user = await SessionHepler.getCurrentUser();
    if (mounted) {
      setState(() => _user = user);
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
        content: const Text(
          'Bạn có chắc muốn đăng xuất khỏi tài khoản Quản trị?',
        ),
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
    final name = _user?.fullName.isNotEmpty == true
        ? _user!.fullName
        : 'Quản trị viên';
    final phone = _user?.phone.isNotEmpty == true ? _user!.phone : 'ADMIN';

    return Scaffold(
      appBar: AppBar(title: const Text('Bảng điều khiển Quản trị')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xff349ff0), Color(0xff2369d5)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const CommunityLogo(size: 40),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            phone,
                            style: const TextStyle(color: Color(0xffd6ebff)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'ADMIN',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Quản lý hệ thống',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 10),
              _MenuCard(
                icon: Icons.manage_accounts_outlined,
                color: AppColors.primary,
                title: 'Quản lý Người dùng',
                subtitle: 'Tài khoản, trạng thái hoạt động và phân quyền',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        UserAdminPage(currentUserId: _user?.userId),
                  ),
                ),
              ),
              _MenuCard(
                icon: Icons.admin_panel_settings_outlined,
                color: const Color(0xff4f46e5),
                title: 'Quản lý Vai trò',
                subtitle: 'Danh sách vai trò hệ thống và tùy chỉnh',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RoleAdminPage()),
                ),
              ),
              _MenuCard(
                icon: Icons.local_hospital_outlined,
                color: const Color(0xff0891b2),
                title: 'Quản lý Chuyên khoa',
                subtitle: 'Danh mục chuyên khoa và hình ảnh',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DepartmentAdminPage(),
                  ),
                ),
              ),
              _MenuCard(
                icon: Icons.home_outlined,
                color: const Color(0xff059669),
                title: 'Giao diện Bệnh nhân',
                subtitle: 'Chuyển sang màn hình đặt lịch khám',
                onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const HomePage()),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Tài khoản',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xffdfedf8)),
                ),
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ChangePasswordPage(authRepository: _authRepo),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Đổi mật khẩu',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xff94a3b8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
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
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffdfedf8)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xff94a3b8)),
            ],
          ),
        ),
      ),
    );
  }
}

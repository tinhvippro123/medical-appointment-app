import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/community_logo.dart';
import '../../helpers/session_helper.dart';
import '../../models/user_role_models.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/department_repository.dart';
import '../../repositories/doctor_repository.dart';
import '../../repositories/role_repository.dart';
import '../../repositories/user_repository.dart';
import '../account/change_password_page.dart';
import '../auth/login_page.dart';
import '../home/home_page.dart';
import 'departments/department_admin_page.dart';
import 'doctors/doctor_admin_page.dart';
import 'roles/role_admin_page.dart';
import 'users/user_admin_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({
    super.key,
    this.currentUser,
    this.authRepository,
    this.userRepository,
    this.roleRepository,
    this.departmentRepository,
    this.doctorRepository,
  });

  final SessionUser? currentUser;
  final AuthRepository? authRepository;
  final UserRepository? userRepository;
  final RoleRepository? roleRepository;
  final DepartmentRepository? departmentRepository;
  final DoctorRepository? doctorRepository;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late final AuthRepository _authRepo =
      widget.authRepository ?? AuthRepository();
  late final UserRepository _userRepo =
      widget.userRepository ?? UserRepository();
  late final RoleRepository _roleRepo =
      widget.roleRepository ?? RoleRepository();
  late final DepartmentRepository _deptRepo =
      widget.departmentRepository ?? DepartmentRepository();
  late final DoctorRepository _doctorRepo =
      widget.doctorRepository ?? DoctorRepository();

  SessionUser? _user;
  bool _loggingOut = false;
  bool _loadingStats = false;
  int? _userCount;
  int? _roleCount;
  int? _departmentCount;
  int? _doctorCount;

  @override
  void initState() {
    super.initState();
    _user = widget.currentUser;
    if (_user == null) {
      _loadUser();
    }
    _loadStats();
  }

  Future<void> _loadUser() async {
    final user = await SessionHepler.getCurrentUser();
    if (mounted) {
      setState(() => _user = user);
    }
  }

  Future<void> _loadStats() async {
    if (_loadingStats) {
      return;
    }
    setState(() => _loadingStats = true);

    int? users;
    int? roles;
    int? departments;
    int? doctors;

    try {
      final paged = await _userRepo.list(page: 1, pageSize: 1);
      users = paged.totalCount;
    } catch (_) {}

    try {
      final roleRes = await _roleRepo.list();
      roles = roleRes.items.length;
    } catch (_) {}

    try {
      final deptList = await _deptRepo.list();
      departments = deptList.length;
    } catch (_) {}

    try {
      final doctorPage = await _doctorRepo.getDoctors(page: 1, pageSize: 1);
      doctors = doctorPage.totalCount;
    } catch (_) {}

    if (!mounted) {
      return;
    }
    setState(() {
      _loadingStats = false;
      if (users != null) {
        _userCount = users;
      }
      if (roles != null) {
        _roleCount = roles;
      }
      if (departments != null) {
        _departmentCount = departments;
      }
      if (doctors != null) {
        _doctorCount = doctors;
      }
    });
  }

  Future<void> _openModule(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) {
      _loadStats();
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
    final phone = _user?.phone.isNotEmpty == true ? _user!.phone : '—';

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildHeader(name, phone),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildStatsStrip(),
                      const SizedBox(height: 20),
                      const Text(
                        'Quản lý danh mục',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 10),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _AdminModuleCard(
                                icon: Icons.people_outline_rounded,
                                title: 'Người dùng',
                                caption: _userCount != null
                                    ? '$_userCount tài khoản'
                                    : 'Tài khoản & quyền',
                                onTap: () => _openModule(
                                  UserAdminPage(currentUserId: _user?.userId),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _AdminModuleCard(
                                icon: Icons.verified_user_outlined,
                                title: 'Vai trò',
                                caption: _roleCount != null
                                    ? '$_roleCount vai trò'
                                    : 'Phân quyền hệ thống',
                                onTap: () => _openModule(const RoleAdminPage()),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _AdminModuleCard(
                                icon: Icons.local_hospital_outlined,
                                title: 'Chuyên khoa',
                                caption: _departmentCount != null
                                    ? '$_departmentCount chuyên khoa'
                                    : 'Danh mục khoa khám',
                                onTap: () =>
                                    _openModule(const DepartmentAdminPage()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _AdminModuleCard(
                                icon: Icons.medical_information_outlined,
                                title: 'Bác sĩ',
                                caption: _doctorCount != null
                                    ? '$_doctorCount bác sĩ'
                                    : 'Hồ sơ & phòng khám',
                                onTap: () =>
                                    _openModule(const DoctorAdminPage()),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
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
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: .04),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _ActionRow(
                              icon: Icons.storefront_outlined,
                              title: 'Giao diện Bệnh nhân',
                              onTap: () =>
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) => const HomePage(),
                                    ),
                                  ),
                            ),
                            const Divider(height: 1, color: Color(0xffeaf1f8)),
                            _ActionRow(
                              icon: Icons.lock_outline_rounded,
                              title: 'Đổi mật khẩu',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChangePasswordPage(
                                    authRepository: _authRepo,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
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
                        'Y tế Hiệp Phước • Quản trị viên',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String name, String phone) {
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
            right: 54,
            top: 16,
            child: Icon(Icons.add_rounded, size: 36, color: Color(0x187fffff)),
          ),
          const Positioned(
            right: 22,
            bottom: 18,
            child: Icon(Icons.add_rounded, size: 22, color: Color(0x147fffff)),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 12, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const CommunityLogo(size: 30),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'QUẢN TRỊ HỆ THỐNG',
                              style: TextStyle(
                                color: Color(0xffd6ebff),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Y tế Hiệp Phước',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Làm mới',
                        onPressed: _loadingStats ? null : _loadStats,
                        icon: _loadingStats
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.refresh_rounded,
                                color: Colors.white,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$name • $phone',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'ADMIN',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
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
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _StatColumn(
                label: 'Người dùng',
                value: _userCount?.toString() ?? '—',
              ),
            ),
            const VerticalDivider(width: 1, color: Color(0xffeaf1f8)),
            Expanded(
              child: _StatColumn(
                label: 'Vai trò',
                value: _roleCount?.toString() ?? '—',
              ),
            ),
            const VerticalDivider(width: 1, color: Color(0xffeaf1f8)),
            Expanded(
              child: _StatColumn(
                label: 'Chuyên khoa',
                value: _departmentCount?.toString() ?? '—',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
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
            const Icon(Icons.chevron_right_rounded, color: Color(0xff94a3b8)),
          ],
        ),
      ),
    );
  }
}

class _AdminModuleCard extends StatelessWidget {
  const _AdminModuleCard({
    required this.icon,
    required this.title,
    required this.caption,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.light,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 22, color: AppColors.primary),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Color(0xff94a3b8),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

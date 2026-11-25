import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../helpers/session_helper.dart';
import '../../../models/user_role_models.dart';
import '../../../repositories/role_repository.dart';
import '../../../repositories/user_repository.dart';
import 'user_form_page.dart';

class UserAdminPage extends StatefulWidget {
  const UserAdminPage({
    super.key,
    this.userRepository,
    this.roleRepository,
    this.currentUserId,
  });

  final UserRepository? userRepository;
  final RoleRepository? roleRepository;
  final int? currentUserId;

  @override
  State<UserAdminPage> createState() => _UserAdminPageState();
}

class _UserAdminPageState extends State<UserAdminPage> {
  late final UserRepository _userRepo =
      widget.userRepository ?? UserRepository();
  late final RoleRepository _roleRepo =
      widget.roleRepository ?? RoleRepository();
  final TextEditingController _searchController = TextEditingController();

  int? _currentUserId;
  List<RoleItem> _roles = const [];
  PagedUsers? _paged;
  String? _error;
  bool _loading = true;

  int _page = 1;
  int? _roleFilterId;
  bool? _isActiveFilter;
  final Set<int> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _currentUserId = widget.currentUserId;
    _initData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    if (_currentUserId == null) {
      final session = await SessionHepler.getCurrentUser();
      _currentUserId = session?.userId;
    }
    try {
      final roleRes = await _roleRepo.list();
      if (mounted) {
        _roles = roleRes.items;
      }
    } catch (_) {}
    await _loadUsers(page: 1);
  }

  Future<void> _loadUsers({int? page}) async {
    final targetPage = page ?? _page;
    setState(() {
      _loading = true;
      _error = null;
      _page = targetPage;
    });

    try {
      final paged = await _userRepo.list(
        page: targetPage,
        pageSize: 10,
        keyword: _searchController.text,
        roleId: _roleFilterId,
        isActive: _isActiveFilter,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _paged = paged;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _openForm([UserItem? user]) async {
    if (_roles.isEmpty) {
      try {
        final roleRes = await _roleRepo.list();
        _roles = roleRes.items;
      } catch (_) {}
    }
    if (!mounted) {
      return;
    }
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UserFormPage(
          userRepository: _userRepo,
          roles: _roles,
          user: user,
          isSelf: user != null && user.id == _currentUserId,
        ),
      ),
    );
    if (changed == true && mounted) {
      await _loadUsers();
    }
  }

  Future<void> _toggleStatus(UserItem user, bool newValue) async {
    if (user.id == _currentUserId || _busyIds.contains(user.id)) {
      return;
    }
    setState(() => _busyIds.add(user.id));
    try {
      await _userRepo.updateStatus(user.id, newValue);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newValue
                ? 'Đã mở khóa ${user.fullName}'
                : 'Đã khóa ${user.fullName}',
          ),
          backgroundColor: const Color(0xff10b981),
        ),
      );
      await _loadUsers();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: const Color(0xffef4444),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(user.id));
      }
    }
  }

  Future<void> _deleteUser(UserItem user) async {
    if (user.id == _currentUserId || _busyIds.contains(user.id)) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vô hiệu hóa người dùng?'),
        content: Text(
          'Bạn có chắc muốn vô hiệu hóa tài khoản “${user.fullName}” (${user.phone})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vô hiệu hóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _busyIds.add(user.id));
    try {
      await _userRepo.delete(user.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã vô hiệu hóa người dùng'),
          backgroundColor: Color(0xff10b981),
        ),
      );
      await _loadUsers();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: const Color(0xffef4444),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(user.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý người dùng'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: () => _loadUsers(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Thêm người dùng'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            children: [
              _buildFilterBar(),
              Expanded(child: _buildListContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _loadUsers(page: 1),
            decoration: InputDecoration(
              hintText: 'Tìm theo họ tên, SĐT hoặc email...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      tooltip: 'Xóa từ khóa',
                      onPressed: () {
                        _searchController.clear();
                        _loadUsers(page: 1);
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                  IconButton(
                    tooltip: 'Tìm kiếm',
                    onPressed: () => _loadUsers(page: 1),
                    icon: const Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Tất cả'),
                  selected: _isActiveFilter == null,
                  onSelected: (_) {
                    _isActiveFilter = null;
                    _loadUsers(page: 1);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Hoạt động'),
                  selected: _isActiveFilter == true,
                  onSelected: (_) {
                    _isActiveFilter = true;
                    _loadUsers(page: 1);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Đã khóa'),
                  selected: _isActiveFilter == false,
                  onSelected: (_) {
                    _isActiveFilter = false;
                    _loadUsers(page: 1);
                  },
                ),
                if (_roles.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: _roleFilterId,
                        hint: const Text('Tất cả vai trò'),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Tất cả vai trò'),
                          ),
                          for (final role in _roles)
                            DropdownMenuItem<int?>(
                              value: role.id,
                              child: Text(role.name),
                            ),
                        ],
                        onChanged: (value) {
                          _roleFilterId = value;
                          _loadUsers(page: 1);
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _loadUsers(),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    final paged = _paged;
    final items = paged?.items ?? const <UserItem>[];

    return RefreshIndicator(
      onRefresh: () => _loadUsers(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (paged?.isFromCache == true)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xfffffbeb),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xfffde68a)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.offline_bolt_outlined, color: Color(0xffb45309)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Đang hiển thị dữ liệu cache SQLite (mất kết nối máy chủ).',
                      style: TextStyle(color: Color(0xff92400e)),
                    ),
                  ),
                ],
              ),
            ),
          Text(
            'NGƯỜI DÙNG • ${paged?.totalCount ?? 0}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: Text('Không tìm thấy người dùng phù hợp.')),
            ),
          for (final user in items) _buildUserCard(user),
          if (paged != null && paged.totalPages > 1) _buildPaginationBar(paged),
        ],
      ),
    );
  }

  Widget _buildUserCard(UserItem user) {
    final isSelf = user.id == _currentUserId;
    final busy = _busyIds.contains(user.id);
    final initial = user.fullName.trim().isNotEmpty
        ? user.fullName.trim()[0].toUpperCase()
        : 'U';

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: busy ? null : () => _openForm(user),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: user.isActive
                    ? AppColors.light
                    : Colors.grey.shade200,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: user.isActive ? AppColors.primary : Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          user.fullName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (isSelf)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xffe0e7ff),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Bạn',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xff3730a3),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email?.isNotEmpty == true
                          ? '${user.phone} • ${user.email}'
                          : user.phone,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: user.roleKey.toUpperCase() == 'ADMIN'
                                ? const Color(0xffeef2ff)
                                : AppColors.light,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            user.roleName.isNotEmpty
                                ? user.roleName
                                : user.roleKey,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: user.roleKey.toUpperCase() == 'ADMIN'
                                  ? const Color(0xff4338ca)
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: user.isActive
                                ? const Color(0xffecfdf5)
                                : const Color(0xfffef2f2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            user.isActive ? 'Hoạt động' : 'Đã khóa',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: user.isActive
                                  ? const Color(0xff047857)
                                  : const Color(0xffdc2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: user.isActive,
                    onChanged: isSelf || busy
                        ? null
                        : (val) => _toggleStatus(user, val),
                  ),
                  IconButton(
                    tooltip: isSelf
                        ? 'Không thể tự khóa tài khoản của chính mình'
                        : 'Vô hiệu hóa ${user.fullName}',
                    onPressed: isSelf || busy ? null : () => _deleteUser(user),
                    icon: Icon(
                      Icons.delete_outline,
                      color: isSelf ? Colors.grey.shade400 : Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationBar(PagedUsers paged) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: paged.hasPreviousPage
                ? () => _loadUsers(page: paged.page - 1)
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
            label: const Text('Trang trước'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'Trang ${paged.page} / ${paged.totalPages}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          OutlinedButton.icon(
            onPressed: paged.hasNextPage
                ? () => _loadUsers(page: paged.page + 1)
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
            label: const Text('Trang sau'),
          ),
        ],
      ),
    );
  }
}

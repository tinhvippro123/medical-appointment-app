import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../helpers/form_validators.dart';
import '../../../models/user_role_models.dart';
import '../../../repositories/role_repository.dart';

class RoleAdminPage extends StatefulWidget {
  const RoleAdminPage({super.key, this.repository});

  final RoleRepository? repository;

  @override
  State<RoleAdminPage> createState() => _RoleAdminPageState();
}

class _RoleAdminPageState extends State<RoleAdminPage> {
  late final RoleRepository _repository = widget.repository ?? RoleRepository();

  RoleListResult? _result;
  String? _error;
  bool _loading = true;
  final Set<int> _deletingIds = {};

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _repository.list();
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
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

  Future<void> _openRoleDialog([RoleItem? role]) async {
    final isEdit = role != null;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _RoleFormDialog(repository: _repository, role: role),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit ? 'Đã cập nhật vai trò' : 'Đã thêm vai trò mới',
          ),
          backgroundColor: const Color(0xff10b981),
        ),
      );
      await _loadRoles();
    }
  }

  Future<void> _deleteRole(RoleItem role) async {
    if (role.isSystemRole || _deletingIds.contains(role.id)) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa vai trò?'),
        content: Text(
          'Bạn có chắc muốn xóa vai trò “${role.name}” (${role.key})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _deletingIds.add(role.id));
    try {
      await _repository.delete(role.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xóa vai trò'),
          backgroundColor: Color(0xff10b981),
        ),
      );
      await _loadRoles();
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
        setState(() => _deletingIds.remove(role.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _result?.items ?? const <RoleItem>[];
    final isFromCache = _result?.isFromCache ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý vai trò'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _loadRoles,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openRoleDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm vai trò'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: _buildBody(items, isFromCache),
        ),
      ),
    );
  }

  Widget _buildBody(List<RoleItem> items, bool isFromCache) {
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
              TextButton(onPressed: _loadRoles, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRoles,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (isFromCache)
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
            'VAI TRÒ HỆ THỐNG • ${items.length}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: Text('Chưa có vai trò nào.')),
            ),
          for (final role in items)
            Card(
              elevation: 0,
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: role.isSystemRole
                            ? const Color(0xffeaf5ff)
                            : const Color(0xfff3f4f6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        role.key,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: role.isSystemRole
                              ? AppColors.primary
                              : AppColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
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
                                role.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (role.isSystemRole)
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
                                    'Mặc định',
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
                            role.description?.isNotEmpty == true
                                ? role.description!
                                : 'Chưa có mô tả',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${role.userCount} người dùng',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Sửa ${role.name}',
                      onPressed: _deletingIds.contains(role.id)
                          ? null
                          : () => _openRoleDialog(role),
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    if (_deletingIds.contains(role.id))
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      IconButton(
                        tooltip: role.isSystemRole
                            ? 'Không thể xóa vai trò mặc định'
                            : 'Xóa ${role.name}',
                        onPressed: role.isSystemRole
                            ? null
                            : () => _deleteRole(role),
                        icon: Icon(
                          Icons.delete_outline,
                          color: role.isSystemRole
                              ? Colors.grey.shade400
                              : Colors.redAccent,
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
}

class _RoleFormDialog extends StatefulWidget {
  const _RoleFormDialog({required this.repository, this.role});

  final RoleRepository repository;
  final RoleItem? role;

  @override
  State<_RoleFormDialog> createState() => _RoleFormDialogState();
}

class _RoleFormDialogState extends State<_RoleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _keyController = TextEditingController(
    text: widget.role?.key ?? '',
  );
  late final TextEditingController _nameController = TextEditingController(
    text: widget.role?.name ?? '',
  );
  late final TextEditingController _descController = TextEditingController(
    text: widget.role?.description ?? '',
  );

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.role != null;
  bool get _isSystem => widget.role?.isSystemRole ?? false;

  @override
  void dispose() {
    _keyController.dispose();
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_isEdit) {
        await widget.repository.update(
          widget.role!.id,
          key: _keyController.text,
          name: _nameController.text,
          description: _descController.text,
        );
      } else {
        await widget.repository.create(
          key: _keyController.text,
          name: _nameController.text,
          description: _descController.text,
        );
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Sửa vai trò' : 'Thêm vai trò mới'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _keyController,
                enabled: !_saving && !_isSystem,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Mã vai trò (Key) *',
                  hintText: 'Ví dụ: STAFF hoặc DOCTOR',
                  helperText: _isSystem
                      ? 'Vai trò mặc định không thể đổi mã'
                      : 'Chỉ gồm chữ, số và dấu _',
                  border: const OutlineInputBorder(),
                ),
                validator: FormValidators.validateRoleKey,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nameController,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Tên vai trò *',
                  hintText: 'Ví dụ: Nhân viên tiếp tân',
                  border: OutlineInputBorder(),
                ),
                validator: FormValidators.validateRoleName,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descController,
                enabled: !_saving,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Mô tả',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: FormValidators.validateRoleDescription,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'Đang lưu...' : 'Lưu'),
        ),
      ],
    );
  }
}

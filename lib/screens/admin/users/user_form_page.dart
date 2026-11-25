import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../helpers/form_validators.dart';
import '../../../models/user_role_models.dart';
import '../../../repositories/user_repository.dart';

class UserFormPage extends StatefulWidget {
  const UserFormPage({
    super.key,
    required this.userRepository,
    required this.roles,
    this.user,
    this.isSelf = false,
  });

  final UserRepository userRepository;
  final List<RoleItem> roles;
  final UserItem? user;
  final bool isSelf;

  @override
  State<UserFormPage> createState() => _UserFormPageState();
}

class _UserFormPageState extends State<UserFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController = TextEditingController(
    text: widget.user?.fullName ?? '',
  );
  late final TextEditingController _phoneController = TextEditingController(
    text: widget.user?.phone ?? '',
  );
  late final TextEditingController _emailController = TextEditingController(
    text: widget.user?.email ?? '',
  );
  final TextEditingController _passwordController = TextEditingController();

  late int? _selectedRoleId =
      widget.user?.roleId ??
      (widget.roles.isNotEmpty ? widget.roles.first.id : null);
  late bool _isActive = widget.user?.isActive ?? true;

  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;

  bool get _isEdit => widget.user != null;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedRoleId == null) {
      setState(() => _error = 'Vui lòng chọn vai trò cho tài khoản');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (_isEdit) {
        await widget.userRepository.update(
          widget.user!.id,
          fullName: _nameController.text,
          phone: _phoneController.text,
          email: _emailController.text,
          roleId: _selectedRoleId!,
          isActive: _isActive,
        );
      } else {
        await widget.userRepository.create(
          fullName: _nameController.text,
          phone: _phoneController.text,
          email: _emailController.text,
          password: _passwordController.text,
          roleId: _selectedRoleId!,
        );
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit ? 'Đã cập nhật người dùng' : 'Đã tạo người dùng mới',
          ),
          backgroundColor: const Color(0xff10b981),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _error = '$e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleItems = List<RoleItem>.from(widget.roles);
    if (_selectedRoleId != null &&
        roleItems.every((r) => r.id != _selectedRoleId)) {
      roleItems.add(
        RoleItem(
          id: _selectedRoleId!,
          key: widget.user?.roleKey ?? 'ROLE',
          name: widget.user?.roleName ?? 'Vai trò hiện tại',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Cập nhật người dùng' : 'Thêm người dùng'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextFormField(
                  controller: _nameController,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên *',
                    hintText: 'Ví dụ: Nguyễn Văn A',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: FormValidators.validateFullName,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  enabled: !_busy,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại *',
                    hintText: 'Ví dụ: 0912345678',
                    prefixIcon: Icon(Icons.phone_iphone_rounded),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: FormValidators.validatePhone,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email (tùy chọn)',
                    hintText: 'Ví dụ: bacsi@hiepphuoc.vn',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: FormValidators.validateOptionalEmail,
                ),
                if (!_isEdit) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    enabled: !_busy,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu *',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: FormValidators.validatePassword,
                  ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _selectedRoleId,
                  decoration: InputDecoration(
                    labelText: 'Vai trò *',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    helperText: widget.isSelf
                        ? 'Không thể tự đổi vai trò của chính mình'
                        : null,
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: roleItems
                      .map(
                        (role) => DropdownMenuItem<int>(
                          value: role.id,
                          child: Text('${role.name} (${role.key})'),
                        ),
                      )
                      .toList(),
                  onChanged: _busy || widget.isSelf
                      ? null
                      : (value) => setState(() => _selectedRoleId = value),
                  validator: (value) =>
                      value == null ? 'Vui lòng chọn vai trò' : null,
                ),
                if (_isEdit) ...[
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    child: SwitchListTile(
                      value: _isActive,
                      onChanged: _busy || widget.isSelf
                          ? null
                          : (value) => setState(() => _isActive = value),
                      title: const Text(
                        'Trạng thái hoạt động',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        widget.isSelf
                            ? 'Không thể tự khóa tài khoản của chính mình'
                            : (_isActive
                                  ? 'Tài khoản đang được phép đăng nhập'
                                  : 'Tài khoản đang bị khóa'),
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _busy ? null : _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(
                    _busy
                        ? 'Đang lưu...'
                        : (_isEdit ? 'Lưu thay đổi' : 'Tạo người dùng'),
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

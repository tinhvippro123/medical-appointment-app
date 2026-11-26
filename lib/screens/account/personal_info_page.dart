import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../helpers/form_validators.dart';
import '../../models/auth_models.dart';
import '../../models/user_role_models.dart';
import '../../repositories/auth_repository.dart';

String maskPhoneNumber(String rawPhone) {
  final digits = rawPhone.trim();
  if (digits.length < 7) {
    return digits.isEmpty ? 'Chưa cập nhật' : digits;
  }
  final prefix = digits.substring(0, 3);
  final suffix = digits.substring(digits.length - 3);
  return '$prefix****$suffix';
}

class PersonalInfoPage extends StatefulWidget {
  const PersonalInfoPage({
    super.key,
    required this.initialUser,
    this.authRepository,
  });

  final SessionUser initialUser;
  final AuthRepository? authRepository;

  @override
  State<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final _lastMiddleNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _emailController = TextEditingController();

  late final AuthRepository _authRepo =
      widget.authRepository ?? AuthRepository();

  bool _isLoading = true;
  bool _isSaving = false;
  late String _phone = widget.initialUser.phone;
  DateTime? _dateOfBirth;
  String? _gender;

  static const List<String> _genderOptions = ['Nam', 'Nữ', 'Khác'];

  @override
  void initState() {
    super.initState();
    _populateNameControllers(widget.initialUser.fullName);
    _fetchLatestProfile();
  }

  @override
  void dispose() {
    _lastMiddleNameController.dispose();
    _firstNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _populateNameControllers(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) {
      _lastMiddleNameController.clear();
      _firstNameController.clear();
      return;
    }
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      _lastMiddleNameController.clear();
      _firstNameController.text = parts.first;
    } else {
      _firstNameController.text = parts.last;
      _lastMiddleNameController.text = parts
          .sublist(0, parts.length - 1)
          .join(' ');
    }
  }

  Future<void> _fetchLatestProfile() async {
    try {
      final profile = await _authRepo.getMyProfileRequest();
      if (!mounted) return;
      setState(() {
        _phone = profile.phone;
        _populateNameControllers(profile.fullName);
        _emailController.text = profile.email ?? '';
        _dateOfBirth = profile.dateOfBirth;
        if (profile.gender != null &&
            _genderOptions.contains(profile.gender!.trim())) {
          _gender = profile.gender!.trim();
        }
      });
    } catch (_) {
      // Nếu mạng chậm vẫn cho phép sửa từ dữ liệu phiên hiện tại
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  static String _formatDob(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString().padLeft(4, '0');
    return '$d/$m/$y';
  }

  Future<void> _pickDateOfBirth() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final initial = _dateOfBirth ?? DateTime(2000, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(1920, 1, 1),
      lastDate: now,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Chọn ngày sinh',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (picked != null && mounted) {
      setState(() {
        _dateOfBirth = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  String get _combinedFullName {
    final lastMiddle = _lastMiddleNameController.text.trim();
    final first = _firstNameController.text.trim();
    return [
      if (lastMiddle.isNotEmpty) lastMiddle,
      if (first.isNotEmpty) first,
    ].join(' ');
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final fullName = _combinedFullName;
    final nameErr = FormValidators.validateFullName(fullName);
    if (nameErr != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(nameErr),
            backgroundColor: const Color(0xffef4444),
          ),
        );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updated = await _authRepo.updateMyProfileRequest(
        UpdateMyProfileRequest(
          fullName: fullName,
          email: _emailController.text.trim(),
          dateOfBirth: _dateOfBirth,
          gender: _gender,
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: const Color(0xffef4444),
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  InputDecoration _fieldDecoration({
    required String hint,
    Widget? suffixIcon,
    bool enabled = true,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xff94a3b8), fontSize: 14.5),
      suffixIcon: suffixIcon,
      enabled: enabled,
      filled: true,
      fillColor: enabled ? const Color(0xfff3f5f8) : const Color(0xfff5f7fa),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xffe5e9f0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xffe5e9f0)),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xffeaeef4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xff0b57d0), width: 1.4),
      ),
    );
  }

  Widget _fieldLabel(String text, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Color(0xff475569),
            ),
          ),
          if (trailing != null) ...[const Spacer(), trailing],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maskedPhone = maskPhoneNumber(_phone);
    final previewName = _combinedFullName;

    return Scaffold(
      backgroundColor: const Color(0xfff4f7fb),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xff0b57d0)),
        title: const Text(
          'Thông tin cá nhân',
          style: TextStyle(
            color: Color(0xff0b57d0),
            fontSize: 18.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SizedBox(
              height: 50,
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('personal-info-save-btn'),
                onPressed: (_isLoading || _isSaving) ? null : _saveProfile,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff0b57d0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Cập nhật thông tin',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      // Khối tóm tắt Avatar + SĐT phía trên
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(24),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xff0b63e5),
                                    Color(0xff3898ff),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                size: 38,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (previewName.isNotEmpty) ...[
                                    Text(
                                      previewName,
                                      style: const TextStyle(
                                        fontSize: 17.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.text,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xffeef4ff),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.phone_in_talk_outlined,
                                          size: 15,
                                          color: Color(0xff0b57d0),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          maskedPhone,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xff0b57d0),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Khối Form Thông tin tài khoản
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: const Color(0xff0b57d0),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Thông tin tài khoản',
                                    style: TextStyle(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.text,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),

                              // Số điện thoại (chỉ đọc)
                              _fieldLabel(
                                'Số điện thoại',
                                trailing: const Icon(
                                  Icons.lock_outline_rounded,
                                  size: 17,
                                  color: Color(0xff94a3b8),
                                ),
                              ),
                              TextFormField(
                                initialValue: maskedPhone,
                                enabled: false,
                                style: const TextStyle(
                                  color: Color(0xff94a3b8),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: _fieldDecoration(
                                  hint: maskedPhone,
                                  enabled: false,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Họ và tên lót
                              _fieldLabel('Họ và tên lót'),
                              TextFormField(
                                key: const ValueKey(
                                  'personal-info-last-middle-field',
                                ),
                                controller: _lastMiddleNameController,
                                onChanged: (_) => setState(() {}),
                                decoration: _fieldDecoration(
                                  hint: 'Họ và tên đệm...',
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Tên
                              _fieldLabel('Tên'),
                              TextFormField(
                                key: const ValueKey(
                                  'personal-info-first-name-field',
                                ),
                                controller: _firstNameController,
                                onChanged: (_) => setState(() {}),
                                decoration: _fieldDecoration(hint: 'Tên...'),
                                validator: (v) {
                                  if ((v?.trim() ?? '').isEmpty) {
                                    return 'Vui lòng nhập tên';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Ngày sinh & Giới tính (cùng hàng)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 11,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _fieldLabel('Ngày sinh'),
                                        InkWell(
                                          key: const ValueKey(
                                            'personal-info-dob-picker',
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          onTap: _pickDateOfBirth,
                                          child: InputDecorator(
                                            decoration: _fieldDecoration(
                                              hint: 'DD/MM/YYYY',
                                              suffixIcon: const Icon(
                                                Icons.calendar_month_outlined,
                                                color: Color(0xff0b57d0),
                                                size: 20,
                                              ),
                                            ),
                                            child: Text(
                                              _dateOfBirth != null
                                                  ? _formatDob(_dateOfBirth!)
                                                  : 'DD/MM/YYYY',
                                              style: TextStyle(
                                                fontSize: 14.5,
                                                color: _dateOfBirth != null
                                                    ? AppColors.text
                                                    : const Color(0xff94a3b8),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 9,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _fieldLabel('Giới tính'),
                                        DropdownButtonFormField<String>(
                                          key: const ValueKey(
                                            'personal-info-gender-dropdown',
                                          ),
                                          initialValue: _gender,
                                          hint: const Text(
                                            'Chọn',
                                            style: TextStyle(
                                              color: Color(0xff475569),
                                              fontSize: 14.5,
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            color: Color(0xff0b57d0),
                                          ),
                                          decoration: _fieldDecoration(
                                            hint: 'Chọn',
                                          ),
                                          items: _genderOptions
                                              .map(
                                                (g) => DropdownMenuItem(
                                                  value: g,
                                                  child: Text(g),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (v) =>
                                              setState(() => _gender = v),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Email
                              _fieldLabel('Email'),
                              TextFormField(
                                key: const ValueKey(
                                  'personal-info-email-field',
                                ),
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: _fieldDecoration(hint: 'Email...'),
                                validator: FormValidators.validateOptionalEmail,
                              ),
                            ],
                          ),
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

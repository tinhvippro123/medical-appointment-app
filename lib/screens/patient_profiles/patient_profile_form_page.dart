import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../models/patient_profile.dart';
import '../../repositories/patient_profile_repository.dart';

String formatBirthDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

class PatientProfileFormPage extends StatefulWidget {
  const PatientProfileFormPage({
    super.key,
    required this.repository,
    this.profile,
  });

  final PatientProfileRepository repository;
  final PatientProfile? profile;

  @override
  State<PatientProfileFormPage> createState() => _PatientProfileFormPageState();
}

class _PatientProfileFormPageState extends State<PatientProfileFormPage> {
  final _form = GlobalKey<FormState>();
  late final Map<String, dynamic> _fields = widget.profile?.toJson() ?? {};
  late DateTime? _birthDate = widget.profile?.dateOfBirth;
  bool _saving = false;

  Future<void> _pickBirthDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final firstDate = DateTime(1900);
    var initialDate = _birthDate ?? DateTime(today.year - 20, 1, 1);
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    if (initialDate.isAfter(today)) initialDate = today;

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: today,
    );
    if (mounted && date != null) setState(() => _birthDate = date);
  }

  Future<void> _save() async {
    final form = _form.currentState!;
    if (_saving || !form.validate()) return;
    final birthDate = _birthDate;
    if (birthDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng chọn ngày sinh.')));
      return;
    }

    form.save();
    _fields.remove('id');
    _fields['dateOfBirth'] = birthDate.toIso8601String().split('T').first;
    setState(() => _saving = true);
    try {
      final profile = await widget.repository.save(
        _fields,
        id: widget.profile?.id,
      );
      if (mounted) Navigator.pop(context, profile);
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException
          ? error.displayMessage
          : 'Không lưu được hồ sơ. Vui lòng thử lại.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _textField(
    String field,
    String label, {
    bool requiredField = false,
    int? maxLength,
    TextInputType? keyboardType,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      initialValue: _fields[field] as String?,
      enabled: !_saving,
      maxLength: maxLength,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        counterText: '',
      ),
      validator: (value) {
        if (requiredField && (value == null || value.trim().isEmpty)) {
          return 'Vui lòng nhập thông tin này.';
        }
        return null;
      },
      onSaved: (value) {
        final text = value?.trim() ?? '';
        _fields[field] = text.isEmpty ? null : text;
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final date = _birthDate;
    final gender = widget.profile?.gender;
    final genders = ['Nam', 'Nữ', 'Khác'];
    if (gender != null && gender.isNotEmpty && !genders.contains(gender)) {
      genders.add(gender);
    }

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.profile == null ? 'Thêm hồ sơ mới' : 'Sửa hồ sơ'),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _textField(
                      'fullName',
                      'Họ và tên',
                      requiredField: true,
                      maxLength: 100,
                    ),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _pickBirthDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        date == null
                            ? 'Chọn ngày sinh'
                            : 'Ngày sinh ${formatBirthDate(date)}',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: genders.contains(gender) ? gender : null,
                      decoration: const InputDecoration(
                        labelText: 'Giới tính',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final value in genders)
                          DropdownMenuItem(value: value, child: Text(value)),
                      ],
                      onChanged: _saving ? null : (_) {},
                      validator: (value) =>
                          value == null ? 'Vui lòng chọn giới tính.' : null,
                      onSaved: (value) => _fields['gender'] = value,
                    ),
                    const SizedBox(height: 16),
                    _textField(
                      'identityCardNumber',
                      'CCCD',
                      maxLength: 20,
                      keyboardType: TextInputType.number,
                    ),
                    _textField('healthInsuranceNumber', 'BHYT', maxLength: 50),
                    _textField('ethnicity', 'Dân tộc', maxLength: 50),
                    _textField('occupation', 'Nghề nghiệp', maxLength: 100),
                    _textField(
                      'phone',
                      'Số điện thoại',
                      keyboardType: TextInputType.phone,
                    ),
                    _textField('address', 'Địa chỉ'),
                    _textField(
                      'relationship',
                      'Mối quan hệ',
                      requiredField: true,
                      maxLength: 50,
                    ),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Đang lưu…' : 'Lưu hồ sơ'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

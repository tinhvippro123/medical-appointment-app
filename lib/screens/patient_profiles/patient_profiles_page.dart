import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../models/patient_profile.dart';
import '../../repositories/patient_profile_repository.dart';

class PatientProfilesPage extends StatefulWidget {
  const PatientProfilesPage({
    super.key,
    this.repository,
    this.profiles,
    this.forBooking = false,
  });

  final PatientProfileRepository? repository;
  final List<PatientProfile>? profiles;
  final bool forBooking;

  @override
  State<PatientProfilesPage> createState() => _PatientProfilesPageState();
}

class _PatientProfilesPageState extends State<PatientProfilesPage> {
  late final _repository = widget.repository ?? PatientProfileRepository();
  late List<PatientProfile> _profiles = List.of(widget.profiles ?? []);
  PatientProfile? _selected;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.profiles == null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profiles = await _repository.list();
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        for (final profile in profiles) {
          if (profile.relationship.trim().toLowerCase() == 'bản thân') {
            _selected = profile;
            break;
          }
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is ApiException
            ? error.displayMessage
            : 'Không tải được hồ sơ bệnh nhân.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addProfile() async {
    final profile = await Navigator.of(context).push<PatientProfile>(
      MaterialPageRoute(
        builder: (_) => _NewProfilePage(repository: _repository),
      ),
    );
    if (!mounted || profile == null) return;
    setState(() {
      _profiles.add(profile);
      if (widget.forBooking) _selected = profile;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.forBooking ? 'Chọn hồ sơ' : 'Quản lý hồ sơ'),
    ),
    body: _buildBody(),
  );

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            TextButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_profiles.isEmpty) const Text('Bạn chưa có hồ sơ bệnh nhân.'),
        for (final profile in _profiles)
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(profile.label),
            selected: widget.forBooking && _selected?.id == profile.id,
            trailing: _selected?.id == profile.id
                ? const Icon(Icons.check)
                : const Icon(Icons.chevron_right),
            onTap: () {
              if (widget.forBooking) {
                setState(() => _selected = profile);
              } else {
                Navigator.pop(context, profile);
              }
            },
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _addProfile,
          icon: const Icon(Icons.person_add_outlined),
          label: const Text('Thêm hồ sơ mới'),
        ),
        if (widget.forBooking) ...[
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _selected == null
                ? null
                : () => Navigator.of(
                    context,
                  ).pushNamed('/departments', arguments: _selected),
            child: const Text('Tiếp tục'),
          ),
        ],
      ],
    );
  }
}

class _NewProfilePage extends StatefulWidget {
  const _NewProfilePage({required this.repository});
  final PatientProfileRepository repository;

  @override
  State<_NewProfilePage> createState() => _NewProfilePageState();
}

class _NewProfilePageState extends State<_NewProfilePage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _relationship = TextEditingController();
  DateTime? _birthDate;
  String? _gender;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _relationship.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(today.year - 20, 1, 1),
      firstDate: DateTime(1900),
      lastDate: today,
    );
    if (mounted && date != null) setState(() => _birthDate = date);
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (_birthDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng chọn ngày sinh.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final profile = await widget.repository.create(
        fullName: _name.text.trim(),
        dateOfBirth: _birthDate!,
        gender: _gender!,
        relationship: _relationship.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    final birthDate = _birthDate;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Thêm hồ sơ mới')),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _name,
                enabled: !_saving,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Họ và tên',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Vui lòng nhập họ tên.'
                    : null,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickBirthDate,
                icon: const Icon(Icons.cake_outlined),
                label: Text(
                  birthDate == null
                      ? 'Chọn ngày sinh'
                      : 'Ngày sinh: ${birthDate.day}/${birthDate.month}/${birthDate.year}',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Giới tính',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Nam', child: Text('Nam')),
                  DropdownMenuItem(value: 'Nữ', child: Text('Nữ')),
                  DropdownMenuItem(value: 'Khác', child: Text('Khác')),
                ],
                onChanged: _saving ? null : (value) => _gender = value,
                validator: (value) =>
                    value == null ? 'Vui lòng chọn giới tính.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _relationship,
                enabled: !_saving,
                maxLength: 50,
                decoration: const InputDecoration(
                  labelText: 'Mối quan hệ',
                  hintText: 'Ví dụ: Bản thân, Con',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Vui lòng nhập mối quan hệ.'
                    : null,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Đang lưu…' : 'Lưu hồ sơ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../models/patient_profile.dart';
import '../../repositories/cart_repository.dart';
import '../../repositories/patient_profile_repository.dart';
import '../patient_profiles/patient_profiles_page.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({
    super.key,
    required this.doctorId,
    this.cartRepository,
    this.profileRepository,
  });

  final int? doctorId;
  final CartRepository? cartRepository;
  final PatientProfileRepository? profileRepository;

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  late final _cart = widget.cartRepository ?? CartRepository();
  late final _profileRepository =
      widget.profileRepository ?? PatientProfileRepository();
  List<Schedule> _schedules = [];
  List<PatientProfile> _profiles = [];
  PatientProfile? _patient;
  late DateTime _date = _today();
  String? _slot;
  String? _loadError;
  bool _loading = true;
  bool _saving = false;

  DateTime _today() =>
      DateUtils.dateOnly(DateTime.now().toUtc().add(const Duration(hours: 7)));

  @override
  void initState() {
    super.initState();
    if (widget.doctorId != null) _load();
  }

  String _message(Object error, String fallback) {
    if (error is ApiException) return error.displayMessage;
    if (error is CartException) return error.message;
    return fallback;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final schedules = await _cart.schedules(widget.doctorId!);
      final profiles = await _profileRepository.list();
      if (!mounted) return;
      setState(() {
        _schedules = schedules;
        _profiles = profiles;
        final selectedId = _patient?.id;
        _patient = null;
        for (final profile in profiles) {
          if (profile.id == selectedId) {
            _patient = profile;
            break;
          }
          if (_patient == null &&
              profile.relationship.trim().toLowerCase() == 'bản thân') {
            _patient = profile;
          }
        }
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _loadError = _message(
            error,
            'Không tải được thông tin đặt lịch.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final today = _today();
    final date = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(today) ? today : _date,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (!mounted || date == null || date == _date) return;
    setState(() {
      _date = date;
      _slot = null;
    });
  }

  Future<void> _manageProfiles() async {
    final profile = await Navigator.of(context).push<PatientProfile>(
      MaterialPageRoute(
        builder: (_) => PatientProfilesPage(
          repository: _profileRepository,
          profiles: _profiles,
        ),
      ),
    );
    if (!mounted) return;
    if (profile != null) setState(() => _patient = profile);
    await _load();
  }

  Future<void> _pickPatient() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            const ListTile(
              title: Text(
                'Đặt cho ai?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final profile in _profiles)
              ListTile(
                title: Text(profile.label),
                leading: const Icon(Icons.person_outline),
                selected: profile.id == _patient?.id,
                trailing: profile.id == _patient?.id
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  setState(() => _patient = profile);
                  Navigator.pop(sheetContext);
                },
              ),
            if (_profiles.isEmpty)
              const ListTile(title: Text('Bạn chưa có hồ sơ bệnh nhân.')),
            ListTile(
              leading: const Icon(Icons.person_add_outlined),
              title: const Text('Thêm hồ sơ mới'),
              onTap: () {
                Navigator.pop(sheetContext);
                _manageProfiles();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addToCart() async {
    final patient = _patient;
    final slot = _slot;
    if (_saving || patient == null || slot == null) return;
    setState(() => _saving = true);
    try {
      await _cart.add(
        doctorId: widget.doctorId!,
        patientProfileId: patient.id,
        date: _date,
        slot: slot,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm lịch hẹn vào giỏ.')),
      );
      Navigator.of(context).pushReplacementNamed('/cart');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _message(error, 'Không thêm được lịch hẹn. Vui lòng thử lại.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: const Text('Chọn ngày giờ khám')),
      body: _buildBody(),
    ),
  );

  Widget _buildBody() {
    if (widget.doctorId == null) {
      return const Center(child: Text('Vui lòng chọn bác sĩ trước.'));
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError case final message?) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              TextButton(onPressed: _load, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }
    final slots =
        _schedules
            .where((schedule) => schedule.day == _date.weekday % 7)
            .map((schedule) => schedule.slot)
            .toSet()
            .toList()
          ..sort();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Ngày khám', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickDate,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text('${_date.day}/${_date.month}/${_date.year}'),
            ),
            const SizedBox(height: 20),
            Text(
              'Khung giờ theo lịch bác sĩ',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (slots.isEmpty)
              const Text('Bác sĩ không có lịch làm việc vào ngày này.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final slot in slots)
                    ChoiceChip(
                      label: Text(slot),
                      selected: _slot == slot,
                      onSelected: _saving
                          ? null
                          : (_) => setState(() => _slot = slot),
                    ),
                ],
              ),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Đặt cho ai?'),
                subtitle: Text(_patient?.label ?? 'Chọn hồ sơ bệnh nhân'),
                trailing: const Icon(Icons.expand_more),
                onTap: _saving ? null : _pickPatient,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving || _slot == null || _patient == null
                  ? null
                  : _addToCart,
              icon: const Icon(Icons.add_shopping_cart_outlined),
              label: Text(_saving ? 'Đang thêm…' : 'Thêm vào giỏ hàng'),
            ),
          ],
        ),
      ),
    );
  }
}

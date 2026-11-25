import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../models/patient_profile.dart';
import '../../repositories/patient_profile_repository.dart';
import 'booking_profile_picker.dart';
import 'patient_profile_form_page.dart';

class PatientProfilesPage extends StatefulWidget {
  const PatientProfilesPage({
    super.key,
    this.repository,
    this.profiles,
    this.forBooking = false,
    this.embedded = false,
  });

  final PatientProfileRepository? repository;
  final List<PatientProfile>? profiles;
  final bool forBooking;
  final bool embedded;

  @override
  State<PatientProfilesPage> createState() => _PatientProfilesPageState();
}

class _PatientProfilesPageState extends State<PatientProfilesPage> {
  late final _repository = widget.repository ?? PatientProfileRepository();
  late List<PatientProfile> _profiles = List.of(widget.profiles ?? []);
  PatientProfile? _selected;
  bool _loading = false;
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.profiles == null) {
      _load();
    } else {
      _selectSelf();
    }
  }

  void _selectSelf() {
    if (!widget.forBooking) return;
    for (final profile in _profiles) {
      if (profile.relationship.trim().toLowerCase() == 'bản thân') {
        _selected = profile;
        return;
      }
    }
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
        _selectSelf();
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

  Future<void> _openForm([PatientProfile? existing]) async {
    if (_deleting) return;
    final profile = await Navigator.of(context).push<PatientProfile>(
      MaterialPageRoute(
        builder: (_) =>
            PatientProfileFormPage(repository: _repository, profile: existing),
      ),
    );
    if (!mounted || profile == null) return;
    setState(() {
      final index = _profiles.indexWhere((item) => item.id == profile.id);
      if (index == -1) {
        _profiles.add(profile);
      } else {
        _profiles[index] = profile;
      }
      if (widget.forBooking) _selected = profile;
    });
  }

  Future<bool> _confirmDelete(PatientProfile profile) async {
    if (_deleting) return false;
    setState(() => _deleting = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Xóa hồ sơ?'),
          content: Text('Bạn có chắc muốn xóa hồ sơ của ${profile.fullName}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xóa'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return false;
      await _repository.delete(profile.id);
      return mounted;
    } catch (error) {
      if (!mounted) return false;
      final message = error is ApiException
          ? error.displayMessage
          : 'Không xóa được hồ sơ. Vui lòng thử lại.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return false;
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _removeProfile(PatientProfile profile) {
    setState(() => _profiles.removeWhere((item) => item.id == profile.id));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.embedded
        ? null
        : AppBar(
            title: Text(widget.forBooking ? 'Đặt khám' : 'Hồ sơ bệnh nhân'),
            actions: [
              if (widget.forBooking)
                IconButton(
                  tooltip: 'Về trang chủ',
                  icon: const Icon(Icons.home_outlined),
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/home', (_) => false),
                ),
            ],
          ),
    body: _buildBody(),
    floatingActionButton: widget.forBooking || _loading || _error != null
        ? null
        : FloatingActionButton(
            onPressed: _deleting ? null : _openForm,
            tooltip: 'Thêm hồ sơ mới',
            child: const Icon(Icons.add),
          ),
  );

  Widget _buildBody() {
    Widget? status;
    if (_loading) status = const Center(child: CircularProgressIndicator());
    if (_error != null) {
      status = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            TextButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    if (widget.forBooking) {
      return BookingProfilePicker(
        profiles: _profiles,
        selectedId: _selected?.id,
        status: status,
        onAdd: status == null ? _openForm : null,
        onSelect: (profile) => setState(() => _selected = profile),
        onOpen: (profile) {
          setState(() => _selected = profile);
          Navigator.of(context).pushNamed('/departments', arguments: profile);
        },
      );
    }
    if (status != null) return status;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        if (_profiles.isEmpty) const Text('Bạn chưa có hồ sơ bệnh nhân.'),
        for (final profile in _profiles) _profileCard(profile),
      ],
    );
  }

  Widget _profileCard(PatientProfile profile) {
    final date = profile.dateOfBirth;
    final birthDate = date == null
        ? 'Chưa có ngày sinh'
        : formatBirthDate(date);
    return Card(
      key: ValueKey(profile.id),
      clipBehavior: Clip.antiAlias,
      child: Dismissible(
        key: ValueKey(profile.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: AlignmentDirectional.centerEnd,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          color: Theme.of(context).colorScheme.errorContainer,
          child: const Icon(Icons.delete_outline),
        ),
        confirmDismiss: (_) => _confirmDelete(profile),
        onDismissed: (_) => _removeProfile(profile),
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
          title: Text(profile.fullName),
          subtitle: Text(
            '${profile.relationship}\n$birthDate · ${profile.gender}',
          ),
          isThreeLine: true,
          onTap: () => _openForm(profile),
          trailing: IconButton(
            tooltip: 'Xóa hồ sơ',
            onPressed: _deleting
                ? null
                : () async {
                    if (await _confirmDelete(profile) && mounted) {
                      _removeProfile(profile);
                    }
                  },
            icon: const Icon(Icons.delete_outline),
          ),
        ),
      ),
    );
  }
}

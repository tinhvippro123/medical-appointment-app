import 'package:flutter/material.dart';
import 'package:medical_appointment_app/core/theme/app_theme.dart';
import 'package:medical_appointment_app/models/doctor.dart';
import 'package:medical_appointment_app/repositories/doctor_schedule_repository.dart';
import 'package:medical_appointment_app/screens/admin/doctors/schedule/doctor_schedule_logic.dart';
import 'package:medical_appointment_app/screens/admin/doctors/schedule/widgets/form_error_banner.dart';

/// Hàm chọn giờ tùy chỉnh (mặc định dùng `showTimePicker`, có thể override khi test)
typedef ScheduleTimePicker = Future<TimeOfDay?> Function(
  BuildContext context,
  TimeOfDay initialTime,
);

/// Bottom sheet biểu mẫu thêm hoặc sửa khung lịch làm việc của bác sĩ
class ScheduleFormSheet extends StatefulWidget {
  const ScheduleFormSheet({
    super.key,
    required this.doctorId,
    required this.scheduleRepository,
    this.schedule,
    this.timePicker,
  });

  final int doctorId;
  final DoctorScheduleRepository scheduleRepository;
  final DoctorSchedule? schedule;
  final ScheduleTimePicker? timePicker;

  bool get isEdit => schedule != null;

  @override
  State<ScheduleFormSheet> createState() => _ScheduleFormSheetState();
}

class _ScheduleFormSheetState extends State<ScheduleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _startTimeController;
  late final TextEditingController _endTimeController;
  late final TextEditingController _maxPatientsController;

  int? _selectedDayOfWeek;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isSubmitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    final existing = widget.schedule;
    if (existing != null) {
      _selectedDayOfWeek = existing.dayOfWeek == 7 ? 0 : existing.dayOfWeek;
      _startTime = parseTimeOfDay(existing.startTime);
      _endTime = parseTimeOfDay(existing.endTime);
    }

    _startTimeController = TextEditingController(
      text: _startTime != null ? formatTimeOfDayDisplay(_startTime!) : '',
    );
    _endTimeController = TextEditingController(
      text: _endTime != null ? formatTimeOfDayDisplay(_endTime!) : '',
    );
    _maxPatientsController = TextEditingController(
      text: existing != null && existing.maxPatients > 0
          ? existing.maxPatients.toString()
          : '20',
    );
  }

  @override
  void dispose() {
    _startTimeController.dispose();
    _endTimeController.dispose();
    _maxPatientsController.dispose();
    super.dispose();
  }

  Future<TimeOfDay?> _openTimePicker(TimeOfDay initialTime) {
    if (widget.timePicker != null) {
      return widget.timePicker!(context, initialTime);
    }
    return showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initialTime = isStart
        ? (_startTime ?? const TimeOfDay(hour: 7, minute: 0))
        : (_endTime ?? const TimeOfDay(hour: 11, minute: 30));
    final picked = await _openTimePicker(initialTime);
    if (!mounted || picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
        _startTimeController.text = formatTimeOfDayDisplay(picked);
      } else {
        _endTime = picked;
        _endTimeController.text = formatTimeOfDayDisplay(picked);
      }
      _submitError = null;
    });
  }

  Future<void> _pickStartTime() => _pickTime(isStart: true);

  Future<void> _pickEndTime() => _pickTime(isStart: false);

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final input = DoctorScheduleFormInput(
        dayOfWeek: _selectedDayOfWeek!,
        startTime: formatTimeOfDayApi(_startTime!),
        endTime: formatTimeOfDayApi(_endTime!),
        maxPatients: int.parse(_maxPatientsController.text.trim()),
      );

      if (widget.isEdit) {
        await widget.scheduleRepository.updateSchedule(
          widget.schedule!.id,
          input,
        );
      } else {
        await widget.scheduleRepository.createSchedule(
          widget.doctorId,
          input,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = extractScheduleErrorMessage(
          e,
          fallback: 'Không thể lưu lịch làm việc. Vui lòng thử lại.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.isEdit ? 'Sửa lịch làm việc' : 'Thêm lịch làm việc',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Đóng',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<int>(
                key: const ValueKey('schedule-day-dropdown'),
                initialValue: _selectedDayOfWeek,
                decoration: InputDecoration(
                  labelText: 'Thứ trong tuần *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                ),
                hint: const Text('Chọn thứ'),
                items: orderedScheduleDays.map((day) {
                  return DropdownMenuItem<int>(
                    value: day,
                    child: Text(DoctorSchedule.dayOfWeekLabel(day)),
                  );
                }).toList(),
                onChanged: _isSubmitting
                    ? null
                    : (val) => setState(() {
                        _selectedDayOfWeek = val;
                        _submitError = null;
                      }),
                validator: validateScheduleDayOfWeek,
              ),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('schedule-start-time-field'),
                      controller: _startTimeController,
                      readOnly: true,
                      onTap: _isSubmitting ? null : _pickStartTime,
                      decoration: InputDecoration(
                        labelText: 'Giờ bắt đầu *',
                        hintText: '07:00',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.access_time_outlined),
                      ),
                      validator: (_) => validateScheduleStartTime(_startTime),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('schedule-end-time-field'),
                      controller: _endTimeController,
                      readOnly: true,
                      onTap: _isSubmitting ? null : _pickEndTime,
                      decoration: InputDecoration(
                        labelText: 'Giờ kết thúc *',
                        hintText: '11:30',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.access_time_filled_outlined),
                      ),
                      validator: (_) =>
                          validateScheduleEndTime(_startTime, _endTime),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                key: const ValueKey('schedule-max-patients-field'),
                controller: _maxPatientsController,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Số bệnh nhân tối đa *',
                  hintText: '20',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.groups_outlined),
                ),
                onChanged: (_) {
                  if (_submitError != null) {
                    setState(() => _submitError = null);
                  }
                },
                validator: validateMaxPatients,
              ),

              if (_submitError != null) ...[
                const SizedBox(height: 14),
                FormErrorBanner(
                  key: const ValueKey('schedule-form-error'),
                  message: _submitError!,
                ),
              ],
              const SizedBox(height: 20),

              FilledButton(
                key: const ValueKey('submit-schedule-button'),
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        widget.isEdit ? 'Lưu thay đổi' : 'Lưu lịch làm việc',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
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

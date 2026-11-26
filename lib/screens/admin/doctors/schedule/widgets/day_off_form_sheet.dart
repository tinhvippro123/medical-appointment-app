import 'package:flutter/material.dart';
import 'package:medical_appointment_app/core/theme/app_theme.dart';
import 'package:medical_appointment_app/models/doctor_day_off.dart';
import 'package:medical_appointment_app/repositories/doctor_day_off_repository.dart';
import 'package:medical_appointment_app/screens/admin/doctors/schedule/doctor_schedule_logic.dart';
import 'package:medical_appointment_app/screens/admin/doctors/schedule/widgets/form_error_banner.dart';

/// Hàm chọn ngày tùy chỉnh (mặc định dùng `showDatePicker`, có thể override khi test)
typedef DayOffDatePicker = Future<DateTime?> Function(
  BuildContext context,
  DateTime initialDate,
  DateTime firstDate,
  DateTime lastDate,
);

/// Bottom sheet biểu mẫu thêm ngày nghỉ mới cho bác sĩ
class DayOffFormSheet extends StatefulWidget {
  const DayOffFormSheet({
    super.key,
    required this.doctorId,
    required this.dayOffRepository,
    this.now,
    this.datePicker,
  });

  final int doctorId;
  final DoctorDayOffRepository dayOffRepository;
  final DateTime? now;
  final DayOffDatePicker? datePicker;

  @override
  State<DayOffFormSheet> createState() => _DayOffFormSheetState();
}

class _DayOffFormSheetState extends State<DayOffFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController();
  final _reasonController = TextEditingController();

  DateTime? _selectedDate;
  bool _isSubmitting = false;
  String? _submitError;

  @override
  void dispose() {
    _dateController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = vietnamToday(widget.now);
    final initialDate =
        _selectedDate != null && !_selectedDate!.isBefore(today)
            ? _selectedDate!
            : today;

    final lastDate = DateTime(today.year + 2, today.month, today.day);
    final picked = widget.datePicker != null
        ? await widget.datePicker!(context, initialDate, today, lastDate)
        : await showDatePicker(
            context: context,
            initialDate: initialDate,
            firstDate: today,
            lastDate: lastDate,
          );
    if (!mounted || picked == null) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
      _dateController.text = DoctorDayOff.formatDisplayDate(_selectedDate!);
      _submitError = null;
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final reasonText = _reasonController.text.trim();
      final input = DoctorDayOffFormInput(
        date: _selectedDate!,
        reason: reasonText.isEmpty ? null : reasonText,
      );

      await widget.dayOffRepository.createDayOff(widget.doctorId, input);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = extractScheduleErrorMessage(
          e,
          fallback: 'Không thể thêm ngày nghỉ. Vui lòng thử lại.',
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
                  const Expanded(
                    child: Text(
                      'Thêm ngày nghỉ',
                      style: TextStyle(
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

              TextFormField(
                key: const ValueKey('day-off-date-field'),
                controller: _dateController,
                readOnly: true,
                onTap: _isSubmitting ? null : _pickDate,
                decoration: InputDecoration(
                  labelText: 'Ngày nghỉ *',
                  hintText: 'Chọn ngày (từ hôm nay)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.event_rounded),
                ),
                validator: (_) =>
                    validateDayOffDate(_selectedDate, now: widget.now),
              ),
              const SizedBox(height: 16),

              TextFormField(
                key: const ValueKey('day-off-reason-field'),
                controller: _reasonController,
                enabled: !_isSubmitting,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Lý do nghỉ (không bắt buộc)',
                  hintText: 'Ví dụ: Nghỉ phép, Hội thảo chuyên môn...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (_) {
                  if (_submitError != null) {
                    setState(() => _submitError = null);
                  }
                },
                validator: validateDayOffReason,
              ),

              if (_submitError != null) ...[
                const SizedBox(height: 14),
                FormErrorBanner(
                  key: const ValueKey('day-off-form-error'),
                  message: _submitError!,
                ),
              ],
              const SizedBox(height: 20),

              FilledButton(
                key: const ValueKey('submit-day-off-button'),
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
                    : const Text(
                        'Lưu ngày nghỉ',
                        style: TextStyle(
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

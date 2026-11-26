import 'package:flutter/material.dart';
import 'package:medical_appointment_app/core/network/api_exception.dart';

// Backend quy ước 0 = Chủ nhật, 1 = Thứ 2 .. 6 = Thứ 7
const List<int> orderedScheduleDays = [1, 2, 3, 4, 5, 6, 0];

// Ngày hiện tại (00:00:00) theo giờ Việt Nam (UTC+7)
DateTime vietnamToday([DateTime? now]) {
  final DateTime vn;
  if (now == null) {
    vn = DateTime.now().toUtc().add(const Duration(hours: 7));
  } else if (now.isUtc) {
    vn = now.add(const Duration(hours: 7));
  } else {
    vn = now;
  }
  return DateTime(vn.year, vn.month, vn.day);
}

String formatTimeOfDayDisplay(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

String formatTimeOfDayApi(TimeOfDay time) =>
    '${formatTimeOfDayDisplay(time)}:00';

TimeOfDay? parseTimeOfDay(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final parts = trimmed.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0].trim());
  final minute = int.tryParse(parts[1].trim());
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String? validateScheduleDayOfWeek(int? dayOfWeek) {
  if (dayOfWeek == null || dayOfWeek < 0 || dayOfWeek > 6) {
    return 'Vui lòng chọn thứ trong tuần';
  }
  return null;
}

String? validateScheduleStartTime(TimeOfDay? startTime) {
  if (startTime == null) {
    return 'Vui lòng chọn giờ bắt đầu';
  }
  return null;
}

String? validateScheduleEndTime(TimeOfDay? startTime, TimeOfDay? endTime) {
  if (endTime == null) {
    return 'Vui lòng chọn giờ kết thúc';
  }
  if (startTime != null) {
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    if (startMinutes >= endMinutes) {
      return 'Giờ bắt đầu phải nhỏ hơn giờ kết thúc';
    }
  }
  return null;
}

String? validateMaxPatients(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Vui lòng nhập số bệnh nhân tối đa';
  }
  final parsed = int.tryParse(value.trim());
  if (parsed == null || parsed <= 0) {
    return 'Số bệnh nhân tối đa phải lớn hơn 0';
  }
  return null;
}

String? validateDayOffDate(DateTime? date, {DateTime? now}) {
  if (date == null) {
    return 'Vui lòng chọn ngày nghỉ';
  }
  final selected = DateTime(date.year, date.month, date.day);
  final today = vietnamToday(now);
  if (selected.isBefore(today)) {
    return 'Không thể đăng ký ngày nghỉ trong quá khứ';
  }
  return null;
}

String? validateDayOffReason(String? value) {
  if (value != null && value.trim().length > 200) {
    return 'Lý do không được vượt quá 200 ký tự';
  }
  return null;
}

String extractScheduleErrorMessage(
  Object error, {
  required String fallback,
}) {
  if (error is ApiException) {
    return error.displayMessage;
  }
  return fallback;
}

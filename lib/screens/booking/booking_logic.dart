import '../../core/network/api_exception.dart';
import '../../models/doctor.dart';

/// Khung giờ khám 1 giờ sau khi tách từ lịch làm việc của bác sĩ.
class BookingTimeSlot {
  final int startMinutes;
  final int endMinutes;
  final String label;

  const BookingTimeSlot({
    required this.startMinutes,
    required this.endMinutes,
    required this.label,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookingTimeSlot &&
          runtimeType == other.runtimeType &&
          startMinutes == other.startMinutes &&
          endMinutes == other.endMinutes &&
          label == other.label;

  @override
  int get hashCode => Object.hash(startMinutes, endMinutes, label);

  @override
  String toString() => label;
}

/// Trả về thời điểm hiện tại theo múi giờ Việt Nam (UTC+7).
/// Nếu [now] được truyền vào:
/// - Nếu `now.isUtc == true`: cộng +7 giờ để quy sang giờ Việt Nam.
/// - Nếu `now.isUtc == false`: coi như đã là giờ địa phương Việt Nam (phục vụ test ổn định).
DateTime vietnamNow([DateTime? now]) {
  if (now == null) {
    final vn = DateTime.now().toUtc().add(const Duration(hours: 7));
    return DateTime(
      vn.year,
      vn.month,
      vn.day,
      vn.hour,
      vn.minute,
      vn.second,
      vn.millisecond,
    );
  }
  if (now.isUtc) {
    final vn = now.add(const Duration(hours: 7));
    return DateTime(
      vn.year,
      vn.month,
      vn.day,
      vn.hour,
      vn.minute,
      vn.second,
      vn.millisecond,
    );
  }
  return DateTime(
    now.year,
    now.month,
    now.day,
    now.hour,
    now.minute,
    now.second,
    now.millisecond,
  );
}

/// Chuẩn hóa DateTime về chỉ gồm ngày (00:00:00).
DateTime normalizeDateOnly(DateTime date) =>
    DateTime(date.year, date.month, date.day);

/// Định dạng ngày gửi API: "yyyy-MM-dd".
String formatApiDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Định dạng ngày hiển thị UI: "dd/MM/yyyy".
String formatDisplayDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.year}';

/// Quy đổi `DateTime.weekday` (1=T2..7=CN) sang quy ước backend `DayOfWeek` (0=CN..6=T7).
int toBackendDayOfWeek(DateTime date) => date.weekday % 7;

/// Chuẩn hóa `dayOfWeek` từ schedule (7 được quy về 0 = Chủ nhật).
int normalizeScheduleDayOfWeek(int dayOfWeek) =>
    dayOfWeek == 7 ? 0 : dayOfWeek;

/// Parse chuỗi giờ `"HH:mm:ss"` hoặc `"HH:mm"` thành tổng số phút tính từ 00:00.
/// Trả `null` nếu không hợp lệ.
int? parseTimeToMinutes(String time) {
  final trimmed = time.trim();
  if (trimmed.isEmpty) return null;
  final parts = trimmed.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0].trim());
  final minute = int.tryParse(parts[1].trim());
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return hour * 60 + minute;
}

/// Định dạng số phút từ 00:00 thành `"HH:mm"`.
String formatMinutesToHHmm(int totalMinutes) {
  final h = (totalMinutes ~/ 60).toString().padLeft(2, '0');
  final m = (totalMinutes % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

// Ngày hợp lệ trên Calendar: thuộc [firstDate, lastDate], không phải ngày nghỉ và có lịch làm việc trong thứ đó.
bool isBookingDaySelectable({
  required DateTime day,
  required List<DoctorSchedule> schedules,
  Set<DateTime> dayOffDates = const {},
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  if (schedules.isEmpty) return false;

  final d = normalizeDateOnly(day);
  final minDate = normalizeDateOnly(firstDate);
  final maxDate = normalizeDateOnly(lastDate);

  if (d.isBefore(minDate) || d.isAfter(maxDate)) {
    return false;
  }

  for (final off in dayOffDates) {
    final normalizedOff = normalizeDateOnly(off);
    if (normalizedOff.year == d.year &&
        normalizedOff.month == d.month &&
        normalizedOff.day == d.day) {
      return false;
    }
  }

  final targetDow = toBackendDayOfWeek(d);
  return schedules.any(
    (s) => normalizeScheduleDayOfWeek(s.dayOfWeek) == targetDow,
  );
}

/// Tìm ngày hợp lệ đầu tiên trong khoảng `[firstDate, lastDate]` thỏa [isBookingDaySelectable].
/// Trả `null` nếu không có ngày nào chọn được (để tránh crash `CalendarDatePicker`).
DateTime? findFirstSelectableDate({
  required List<DoctorSchedule> schedules,
  Set<DateTime> dayOffDates = const {},
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  if (schedules.isEmpty) return null;
  final start = normalizeDateOnly(firstDate);
  final end = normalizeDateOnly(lastDate);
  if (start.isAfter(end)) return null;

  var current = start;
  while (!current.isAfter(end)) {
    if (isBookingDaySelectable(
      day: current,
      schedules: schedules,
      dayOffDates: dayOffDates,
      firstDate: start,
      lastDate: end,
    )) {
      return current;
    }
    current = DateTime(current.year, current.month, current.day + 1);
  }
  return null;
}

/// Kiểm tra bác sĩ có ca làm việc vào thứ của [date] hay không (chưa xét giờ qua).
bool hasAnyScheduleForDate(DateTime date, List<DoctorSchedule> schedules) {
  final targetDow = toBackendDayOfWeek(date);
  return schedules.any(
    (s) => normalizeScheduleDayOfWeek(s.dayOfWeek) == targetDow,
  );
}

/// Sinh danh sách slot 1 giờ cho ngày [date] từ danh sách [schedules].
/// - Quy tắc slot lẻ cuối ca: mỗi slot dài đúng 60 phút (`current + 60 <= endMinutes`),
///   phần lẻ nhỏ hơn 60 phút ở cuối ca bị BỎ (ví dụ 07:00-11:30 → 07:00-08:00..10:00-11:00).
/// - Nhiều ca trong cùng ngày: gộp lại, loại trùng và sắp xếp tăng dần theo giờ.
/// - Nếu [date] là ngày hôm nay (theo UTC+7 từ [now]): lọc bỏ slot có giờ bắt đầu `<= giờ hiện tại`.
/// - Nếu [date] là ngày quá khứ (trước hôm nay theo UTC+7): trả về danh sách rỗng.
List<BookingTimeSlot> generateHourlySlotsForDate({
  required DateTime date,
  required List<DoctorSchedule> schedules,
  DateTime? now,
}) {
  if (schedules.isEmpty) return const [];

  final vnNow = vietnamNow(now);
  final todayVn = normalizeDateOnly(vnNow);
  final targetDate = normalizeDateOnly(date);

  if (targetDate.isBefore(todayVn)) {
    return const [];
  }

  final isToday = targetDate.year == todayVn.year &&
      targetDate.month == todayVn.month &&
      targetDate.day == todayVn.day;
  final nowMinutes = vnNow.hour * 60 + vnNow.minute;

  final targetDow = toBackendDayOfWeek(targetDate);
  final matchingSchedules = schedules.where(
    (s) => normalizeScheduleDayOfWeek(s.dayOfWeek) == targetDow,
  );

  final uniqueSlots = <String, BookingTimeSlot>{};

  for (final schedule in matchingSchedules) {
    final startMin = parseTimeToMinutes(schedule.startTime);
    final endMin = parseTimeToMinutes(schedule.endTime);
    if (startMin == null || endMin == null || startMin >= endMin) {
      continue;
    }

    var current = startMin;
    while (current + 60 <= endMin) {
      final slotEnd = current + 60;
      // Lọc slot đã qua trong ngày hôm nay (khớp OrderService: slotStart <= currentTimeOfDay)
      if (!isToday || current > nowMinutes) {
        final label =
            '${formatMinutesToHHmm(current)}-${formatMinutesToHHmm(slotEnd)}';
        uniqueSlots[label] = BookingTimeSlot(
          startMinutes: current,
          endMinutes: slotEnd,
          label: label,
        );
      }
      current += 60;
    }
  }

  final result = uniqueSlots.values.toList()
    ..sort((a, b) {
      final cmp = a.startMinutes.compareTo(b.startMinutes);
      return cmp != 0 ? cmp : a.endMinutes.compareTo(b.endMinutes);
    });

  return result;
}

/// Ánh xạ lỗi từ API đặt lịch/giỏ hàng sang thông báo tiếng Việt thân thiện.
/// Ưu tiên kiểm tra `errorCode` trước `statusCode` (ví dụ backend trả 400 cho `DOCTOR_NOT_FOUND`).
String mapBookingErrorMessage(Object error) {
  if (error is ApiException) {
    switch (error.errorCode) {
      case 'DOCTOR_NOT_FOUND':
        return 'Không tìm thấy thông tin bác sĩ hoặc bác sĩ đã ngừng hoạt động.';
      case 'INVALID_PATIENT_PROFILE':
        return 'Hồ sơ bệnh nhân không hợp lệ hoặc không thuộc tài khoản của bạn.';
      case 'INVALID_TIME_SLOT':
        return 'Khung giờ không nằm trong lịch làm việc của bác sĩ.';
      case 'CART_ITEM_DUPLICATE':
        return 'Lịch này đã có trong giỏ hàng';
      case 'APPOINTMENT_TIME_PASSED':
        return 'Giờ khám đã trôi qua, vui lòng chọn khung giờ khác.';
      case 'DOCTOR_ON_LEAVE':
        return 'Bác sĩ nghỉ khám vào ngày này, vui lòng chọn ngày khác.';
      case 'TIME_SLOT_FULL':
        return 'Khung giờ này đã đầy, vui lòng chọn giờ khác.';
      case 'PATIENT_SCHEDULE_CONFLICT':
        return 'Hồ sơ bệnh nhân đã có lịch khám trong khung giờ này.';
      case 'DOCTOR_UNAVAILABLE':
        return 'Bác sĩ hiện không nhận lịch khám.';
    }

    if (error.statusCode == 401) {
      return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    }

    // Lỗi 400 ValidationProblemDetails (không có errorCode): lấy message đầu tiên trong fieldErrors
    if (error.fieldErrors.isNotEmpty) {
      for (final messages in error.fieldErrors.values) {
        for (final msg in messages) {
          if (msg.trim().isNotEmpty) {
            return msg.trim();
          }
        }
      }
    }

    return error.displayMessage;
  }

  return 'Đã có lỗi xảy ra. Vui lòng thử lại.';
}

import 'doctor.dart';

/// Model đại diện cho một ngày nghỉ của bác sĩ từ backend
class DoctorDayOff {
  final int id;
  final int doctorId;
  final DateTime date;
  final String? reason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DoctorDayOff({
    required this.id,
    required this.doctorId,
    required this.date,
    this.reason,
    this.createdAt,
    this.updatedAt,
  });

  /// Ngày đã chuẩn hóa chỉ gồm năm-tháng-ngày (00:00:00)
  DateTime get dateOnly => DateTime(date.year, date.month, date.day);

  /// Định dạng ngày gửi API: "yyyy-MM-dd"
  static String formatApiDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Định dạng ngày hiển thị UI: "dd/MM/yyyy"
  static String formatDisplayDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year.toString().padLeft(4, '0')}';

  String get dateApiString => formatApiDate(dateOnly);
  String get dateDisplay => formatDisplayDate(dateOnly);

  /// Tên thứ trong tuần của ngày nghỉ (tái dùng ánh xạ 0=Chủ nhật..6=Thứ 7)
  String get dayOfWeekLabel =>
      DoctorSchedule.dayOfWeekLabel(dateOnly.weekday % 7);

  factory DoctorDayOff.fromJson(Map<String, dynamic> json) {
    final rawDate = (json['date'] ?? '').toString();
    final parsed = DateTime.tryParse(rawDate);
    final normalized = parsed != null
        ? DateTime(parsed.year, parsed.month, parsed.day)
        : DateTime(1970, 1, 1);

    return DoctorDayOff(
      id: (json['id'] as num?)?.toInt() ?? 0,
      doctorId: (json['doctorId'] as num?)?.toInt() ?? 0,
      date: normalized,
      reason: json['reason'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'doctorId': doctorId,
    'date': dateApiString,
    if (reason != null) 'reason': reason,
  };
}

/// Dữ liệu đầu vào cho Form tạo mới ngày nghỉ bác sĩ
class DoctorDayOffFormInput {
  final DateTime date;
  final String? reason;

  const DoctorDayOffFormInput({
    required this.date,
    this.reason,
  });

  Map<String, dynamic> toJson() {
    final trimmedReason = reason?.trim();
    return {
      'date': DoctorDayOff.formatApiDate(date),
      if (trimmedReason != null && trimmedReason.isNotEmpty)
        'reason': trimmedReason,
    };
  }
}

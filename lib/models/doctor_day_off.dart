/// Model đại diện cho một ngày nghỉ của bác sĩ từ backend
class DoctorDayOff {
  final int id;
  final int doctorId;
  final DateTime date;
  final String? reason;

  const DoctorDayOff({
    required this.id,
    required this.doctorId,
    required this.date,
    this.reason,
  });

  /// Ngày đã chuẩn hóa chỉ gồm năm-tháng-ngày (00:00:00)
  DateTime get dateOnly => DateTime(date.year, date.month, date.day);

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
    );
  }
}

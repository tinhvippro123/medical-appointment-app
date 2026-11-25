/// Model đại diện cho Hồ sơ bệnh nhân dùng khi đặt lịch khám
class PatientProfile {
  final int id;
  final String fullName;
  final DateTime? dateOfBirth;
  final String gender;
  final String relationship;

  const PatientProfile({
    required this.id,
    required this.fullName,
    this.dateOfBirth,
    this.gender = '',
    required this.relationship,
  });

  /// Nhãn hiển thị gọn trong dropdown: "Nguyễn Văn A (Bản thân)"
  String get displayLabel {
    final name = fullName.trim();
    final rel = relationship.trim();
    if (name.isEmpty) return rel.isEmpty ? 'Hồ sơ #$id' : rel;
    if (rel.isEmpty) return name;
    return '$name ($rel)';
  }

  /// Nhãn hiển thị dùng ở danh sách chọn hồ sơ đặt khám
  String get label => '$fullName — $relationship';

  factory PatientProfile.fromJson(Map<String, dynamic> json) => PatientProfile(
    id: (json['id'] as num?)?.toInt() ?? 0,
    fullName: (json['fullName'] ?? '').toString(),
    dateOfBirth: json['dateOfBirth'] != null
        ? DateTime.tryParse(json['dateOfBirth'].toString())
        : null,
    gender: (json['gender'] ?? '').toString(),
    relationship: (json['relationship'] ?? '').toString(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'dateOfBirth': dateOfBirth?.toIso8601String(),
    'gender': gender,
    'relationship': relationship,
  };
}

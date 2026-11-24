/// Model đại diện cho thông tin Bác sĩ từ backend
class Doctor {
  final int id;
  final String fullName;
  final String? qualification;
  final String? email;
  final String? phone;
  final int departmentId;
  final String departmentName;
  final int? roomId;
  final String? roomNumber;
  final int? floor;
  final String? description;
  final String? avatarUrl;
  final int experienceYears;
  final double consultationFee;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Doctor({
    required this.id,
    required this.fullName,
    this.qualification,
    this.email,
    this.phone,
    required this.departmentId,
    required this.departmentName,
    this.roomId,
    this.roomNumber,
    this.floor,
    this.description,
    this.avatarUrl,
    required this.experienceYears,
    required this.consultationFee,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  /// Chuỗi hiển thị thông tin phòng khám
  String get roomDisplay {
    if (roomNumber != null && roomNumber!.isNotEmpty) {
      if (floor != null && floor! > 0) {
        return 'Phòng $roomNumber (Tầng $floor)';
      }
      return 'Phòng $roomNumber';
    }
    return 'Chưa gán phòng';
  }

  /// Định dạng phí khám dạng tiền tệ VNĐ (ví dụ: 150.000 đ)
  String get feeFormatted {
    final feeInt = consultationFee.toInt();
    final s = feeInt.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(s[i]);
    }
    return '${buffer.toString()} đ';
  }

  factory Doctor.fromJson(Map<String, dynamic> json) => Doctor(
    id: json['id'] as int,
    fullName: (json['fullName'] ?? '').toString(),
    qualification: json['qualification'] as String?,
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    departmentId: (json['departmentId'] as num?)?.toInt() ?? 0,
    departmentName: (json['departmentName'] ?? '').toString(),
    roomId: (json['roomId'] as num?)?.toInt(),
    roomNumber: json['roomNumber'] as String?,
    floor: (json['floor'] as num?)?.toInt(),
    description: json['description'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
    experienceYears: (json['experienceYears'] as num?)?.toInt() ?? 0,
    consultationFee: (json['consultationFee'] as num?)?.toDouble() ?? 0.0,
    isActive: json['isActive'] as bool? ?? true,
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'].toString())
        : null,
    updatedAt: json['updatedAt'] != null
        ? DateTime.tryParse(json['updatedAt'].toString())
        : null,
  );
}

/// Dữ liệu đầu vào cho Form tạo mới hoặc cập nhật bác sĩ
class DoctorFormInput {
  final String fullName;
  final String? qualification;
  final String? email;
  final String? phone;
  final int departmentId;
  final int? roomId;
  final String? description;
  final int experienceYears;
  final double consultationFee;

  const DoctorFormInput({
    required this.fullName,
    this.qualification,
    this.email,
    this.phone,
    required this.departmentId,
    this.roomId,
    this.description,
    required this.experienceYears,
    required this.consultationFee,
  });

  /// Chuyển đổi thành `Map<String, String>` cho multipart fields
  Map<String, String> toFields() {
    final map = <String, String>{
      'FullName': fullName.trim(),
      'DepartmentId': departmentId.toString(),
      'ExperienceYears': experienceYears.toString(),
      'ConsultationFee': consultationFee.toInt().toString(),
    };

    if (qualification != null && qualification!.trim().isNotEmpty) {
      map['Qualification'] = qualification!.trim();
    }
    if (email != null && email!.trim().isNotEmpty) {
      map['Email'] = email!.trim();
    }
    if (phone != null && phone!.trim().isNotEmpty) {
      map['Phone'] = phone!.trim();
    }
    if (roomId != null) {
      map['RoomId'] = roomId.toString();
    }
    if (description != null && description!.trim().isNotEmpty) {
      map['Description'] = description!.trim();
    }

    return map;
  }
}

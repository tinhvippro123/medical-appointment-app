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
  final List<DoctorSchedule> schedules;

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
    this.schedules = const [],
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

  /// Chuỗi hiển thị chi tiết phòng khám: "Phòng {RoomNumber}, Tầng {Floor}" hoặc "Chưa cập nhật"
  String get roomDetailDisplay {
    if (roomNumber != null && roomNumber!.trim().isNotEmpty) {
      if (floor != null) {
        return 'Phòng $roomNumber, Tầng $floor';
      }
      return 'Phòng $roomNumber';
    }
    return 'Chưa cập nhật';
  }

  /// Danh sách lịch làm việc đã gom và sắp xếp từ Thứ 2 đến Chủ nhật
  List<GroupedDoctorSchedule> get groupedSchedules =>
      GroupedDoctorSchedule.groupAndSort(schedules);

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
    id: (json['id'] as num?)?.toInt() ?? 0,
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
    schedules: (json['schedules'] as List<dynamic>?)
            ?.whereType<Map>()
            .map((e) => DoctorSchedule.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const [],
  );
}

/// Model đại diện cho một khung lịch làm việc của Bác sĩ
class DoctorSchedule {
  final int id;
  final int dayOfWeek; // 0=Chủ nhật, 1=Thứ 2, ..., 6=Thứ 7
  final String startTime;
  final String endTime;
  final int maxPatients;

  const DoctorSchedule({
    this.id = 0,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.maxPatients = 0,
  });

  /// Tên thứ trong tuần hiển thị bằng tiếng Việt
  String get dayName {
    switch (dayOfWeek) {
      case 1:
        return 'Thứ 2';
      case 2:
        return 'Thứ 3';
      case 3:
        return 'Thứ 4';
      case 4:
        return 'Thứ 5';
      case 5:
        return 'Thứ 6';
      case 6:
        return 'Thứ 7';
      case 0:
      case 7:
        return 'Chủ nhật';
      default:
        return 'Thứ $dayOfWeek';
    }
  }

  /// Cắt giây giờ từ "HH:mm:ss" hoặc "HH:mm" thành "HH:mm"
  static String formatTime(String time) {
    final trimmed = time.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split(':');
    if (parts.length >= 2) {
      final hour = parts[0].padLeft(2, '0');
      final minute = parts[1].padLeft(2, '0');
      return '$hour:$minute';
    }
    return trimmed;
  }

  String get startTimeFormatted => formatTime(startTime);
  String get endTimeFormatted => formatTime(endTime);

  /// Chuỗi hiển thị khung giờ "HH:mm-HH:mm"
  String get timeRangeDisplay {
    final start = startTimeFormatted;
    final end = endTimeFormatted;
    if (start.isEmpty && end.isEmpty) return '';
    if (end.isEmpty) return start;
    if (start.isEmpty) return end;
    return '$start-$end';
  }

  factory DoctorSchedule.fromJson(Map<String, dynamic> json) => DoctorSchedule(
    id: (json['id'] as num?)?.toInt() ?? 0,
    dayOfWeek: (json['dayOfWeek'] as num?)?.toInt() ?? 0,
    startTime: (json['startTime'] ?? '').toString(),
    endTime: (json['endTime'] ?? '').toString(),
    maxPatients: (json['maxPatients'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'dayOfWeek': dayOfWeek,
    'startTime': startTime,
    'endTime': endTime,
    'maxPatients': maxPatients,
  };
}

/// Nhóm các khung giờ làm việc theo từng thứ trong tuần, sắp xếp từ Thứ 2 đến Chủ nhật
class GroupedDoctorSchedule {
  final int dayOfWeek;
  final String dayName;
  final List<DoctorSchedule> slots;

  const GroupedDoctorSchedule({
    required this.dayOfWeek,
    required this.dayName,
    required this.slots,
  });

  /// Danh sách khung giờ gom lại, ví dụ: "07:00-11:30, 13:30-17:00"
  String get timeSlotsDisplay {
    return slots
        .map((s) => s.timeRangeDisplay)
        .where((s) => s.isNotEmpty)
        .join(', ');
  }

  /// Chuỗi gom đầy đủ: "Thứ 2: 07:00-11:30, 13:30-17:00"
  String get fullDisplay => '$dayName: $timeSlotsDisplay';

  /// Gom danh sách lịch làm việc theo thứ và sắp xếp từ Thứ 2 đến Chủ nhật
  static List<GroupedDoctorSchedule> groupAndSort(List<DoctorSchedule> schedules) {
    if (schedules.isEmpty) return const [];

    // Gom theo dayOfWeek (chuẩn hóa 7 thành 0 nếu có)
    final map = <int, List<DoctorSchedule>>{};
    for (final s in schedules) {
      final normalizedDay = (s.dayOfWeek == 7) ? 0 : s.dayOfWeek;
      map.putIfAbsent(normalizedDay, () => []).add(s);
    }

    // Sắp xếp các slot trong mỗi ngày theo startTime
    for (final list in map.values) {
      list.sort((a, b) => a.startTime.compareTo(b.startTime));
    }

    // Sắp xếp các thứ từ Thứ 2 (1) -> Thứ 7 (6) -> Chủ nhật (0/7 coi như 7)
    final sortedDays = map.keys.toList()
      ..sort((a, b) {
        final orderA = (a == 0) ? 7 : a;
        final orderB = (b == 0) ? 7 : b;
        return orderA.compareTo(orderB);
      });

    return sortedDays.map((day) {
      final slots = map[day]!;
      final dayName = slots.first.dayName;
      return GroupedDoctorSchedule(
        dayOfWeek: day,
        dayName: dayName,
        slots: slots,
      );
    }).toList();
  }
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

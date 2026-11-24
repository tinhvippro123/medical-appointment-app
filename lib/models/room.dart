/// Model đại diện cho phòng khám
class Room {
  final int id;
  final String roomNumber;
  final int floor;
  final int departmentId;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Room({
    required this.id,
    required this.roomNumber,
    required this.floor,
    required this.departmentId,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  /// Chuỗi hiển thị tên phòng và tầng cho Dropdown
  String get displayLabel => 'Phòng $roomNumber (Tầng $floor)';

  factory Room.fromJson(Map<String, dynamic> json) => Room(
    id: json['id'] as int,
    roomNumber: (json['roomNumber'] ?? '').toString(),
    floor: (json['floor'] as num?)?.toInt() ?? 0,
    departmentId: (json['departmentId'] as num?)?.toInt() ?? 0,
    isActive: json['isActive'] as bool? ?? true,
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'].toString())
        : null,
    updatedAt: json['updatedAt'] != null
        ? DateTime.tryParse(json['updatedAt'].toString())
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'roomNumber': roomNumber,
    'floor': floor,
    'departmentId': departmentId,
    'isActive': isActive,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };
}

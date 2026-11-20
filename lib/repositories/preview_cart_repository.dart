import 'cart_repository.dart';

/// Dữ liệu xem thử lưu trong bộ nhớ, không gửi tới máy chủ.
class PreviewCartRepository extends CartRepository {
  PreviewCartRepository() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final date =
        '${tomorrow.year.toString().padLeft(4, '0')}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
    items = [
      _item(
        1,
        'BS. Nguyễn Minh Anh',
        'Nội tổng quát',
        'Nguyễn Văn An',
        150000,
        date,
        '08:00-09:00',
      ),
      _item(
        2,
        'BS. Trần Thu Hà',
        'Nhi khoa',
        'Nguyễn Thị Mai',
        200000,
        date,
        '09:00-10:00',
      ),
    ];
  }
  late List<CartItem> items;
  CartItem _item(
    int id,
    String doctor,
    String department,
    String patient,
    int fee,
    String date,
    String slot,
  ) => CartItem.fromJson({
    'id': id,
    'doctorId': id,
    'doctorFullName': doctor,
    'doctorAvatarUrl': null,
    'doctorIsActive': true,
    'departmentName': department,
    'consultationFee': fee,
    'patientProfileFullName': patient,
    'appointmentDate': date,
    'timeSlot': slot,
    'note': null,
  });
  @override
  Future<List<CartItem>> list() async => List.of(items);
  @override
  Future<List<Schedule>> schedules(int doctorId) async => [
    for (var day = 0; day < 7; day++) ...[
      Schedule.fromJson({
        'dayOfWeek': day,
        'startTime': '08:00:00',
        'endTime': '09:00:00',
      }),
      Schedule.fromJson({
        'dayOfWeek': day,
        'startTime': '09:00:00',
        'endTime': '10:00:00',
      }),
    ],
  ];
  @override
  Future<void> delete(int id) async {
    items.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> clear() async {
    items.clear();
  }

  @override
  Future<void> update(CartItem item, DateTime date, String slot) async {
    final index = items.indexWhere((entry) => entry.id == item.id);
    if (index < 0) throw CartException('Không tìm thấy lịch hẹn.');
    final dateString =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    items[index] = _item(
      item.id,
      item.doctor,
      item.department,
      item.patient,
      item.fee.toInt(),
      dateString,
      slot,
    );
  }
}

/// Các hằng số và hàm hỗ trợ cho trạng thái đơn đặt lịch
abstract final class OrderStatus {
  static const String pending = 'Pending';
  static const String confirmed = 'Confirmed';
  static const String completed = 'Completed';
  static const String cancelled = 'Cancelled';

  static const List<String> all = [
    pending,
    confirmed,
    completed,
    cancelled,
  ];

  /// Chuẩn hóa chuỗi/số trạng thái về dạng PascalCase khớp backend
  static String normalize(dynamic raw) {
    if (raw == null) return pending;
    if (raw is num) {
      switch (raw.toInt()) {
        case 0:
          return pending;
        case 1:
          return confirmed;
        case 2:
          return completed;
        case 3:
          return cancelled;
      }
    }
    final value = raw.toString().trim();
    if (value.isEmpty) return pending;
    switch (value.toLowerCase()) {
      case 'pending':
        return pending;
      case 'confirmed':
        return confirmed;
      case 'completed':
        return completed;
      case 'cancelled':
        return cancelled;
      default:
        return value;
    }
  }

  /// Trả về các trạng thái hợp lệ tiếp theo theo rule backend (AdminOrderService)
  static List<String> allowedNextStatuses(String currentStatus) {
    switch (normalize(currentStatus)) {
      case pending:
        return const [confirmed, cancelled];
      case confirmed:
        return const [completed, cancelled];
      default:
        return const [];
    }
  }

  /// Nhãn tiếng Việt tương ứng với từng trạng thái đơn hàng
  static String label(String status) {
    switch (normalize(status)) {
      case pending:
        return 'Chờ xác nhận';
      case confirmed:
        return 'Đã xác nhận';
      case completed:
        return 'Hoàn thành';
      case cancelled:
        return 'Đã hủy';
      default:
        final trimmed = status.trim();
        return trimmed.isEmpty ? 'Không xác định' : trimmed;
    }
  }
}

/// Model chi tiết từng lịch hẹn trong đơn đặt lịch (khớp AdminOrderItemResponse)
class OrderDetail {
  final int id;
  final int orderId;
  final int doctorId;
  final String doctorFullName;
  final String departmentName;
  final String? roomNumber;
  final int patientProfileId;
  final String patientProfileFullName;
  final DateTime? appointmentDate;
  final String timeSlot;
  final int queueNumber;
  final double fee;
  final String? note;
  final String status;
  final DateTime? createdAt;

  const OrderDetail({
    required this.id,
    required this.orderId,
    required this.doctorId,
    required this.doctorFullName,
    required this.departmentName,
    this.roomNumber,
    required this.patientProfileId,
    required this.patientProfileFullName,
    this.appointmentDate,
    required this.timeSlot,
    required this.queueNumber,
    required this.fee,
    this.note,
    required this.status,
    this.createdAt,
  });

  String get feeFormatted => Order.formatMoney(fee);

  String get appointmentDateFormatted =>
      Order.formatDate(appointmentDate) ?? 'Chưa cập nhật';

  String get roomDisplay {
    final trimmed = roomNumber?.trim() ?? '';
    return trimmed.isEmpty ? 'Chưa gán phòng' : 'Phòng $trimmed';
  }

  String get statusLabel => OrderStatus.label(status);

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    final doctorMap = json['doctor'] is Map
        ? Map<String, dynamic>.from(json['doctor'] as Map)
        : null;
    final departmentMap = doctorMap != null && doctorMap['department'] is Map
        ? Map<String, dynamic>.from(doctorMap['department'] as Map)
        : null;
    final roomMap = doctorMap != null && doctorMap['room'] is Map
        ? Map<String, dynamic>.from(doctorMap['room'] as Map)
        : null;
    final profileMap = json['patientProfile'] is Map
        ? Map<String, dynamic>.from(json['patientProfile'] as Map)
        : null;

    return OrderDetail(
      id: Order.parseInt(json['id']),
      orderId: Order.parseInt(json['orderId']),
      doctorId: Order.parseInt(json['doctorId']),
      doctorFullName: Order.parseString(
        json['doctorFullName'] ?? doctorMap?['fullName'],
      ),
      departmentName: Order.parseString(
        json['departmentName'] ?? departmentMap?['name'],
      ),
      roomNumber: Order.parseNullableString(
        json['roomNumber'] ?? roomMap?['roomNumber'],
      ),
      patientProfileId: Order.parseInt(json['patientProfileId']),
      patientProfileFullName: Order.parseString(
        json['patientProfileFullName'] ?? profileMap?['fullName'],
      ),
      appointmentDate: Order.parseDateTime(json['appointmentDate']),
      timeSlot: Order.parseString(json['timeSlot']),
      queueNumber: Order.parseInt(json['queueNumber']),
      fee: Order.parseDouble(json['fee']),
      note: Order.parseNullableString(json['note']),
      status: OrderStatus.normalize(json['status']),
      createdAt: Order.parseDateTime(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderId': orderId,
        'doctorId': doctorId,
        'doctorFullName': doctorFullName,
        'departmentName': departmentName,
        'roomNumber': roomNumber,
        'patientProfileId': patientProfileId,
        'patientProfileFullName': patientProfileFullName,
        'appointmentDate': Order.formatIsoDate(appointmentDate),
        'timeSlot': timeSlot,
        'queueNumber': queueNumber,
        'fee': fee,
        'note': note,
        'status': status,
        'createdAt': createdAt?.toIso8601String(),
      };
}

/// Model đơn đặt lịch dùng chung cho Admin và luồng Checkout/Lịch sử đặt lịch
/// (khớp AdminOrderResponse & AdminOrderDetailResponse từ backend)
class Order {
  final int id;
  final int userId;
  final String userFullName;
  final double totalAmount;
  final String status;
  final String? cancellationReason;
  final String paymentMethod;
  final String paymentStatus;
  final String? transactionId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<OrderDetail> orderDetails;

  const Order({
    required this.id,
    required this.userId,
    required this.userFullName,
    required this.totalAmount,
    required this.status,
    this.cancellationReason,
    required this.paymentMethod,
    required this.paymentStatus,
    this.transactionId,
    this.createdAt,
    this.updatedAt,
    this.orderDetails = const [],
  });

  String get totalAmountFormatted => formatMoney(totalAmount);

  String get statusLabel => OrderStatus.label(status);

  List<String> get allowedNextStatuses =>
      OrderStatus.allowedNextStatuses(status);

  String get createdAtFormatted =>
      formatDateTime(createdAt) ?? 'Chưa cập nhật';

  String get updatedAtFormatted =>
      formatDateTime(updatedAt) ?? 'Chưa cập nhật';

  String get customerDisplay {
    final trimmed = userFullName.trim();
    return trimmed.isEmpty ? 'Người dùng #$userId' : trimmed;
  }

  String get paymentMethodLabel {
    switch (paymentMethod.trim().toLowerCase()) {
      case 'cash':
        return 'Tiền mặt';
      case 'vnpay':
        return 'VNPay';
      case 'vietqr':
        return 'VietQR';
      default:
        final trimmed = paymentMethod.trim();
        return trimmed.isEmpty ? 'Chưa xác định' : trimmed;
    }
  }

  String get paymentStatusLabel {
    switch (paymentStatus.trim().toLowerCase()) {
      case 'paid':
        return 'Đã thanh toán';
      case 'unpaid':
        return 'Chưa thanh toán';
      default:
        final trimmed = paymentStatus.trim();
        return trimmed.isEmpty ? 'Chưa xác định' : trimmed;
    }
  }

  bool get isPaid => paymentStatus.trim().toLowerCase() == 'paid';

  Order copyWith({
    int? id,
    int? userId,
    String? userFullName,
    double? totalAmount,
    String? status,
    String? cancellationReason,
    String? paymentMethod,
    String? paymentStatus,
    String? transactionId,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<OrderDetail>? orderDetails,
  }) {
    return Order(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userFullName: userFullName ?? this.userFullName,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      transactionId: transactionId ?? this.transactionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      orderDetails: orderDetails ?? this.orderDetails,
    );
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    final userMap = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : null;
    final rawDetails = json['orderDetails'] as List<dynamic>?;
    final details = rawDetails
            ?.whereType<Map>()
            .map((e) => OrderDetail.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const <OrderDetail>[];

    return Order(
      id: parseInt(json['id']),
      userId: parseInt(json['userId']),
      userFullName: parseString(
        json['userFullName'] ?? userMap?['fullName'],
      ),
      totalAmount: parseDouble(json['totalAmount']),
      status: OrderStatus.normalize(json['status']),
      cancellationReason: parseNullableString(json['cancellationReason']),
      paymentMethod: parseString(json['paymentMethod'], 'Cash'),
      paymentStatus: parseString(json['paymentStatus'], 'Unpaid'),
      transactionId: parseNullableString(json['transactionId']),
      createdAt: parseDateTime(json['createdAt']),
      updatedAt: parseDateTime(json['updatedAt']),
      orderDetails: details,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'userFullName': userFullName,
        'totalAmount': totalAmount,
        'status': status,
        'cancellationReason': cancellationReason,
        'paymentMethod': paymentMethod,
        'paymentStatus': paymentStatus,
        'transactionId': transactionId,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'orderDetails': orderDetails.map((e) => e.toJson()).toList(),
      };

  static int parseInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim()) ?? fallback;
  }

  static double parseDouble(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim()) ?? fallback;
  }

  static String parseString(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    return value.toString();
  }

  static String? parseNullableString(dynamic value) {
    if (value == null) return null;
    final str = value.toString();
    return str;
  }

  static DateTime? parseDateTime(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  /// Chuyển UTC sang giờ Việt Nam (UTC+7); giữ nguyên nếu là thời gian không kèm offset
  static DateTime toVietnamTime(DateTime dateTime) {
    if (dateTime.isUtc) {
      return dateTime.add(const Duration(hours: 7));
    }
    return dateTime;
  }

  static String? formatDate(DateTime? date) {
    if (date == null) return null;
    final d = toVietnamTime(date);
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }

  static String? formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return null;
    final d = toVietnamTime(dateTime);
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$day/$month/${d.year} $hour:$minute';
  }

  static String? formatIsoDate(DateTime? date) {
    if (date == null) return null;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  /// Định dạng tiền tệ VNĐ (ví dụ: 200.000 đ)
  static String formatMoney(double amount) {
    final rounded = amount.round();
    final negative = rounded < 0;
    final digits = rounded.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }
    return '${negative ? '-' : ''}${buffer.toString()} đ';
  }
}

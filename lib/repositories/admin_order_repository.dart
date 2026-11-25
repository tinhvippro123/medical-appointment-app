import 'package:medical_appointment_app/core/network/api_client.dart';
import 'package:medical_appointment_app/core/network/api_exception.dart';
import 'package:medical_appointment_app/models/order.dart';
import 'package:medical_appointment_app/models/paged_result.dart';

/// Repository quản lý đơn đặt lịch dành cho Quản trị viên (ADMIN)
class AdminOrderRepository {
  AdminOrderRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  ApiClient get apiClient => _apiClient;

  /// Lấy danh sách tất cả đơn đặt lịch có phân trang và lọc theo trạng thái
  /// (GET /api/admin/orders?page=...&pageSize=...&status=...)
  Future<PagedResult<Order>> getOrders({
    int page = 1,
    int pageSize = 10,
    String? status,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
    };
    if (status != null && status.trim().isNotEmpty) {
      queryParams['status'] = status.trim();
    }

    final res = await _apiClient.get(
      '/api/admin/orders',
      queryParameters: queryParams,
    );

    if (res is Map) {
      return PagedResult<Order>.fromJson(
        Map<String, dynamic>.from(res),
        (item) => Order.fromJson(
          item is Map
              ? Map<String, dynamic>.from(item)
              : const <String, dynamic>{},
        ),
      );
    }

    throw const ApiException(
      statusCode: 500,
      message: 'Dữ liệu danh sách đơn đặt lịch không hợp lệ.',
    );
  }

  /// Lấy chi tiết một đơn đặt lịch kèm OrderDetails (GET /api/admin/orders/{id})
  Future<Order> getOrderById(int id) async {
    final res = await _apiClient.get('/api/admin/orders/$id');
    if (res is Map) {
      return Order.fromJson(Map<String, dynamic>.from(res));
    }

    throw const ApiException(
      statusCode: 500,
      message: 'Dữ liệu chi tiết đơn đặt lịch không hợp lệ.',
    );
  }

  /// Cập nhật trạng thái đơn đặt lịch (PUT /api/admin/orders/{id}/status)
  Future<Order> updateOrderStatus(
    int id, {
    required String status,
    String? cancellationReason,
  }) async {
    final trimmedReason = cancellationReason?.trim();
    final body = <String, dynamic>{
      'status': status.trim(),
      if (trimmedReason != null && trimmedReason.isNotEmpty)
        'cancellationReason': trimmedReason,
    };

    final res = await _apiClient.put(
      '/api/admin/orders/$id/status',
      body: body,
    );

    if (res is Map) {
      return Order.fromJson(Map<String, dynamic>.from(res));
    }

    throw const ApiException(
      statusCode: 500,
      message: 'Dữ liệu phản hồi cập nhật trạng thái không hợp lệ.',
    );
  }
}

import '../core/network/api_client.dart';
import '../models/order.dart';
import '../models/paged_result.dart';

class OrderRepository {
  OrderRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<Order> checkout({
    required int doctorId,
    required int patientProfileId,
    required DateTime date,
    required String slot,
    required String note,
    required String paymentMethod,
  }) async {
    final data = await _api.post(
      '/api/orders/checkout',
      body: {
        'paymentMethod': paymentMethod,
        'appointment': {
          'doctorId': doctorId,
          'patientProfileId': patientProfileId,
          'appointmentDate': date.toIso8601String().split('T').first,
          'timeSlot': slot,
          if (note.isNotEmpty) 'note': note,
        },
      },
    );
    return Order.fromJson(data as Map<String, dynamic>);
  }

  Future<PagedResult<Order>> list({int page = 1}) async {
    final data = await _api.get(
      '/api/orders',
      queryParameters: {'page': page, 'pageSize': 10},
    );
    return PagedResult<Order>.fromJson(
      data as Map<String, dynamic>,
      (item) => Order.fromJson(item as Map<String, dynamic>),
    );
  }

  Future<Order> detail(int id) async {
    final data = await _api.get('/api/orders/$id');
    return Order.fromJson(data as Map<String, dynamic>);
  }
}

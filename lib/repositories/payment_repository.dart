import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/payment_models.dart';

class PaymentRepository {
  PaymentRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<VnPaySession> createVnPay(int orderId) async {
    final res = await _api.post(
      '/api/payments/vnpay',
      body: {'orderId': orderId},
    );
    if (res is Map) {
      return VnPaySession.fromJson(Map<String, dynamic>.from(res));
    }
    throw const ApiException(
      statusCode: 500,
      message: 'Dữ liệu khởi tạo thanh toán VNPay không hợp lệ.',
    );
  }

  Future<VietQrSession> createVietQr(int orderId) async {
    final res = await _api.post(
      '/api/payments/vietqr',
      body: {'orderId': orderId},
    );
    if (res is Map) {
      return VietQrSession.fromJson(Map<String, dynamic>.from(res));
    }
    throw const ApiException(
      statusCode: 500,
      message: 'Dữ liệu khởi tạo mã VietQR không hợp lệ.',
    );
  }

  Future<PaymentResult> verifyVnPayCallbackUrl(String callbackUrl) async {
    final uri = Uri.parse(callbackUrl);
    final res = await _api.get(
      uri.path,
      queryParameters: uri.queryParameters,
    );
    if (res is Map) {
      return PaymentResult.fromJson(Map<String, dynamic>.from(res));
    }
    throw const ApiException(
      statusCode: 500,
      message: 'Phản hồi xác nhận giao dịch VNPay không hợp lệ.',
    );
  }

  Future<PaymentResult> confirmPayment({
    required int orderId,
    required String provider,
    bool simulateFailure = false,
  }) async {
    final res = await _api.post(
      '/api/payments/confirm',
      body: {
        'orderId': orderId,
        'provider': provider,
        'simulateFailure': simulateFailure,
      },
    );
    if (res is Map) {
      return PaymentResult.fromJson(Map<String, dynamic>.from(res));
    }
    throw const ApiException(
      statusCode: 500,
      message: 'Phản hồi xác nhận thanh toán không hợp lệ.',
    );
  }
}

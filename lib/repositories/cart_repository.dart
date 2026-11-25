import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../helpers/session_helper.dart';

class CartItem {
  CartItem.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      doctorId = j['doctorId'],
      doctor = j['doctorFullName'],
      avatar = j['doctorAvatarUrl'],
      active = j['doctorIsActive'],
      department = j['departmentName'],
      fee = (j['consultationFee'] as num).toDouble(),
      patient = j['patientProfileFullName'],
      date = DateTime.parse(j['appointmentDate']),
      slot = j['timeSlot'],
      note = j['note'];
  final int id, doctorId;
  final String doctor, department, patient, slot;
  final String? avatar, note;
  final bool active;
  final double fee;
  final DateTime date;
}

class Schedule {
  Schedule.fromJson(Map<String, dynamic> j)
    : day = j['dayOfWeek'],
      start = j['startTime'],
      end = j['endTime'];
  final int day;
  final String start, end;
  String get slot => '${start.substring(0, 5)}-${end.substring(0, 5)}';
}

class CartException implements Exception {
  CartException(this.message);
  final String message;
  @override
  String toString() => message;
}

class CartRepository {
  CartRepository({
    http.Client? client,
    String? baseUrl,
    Future<String?> Function()? token,
  }) : client = client ?? http.Client(),
       baseUrl = baseUrl ?? AppConfig.baseUrl,
       token = token ?? SessionHepler.getToken;
  final http.Client client;
  final String baseUrl;
  final Future<String?> Function() token;
  String? imageUrl(String? path) => path == null || path.isEmpty
      ? null
      : Uri.parse('$baseUrl/').resolve(path).toString();
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final jwt = await token();
    if (jwt == null || jwt.isEmpty) {
      throw CartException('Vui lòng đăng nhập để xem giỏ hàng.');
    }
    final req = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers['Authorization'] = 'Bearer $jwt';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    try {
      final res = await (() async => http.Response.fromStream(
        await client.send(req),
      ))().timeout(const Duration(seconds: 20));
      dynamic data;
      try {
        if (res.bodyBytes.isNotEmpty) {
          data = jsonDecode(utf8.decode(res.bodyBytes));
        }
      } catch (_) {}
      if (res.statusCode == 401 || res.statusCode == 403) {
        throw CartException('Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.');
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        String message = 'Không thực hiện được yêu cầu. Vui lòng thử lại.';
        if (data is Map) {
          if (data['message'] is String) {
            message = data['message'];
          } else if (data['errors'] is Map) {
            final errors = (data['errors'] as Map).values.expand(
              (e) => e is List ? e : [e],
            );
            message = errors.join('\n');
          }
        }
        throw CartException(message);
      }
      return data;
    } on CartException {
      rethrow;
    } on TimeoutException {
      throw CartException('Kết nối quá thời gian. Vui lòng thử lại.');
    } catch (_) {
      throw CartException('Không kết nối được máy chủ. Vui lòng thử lại.');
    }
  }

  Future<List<CartItem>> list() async =>
      ((await request('GET', '/api/cart')) as List)
          .map((e) => CartItem.fromJson(e))
          .toList();

  Future<void> add({
    required int doctorId,
    required int patientProfileId,
    required DateTime date,
    required String slot,
  }) async {
    await request(
      'POST',
      '/api/cart',
      body: {
        'doctorId': doctorId,
        'patientProfileId': patientProfileId,
        'appointmentDate': date.toIso8601String().split('T').first,
        'timeSlot': slot,
      },
    );
  }

  Future<List<Schedule>> schedules(int doctorId) async =>
      ((await request('GET', '/api/doctors/$doctorId/schedules')) as List)
          .map((e) => Schedule.fromJson(e))
          .toList();
  Future<void> update(CartItem item, DateTime date, String slot) async {
    await request(
      'PUT',
      '/api/cart/${item.id}',
      body: {
        'appointmentDate':
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'timeSlot': slot,
        'note': item.note,
      },
    );
  }

  Future<void> delete(int id) async {
    await request('DELETE', '/api/cart/$id');
  }

  Future<void> clear() async {
    await request('DELETE', '/api/cart/clear');
  }
}

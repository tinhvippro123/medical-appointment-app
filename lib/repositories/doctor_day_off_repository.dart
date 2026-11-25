import 'package:medical_appointment_app/core/network/api_client.dart';
import 'package:medical_appointment_app/models/doctor_day_off.dart';

/// Repository quản lý ngày nghỉ của bác sĩ (/api/doctors/{doctorId}/day-offs)
class DoctorDayOffRepository {
  DoctorDayOffRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  ApiClient get apiClient => _apiClient;

  /// Lấy danh sách ngày nghỉ của bác sĩ (GET /api/doctors/{doctorId}/day-offs)
  Future<List<DoctorDayOff>> getDayOffs(
    int doctorId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final queryParams = <String, dynamic>{};
    if (from != null) {
      queryParams['from'] = DoctorDayOff.formatApiDate(from);
    }
    if (to != null) {
      queryParams['to'] = DoctorDayOff.formatApiDate(to);
    }

    final res = await _apiClient.get(
      '/api/doctors/$doctorId/day-offs',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    if (res is List) {
      return res
          .whereType<Map>()
          .map((e) => DoctorDayOff.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  /// Thêm ngày nghỉ mới cho bác sĩ (POST /api/doctors/{doctorId}/day-offs)
  Future<DoctorDayOff> createDayOff(
    int doctorId,
    DoctorDayOffFormInput input,
  ) async {
    final res = await _apiClient.post(
      '/api/doctors/$doctorId/day-offs',
      body: input.toJson(),
    );
    return DoctorDayOff.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// Xóa ngày nghỉ của bác sĩ (DELETE /api/doctors/{doctorId}/day-offs/{dayOffId})
  Future<void> deleteDayOff(int doctorId, int dayOffId) async {
    await _apiClient.delete('/api/doctors/$doctorId/day-offs/$dayOffId');
  }
}

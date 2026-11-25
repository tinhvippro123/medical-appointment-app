import 'package:medical_appointment_app/core/network/api_client.dart';
import 'package:medical_appointment_app/models/doctor.dart';

/// Repository quản lý CRUD lịch làm việc của bác sĩ
class DoctorScheduleRepository {
  DoctorScheduleRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  ApiClient get apiClient => _apiClient;

  /// Lấy danh sách lịch làm việc của bác sĩ (GET /api/doctors/{doctorId}/schedules)
  Future<List<DoctorSchedule>> getSchedules(int doctorId) async {
    final res = await _apiClient.get('/api/doctors/$doctorId/schedules');
    if (res is List) {
      return res
          .whereType<Map>()
          .map((e) => DoctorSchedule.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  /// Tạo mới khung lịch làm việc (POST /api/doctors/{doctorId}/schedules)
  Future<DoctorSchedule> createSchedule(
    int doctorId,
    DoctorScheduleFormInput input,
  ) async {
    final res = await _apiClient.post(
      '/api/doctors/$doctorId/schedules',
      body: input.toJson(),
    );
    return DoctorSchedule.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// Cập nhật khung lịch làm việc (PUT /api/schedules/{scheduleId})
  Future<DoctorSchedule> updateSchedule(
    int scheduleId,
    DoctorScheduleFormInput input,
  ) async {
    final res = await _apiClient.put(
      '/api/schedules/$scheduleId',
      body: input.toJson(),
    );
    return DoctorSchedule.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// Xóa khung lịch làm việc (DELETE /api/schedules/{scheduleId})
  Future<void> deleteSchedule(int scheduleId) async {
    await _apiClient.delete('/api/schedules/$scheduleId');
  }
}

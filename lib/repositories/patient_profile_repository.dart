import '../core/network/api_client.dart';
import '../models/patient_profile.dart';

/// Repository quản lý đọc hồ sơ bệnh nhân của người dùng hiện tại.
/// Card F6 sẽ mở rộng thêm create/update/delete trên lớp này.
class PatientProfileRepository {
  PatientProfileRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  ApiClient get apiClient => _apiClient;

  /// Lấy danh sách hồ sơ bệnh nhân của tài khoản đang đăng nhập (GET /api/patient-profiles)
  Future<List<PatientProfile>> getProfiles() async {
    final res = await _apiClient.get('/api/patient-profiles');
    if (res is List) {
      return res
          .whereType<Map>()
          .map((e) => PatientProfile.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }
}

import '../core/network/api_client.dart';
import '../models/patient_profile.dart';

/// Repository quản lý hồ sơ bệnh nhân của người dùng hiện tại.
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

  Future<List<PatientProfile>> list() => getProfiles();

  Future<PatientProfile> create({
    required String fullName,
    required DateTime dateOfBirth,
    required String gender,
    required String relationship,
  }) async {
    final data = await _apiClient.post(
      '/api/patient-profiles',
      body: {
        'fullName': fullName,
        'dateOfBirth': dateOfBirth.toIso8601String().split('T').first,
        'gender': gender,
        'relationship': relationship,
      },
    );
    return PatientProfile.fromJson(Map<String, dynamic>.from(data as Map));
  }
}

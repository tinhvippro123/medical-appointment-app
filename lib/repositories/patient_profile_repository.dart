import '../core/network/api_client.dart';
import '../models/patient_profile.dart';

/// Repository quản lý hồ sơ bệnh nhân của người dùng hiện tại.
class PatientProfileRepository {
  PatientProfileRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;
  static const _path = '/api/patient-profiles';

  ApiClient get apiClient => _apiClient;

  /// Lấy danh sách hồ sơ bệnh nhân của tài khoản đang đăng nhập (GET /api/patient-profiles)
  Future<List<PatientProfile>> getProfiles() async {
    final res = await _apiClient.get(_path);
    if (res is List) {
      return res
          .whereType<Map>()
          .map((e) => PatientProfile.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  Future<List<PatientProfile>> list() => getProfiles();

  Future<PatientProfile> save(Map<String, dynamic> body, {int? id}) async {
    final data = id == null
        ? await _apiClient.post(_path, body: body)
        : await _apiClient.put('$_path/$id', body: body);
    return PatientProfile.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> delete(int id) async {
    await _apiClient.delete('$_path/$id');
  }
}

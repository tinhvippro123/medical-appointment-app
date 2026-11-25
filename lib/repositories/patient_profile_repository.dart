import '../core/network/api_client.dart';
import '../models/patient_profile.dart';

class PatientProfileRepository {
  PatientProfileRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<PatientProfile>> list() async {
    final data = await _apiClient.get('/api/patient-profiles') as List;
    return data
        .map((item) => PatientProfile.fromJson(item as Map<String, dynamic>))
        .toList();
  }

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
    return PatientProfile.fromJson(data as Map<String, dynamic>);
  }
}

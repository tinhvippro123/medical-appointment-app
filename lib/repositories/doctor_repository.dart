import '../core/network/api_client.dart';
import '../models/doctor.dart';
import '../models/doctor_day_off.dart';
import '../models/paged_result.dart';

class DoctorRepository {
  DoctorRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  ApiClient get apiClient => _apiClient;

  /// Lấy danh sách bác sĩ có phân trang
  Future<PagedResult<Doctor>> getDoctors({int page = 1, int pageSize = 10}) async {
    final res = await _apiClient.get(
      '/api/doctors',
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
      },
    );

    return PagedResult<Doctor>.fromJson(
      res as Map<String, dynamic>,
      (j) => Doctor.fromJson(j as Map<String, dynamic>),
    );
  }

  /// Lấy danh sách bác sĩ đang hoạt động trong chuyên khoa.
  Future<PagedResult<Doctor>> getDepartmentDoctors(
    int departmentId, {
    int page = 1,
    int pageSize = 10,
  }) async {
    final result = await _apiClient.get(
      '/api/departments/$departmentId/doctors',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return PagedResult<Doctor>.fromJson(
      result as Map<String, dynamic>,
      (item) => Doctor.fromJson(item as Map<String, dynamic>),
    );
  }

  /// Lấy chi tiết thông tin bác sĩ theo id
  Future<Doctor> getDoctorById(int id) async {
    final res = await _apiClient.get('/api/doctors/$id');
    return Doctor.fromJson(res as Map<String, dynamic>);
  }

  /// Lấy danh sách ngày nghỉ của bác sĩ trong khoảng [from, to] (GET /api/doctors/{doctorId}/day-offs)
  Future<List<DoctorDayOff>> getDoctorDayOffs(
    int doctorId, {
    DateTime? from,
    DateTime? to,
  }) async {
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final queryParams = <String, dynamic>{};
    if (from != null) queryParams['from'] = fmt(from);
    if (to != null) queryParams['to'] = fmt(to);

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
    return [];
  }

  /// Lấy danh sách bác sĩ cùng chuyên khoa (GET /api/doctors/{id}/related)
  Future<PagedResult<Doctor>> getRelatedDoctors(
    int id, {
    int page = 1,
    int pageSize = 5,
  }) async {
    final res = await _apiClient.get(
      '/api/doctors/$id/related',
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
      },
    );

    return PagedResult<Doctor>.fromJson(
      res as Map<String, dynamic>,
      (j) => Doctor.fromJson(j as Map<String, dynamic>),
    );
  }

  /// Tìm kiếm bác sĩ theo từ khóa và chuyên khoa có phân trang (GET /api/doctors/search)
  Future<PagedResult<Doctor>> searchDoctors({
    String? keyword,
    int? departmentId,
    int page = 1,
    int pageSize = 10,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
    };
    if (keyword != null && keyword.trim().isNotEmpty) {
      queryParams['keyword'] = keyword.trim();
    }
    if (departmentId != null) {
      queryParams['departmentId'] = departmentId;
    }

    final res = await _apiClient.get(
      '/api/doctors/search',
      queryParameters: queryParams,
    );

    return PagedResult<Doctor>.fromJson(
      res as Map<String, dynamic>,
      (j) => Doctor.fromJson(j as Map<String, dynamic>),
    );
  }

  /// Thêm bác sĩ mới (POST /api/doctors) dùng multipart/form-data
  Future<Doctor> createDoctor(
    DoctorFormInput input, {
    List<int>? imageBytes,
    String? imageFilename,
    String? avatarUrl,
  }) async {
    final files = <MultipartFileItem>[];
    if (imageBytes != null && imageBytes.isNotEmpty && imageFilename != null) {
      files.add(
        MultipartFileItem(
          field: 'Image',
          bytes: imageBytes,
          filename: imageFilename,
        ),
      );
    }

    final res = await _apiClient.sendMultipart(
      method: 'POST',
      path: '/api/doctors',
      fields: {...input.toFields(), 'AvatarUrl': ?avatarUrl},
      files: files.isNotEmpty ? files : null,
    );

    return Doctor.fromJson(res as Map<String, dynamic>);
  }

  /// Cập nhật thông tin bác sĩ (PUT /api/doctors/:id) dùng multipart/form-data
  Future<Doctor> updateDoctor(
    int id,
    DoctorFormInput input, {
    List<int>? imageBytes,
    String? imageFilename,
    String? avatarUrl,
  }) async {
    final files = <MultipartFileItem>[];
    if (imageBytes != null && imageBytes.isNotEmpty && imageFilename != null) {
      files.add(
        MultipartFileItem(
          field: 'Image',
          bytes: imageBytes,
          filename: imageFilename,
        ),
      );
    }

    final res = await _apiClient.sendMultipart(
      method: 'PUT',
      path: '/api/doctors/$id',
      fields: {...input.toFields(), 'AvatarUrl': ?avatarUrl},
      files: files.isNotEmpty ? files : null,
    );

    return Doctor.fromJson(res as Map<String, dynamic>);
  }

  /// Xóa mềm bác sĩ (DELETE /api/doctors/:id)
  Future<void> deleteDoctor(int id) async {
    await _apiClient.delete('/api/doctors/$id');
  }

  /// Chuẩn hóa URL ảnh đại diện
  String? imageUrl(String? path) => _apiClient.imageUrl(path);
}

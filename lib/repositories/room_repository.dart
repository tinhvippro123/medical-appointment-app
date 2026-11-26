import '../core/network/api_client.dart';
import '../models/room.dart';

class RoomRepository {
  RoomRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Lấy danh sách phòng, có thể lọc theo chuyên khoa (departmentId)
  Future<List<Room>> getRooms({int? departmentId}) async {
    final query = departmentId != null ? {'departmentId': departmentId} : null;
    final res = await _apiClient.get('/api/rooms', queryParameters: query);
    if (res is List) {
      return res.map((e) => Room.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Lấy chi tiết một phòng theo id
  Future<Room> getRoomById(int id) async {
    final res = await _apiClient.get('/api/rooms/$id');
    return Room.fromJson(res as Map<String, dynamic>);
  }
}

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medical_appointment_app/core/network/api_client.dart';
import 'package:medical_appointment_app/models/room.dart';
import 'package:medical_appointment_app/repositories/room_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Room Model & Repository Tests', () {
    test('Room.fromJson parse đầy đủ các trường và displayLabel đúng', () {
      final json = {
        'id': 10,
        'roomNumber': '201',
        'floor': 2,
        'departmentId': 3,
        'isActive': true,
      };

      final room = Room.fromJson(json);

      expect(room.id, 10);
      expect(room.roomNumber, '201');
      expect(room.floor, 2);
      expect(room.departmentId, 3);
      expect(room.isActive, isTrue);
      expect(room.displayLabel, 'Phòng 201 (Tầng 2)');
    });

    test('RoomRepository.getRooms gọi GET /api/rooms và parse danh sách', () async {
      final mockRooms = [
        {
          'id': 1,
          'roomNumber': '101',
          'floor': 1,
          'departmentId': 2,
          'isActive': true,
        },
        {
          'id': 2,
          'roomNumber': '102',
          'floor': 1,
          'departmentId': 2,
          'isActive': false,
        },
      ];

      String? requestedPath;
      final mockClient = MockClient((request) async {
        requestedPath = request.url.path;
        expect(request.url.queryParameters['departmentId'], '2');
        return http.Response.bytes(
          utf8.encode(jsonEncode(mockRooms)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final apiClient = ApiClient(
        client: mockClient,
        baseUrl: 'http://test.api',
        tokenProvider: () async => 'token',
      );
      final repo = RoomRepository(apiClient: apiClient);

      final rooms = await repo.getRooms(departmentId: 2);

      expect(requestedPath, '/api/rooms');
      expect(rooms.length, 2);
      expect(rooms[0].roomNumber, '101');
      expect(rooms[0].isActive, isTrue);
      expect(rooms[1].roomNumber, '102');
      expect(rooms[1].isActive, isFalse);
    });
  });
}

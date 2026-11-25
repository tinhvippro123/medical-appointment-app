import 'package:sqflite/sqflite.dart';

bool get isFlutterTestEnvironment => false;

Future<Database?> openAppDatabase({
  required String dbName,
  required int version,
  required OnDatabaseCreateFn onCreate,
  bool inMemory = false,
}) async => null;

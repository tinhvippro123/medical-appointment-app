import 'dart:io' show Platform;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool _ffiInitialized = false;

bool get isFlutterTestEnvironment =>
    Platform.environment.containsKey('FLUTTER_TEST');

Future<Database?> openAppDatabase({
  required String dbName,
  required int version,
  required OnDatabaseCreateFn onCreate,
  bool inMemory = false,
}) async {
  final useFfi =
      inMemory || Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  if (useFfi) {
    if (!_ffiInitialized) {
      sqfliteFfiInit();
      _ffiInitialized = true;
    }
    final dbPath = inMemory
        ? inMemoryDatabasePath
        : p.join(await databaseFactoryFfi.getDatabasesPath(), dbName);
    return databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(version: version, onCreate: onCreate),
    );
  }

  final dbPath = p.join(await getDatabasesPath(), dbName);
  return openDatabase(dbPath, version: version, onCreate: onCreate);
}

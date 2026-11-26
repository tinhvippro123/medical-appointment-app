import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:sqflite/sqflite.dart';
import '../models/user_role_models.dart';
import 'session_helper.dart';
import 'sqlite_platform_stub.dart'
    if (dart.library.io) 'sqlite_platform_io.dart'
    as platform;

class LocalDatabaseHelper {
  static const String _dbName = 'medical_app.db';
  static const int _dbVersion = 1;

  static Database? _db;
  static bool _allowInTest = false;
  static bool _inMemory = false;

  static Future<Database?> get database async {
    if (kIsWeb) {
      return null;
    }
    if (platform.isFlutterTestEnvironment && !_allowInTest) {
      return null;
    }
    if (_db != null && _db!.isOpen) {
      return _db;
    }
    _db = await platform.openAppDatabase(
      dbName: _dbName,
      version: _dbVersion,
      onCreate: _onCreate,
      inMemory: _inMemory,
    );
    return _db;
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE user_session (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        user_id INTEGER NOT NULL,
        full_name TEXT NOT NULL,
        phone TEXT NOT NULL,
        role_key TEXT NOT NULL,
        token TEXT NOT NULL,
        saved_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE cached_roles (
        id INTEGER PRIMARY KEY,
        role_key TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        user_count INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE cached_users (
        id INTEGER PRIMARY KEY,
        full_name TEXT NOT NULL,
        phone TEXT NOT NULL,
        email TEXT,
        role_id INTEGER NOT NULL,
        role_key TEXT NOT NULL,
        role_name TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT
      )
    ''');
  }

  static Future<void> saveSession(SessionUser user, String token) async {
    final db = await database;
    if (db == null) {
      return;
    }
    await db.insert('user_session', {
      'id': 1,
      'user_id': user.userId,
      'full_name': user.fullName,
      'phone': user.phone,
      'role_key': user.roleKey,
      'token': token,
      'saved_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<StoredSession?> getSession() async {
    final db = await database;
    if (db == null) {
      return null;
    }
    final rows = await db.query('user_session', where: 'id = 1', limit: 1);
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    final token = (row['token'] ?? '') as String;
    if (token.isEmpty) {
      return null;
    }
    final decoded = SessionHepler.decodeToken(token);
    return StoredSession(
      user: SessionUser(
        userId: (row['user_id'] as num).toInt(),
        fullName: (row['full_name'] ?? '') as String,
        phone: (row['phone'] ?? '') as String,
        roleKey: (row['role_key'] ?? '') as String,
        expiresAt: decoded?.expiresAt,
      ),
      token: token,
    );
  }

  static Future<void> clearSession() async {
    final db = await database;
    if (db == null) {
      return;
    }
    await db.delete('user_session');
  }

  static Future<void> cacheRoles(List<RoleItem> roles) async {
    final db = await database;
    if (db == null) {
      return;
    }
    await db.transaction((txn) async {
      await txn.delete('cached_roles');
      for (final role in roles) {
        await txn.insert(
          'cached_roles',
          role.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  static Future<List<RoleItem>> getCachedRoles() async {
    final db = await database;
    if (db == null) {
      return [];
    }
    final rows = await db.query('cached_roles', orderBy: 'id ASC');
    return rows.map(RoleItem.fromDbMap).toList();
  }

  static Future<void> cacheUsers(List<UserItem> users) async {
    final db = await database;
    if (db == null) {
      return;
    }
    await db.transaction((txn) async {
      await txn.delete('cached_users');
      for (final user in users) {
        await txn.insert(
          'cached_users',
          user.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  static Future<List<UserItem>> getCachedUsers() async {
    final db = await database;
    if (db == null) {
      return [];
    }
    final rows = await db.query('cached_users', orderBy: 'id DESC');
    return rows.map(UserItem.fromDbMap).toList();
  }

  static Future<void> clearAllCaches() async {
    final db = await database;
    if (db == null) {
      return;
    }
    await db.delete('cached_roles');
    await db.delete('cached_users');
  }

  @visibleForTesting
  static Future<void> useInMemoryForTest() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    _allowInTest = true;
    _inMemory = true;
    await database;
  }

  @visibleForTesting
  static Future<void> resetForTest() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    _allowInTest = false;
    _inMemory = false;
  }
}

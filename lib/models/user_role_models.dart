class SessionUser {
  const SessionUser({
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.roleKey,
    this.expiresAt,
  });

  final int userId;
  final String fullName;
  final String phone;
  final String roleKey;
  final DateTime? expiresAt;

  bool get isAdmin => roleKey.toUpperCase() == 'ADMIN';

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  String get roleDisplayName {
    final normalized = roleKey.toUpperCase();
    if (normalized == 'ADMIN') {
      return 'Quản trị viên';
    }
    if (normalized == 'PATIENT') {
      return 'Bệnh nhân';
    }
    return roleKey;
  }
}

class StoredSession {
  const StoredSession({required this.user, required this.token});

  final SessionUser user;
  final String token;
}

class RoleItem {
  const RoleItem({
    required this.id,
    required this.key,
    required this.name,
    this.description,
    this.userCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String key;
  final String name;
  final String? description;
  final int userCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isSystemRole {
    final normalized = key.toUpperCase();
    return normalized == 'ADMIN' || normalized == 'PATIENT';
  }

  factory RoleItem.fromJson(Map<String, dynamic> json) {
    return RoleItem(
      id: (json['id'] as num).toInt(),
      key: (json['key'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      description: json['description'] as String?,
      userCount: (json['userCount'] as num?)?.toInt() ?? 0,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  Map<String, Object?> toDbMap() => {
    'id': id,
    'role_key': key,
    'name': name,
    'description': description,
    'user_count': userCount,
    'updated_at': updatedAt?.toIso8601String(),
  };

  factory RoleItem.fromDbMap(Map<String, Object?> map) {
    return RoleItem(
      id: (map['id'] as num).toInt(),
      key: (map['role_key'] ?? '') as String,
      name: (map['name'] ?? '') as String,
      description: map['description'] as String?,
      userCount: (map['user_count'] as num?)?.toInt() ?? 0,
      updatedAt: _parseDate(map['updated_at']),
    );
  }
}

class RoleListResult {
  const RoleListResult({required this.items, this.isFromCache = false});

  final List<RoleItem> items;
  final bool isFromCache;
}

class UserItem {
  const UserItem({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
    required this.roleId,
    required this.roleKey,
    required this.roleName,
    required this.isActive,
    this.createdAt,
  });

  final int id;
  final String fullName;
  final String phone;
  final String? email;
  final int roleId;
  final String roleKey;
  final String roleName;
  final bool isActive;
  final DateTime? createdAt;

  factory UserItem.fromJson(Map<String, dynamic> json) {
    return UserItem(
      id: (json['id'] as num).toInt(),
      fullName: (json['fullName'] ?? '') as String,
      phone: (json['phone'] ?? '') as String,
      email: json['email'] as String?,
      roleId: (json['roleId'] as num?)?.toInt() ?? 0,
      roleKey: (json['roleKey'] ?? '') as String,
      roleName: (json['roleName'] ?? '') as String,
      isActive: (json['isActive'] as bool?) ?? true,
      createdAt: _parseDate(json['createdAt']),
    );
  }

  Map<String, Object?> toDbMap() => {
    'id': id,
    'full_name': fullName,
    'phone': phone,
    'email': email,
    'role_id': roleId,
    'role_key': roleKey,
    'role_name': roleName,
    'is_active': isActive ? 1 : 0,
    'created_at': createdAt?.toIso8601String(),
  };

  factory UserItem.fromDbMap(Map<String, Object?> map) {
    return UserItem(
      id: (map['id'] as num).toInt(),
      fullName: (map['full_name'] ?? '') as String,
      phone: (map['phone'] ?? '') as String,
      email: map['email'] as String?,
      roleId: (map['role_id'] as num?)?.toInt() ?? 0,
      roleKey: (map['role_key'] ?? '') as String,
      roleName: (map['role_name'] ?? '') as String,
      isActive: ((map['is_active'] as num?)?.toInt() ?? 1) == 1,
      createdAt: _parseDate(map['created_at']),
    );
  }

  UserItem copyWith({
    bool? isActive,
    int? roleId,
    String? roleKey,
    String? roleName,
  }) {
    return UserItem(
      id: id,
      fullName: fullName,
      phone: phone,
      email: email,
      roleId: roleId ?? this.roleId,
      roleKey: roleKey ?? this.roleKey,
      roleName: roleName ?? this.roleName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }
}

class PagedUsers {
  const PagedUsers({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.hasPreviousPage,
    required this.hasNextPage,
    this.isFromCache = false,
  });

  final List<UserItem> items;
  final int totalCount;
  final int page;
  final int pageSize;
  final int totalPages;
  final bool hasPreviousPage;
  final bool hasNextPage;
  final bool isFromCache;

  factory PagedUsers.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    final items = rawItems
        .map((e) => UserItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final page = (json['page'] as num?)?.toInt() ?? 1;
    final totalPages = (json['totalPages'] as num?)?.toInt() ?? 1;
    return PagedUsers(
      items: items,
      totalCount: (json['totalCount'] as num?)?.toInt() ?? items.length,
      page: page,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 10,
      totalPages: totalPages < 1 ? 1 : totalPages,
      hasPreviousPage: (json['hasPreviousPage'] as bool?) ?? page > 1,
      hasNextPage: (json['hasNextPage'] as bool?) ?? page < totalPages,
    );
  }
}

DateTime? _parseDate(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

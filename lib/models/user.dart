import 'role.dart';

class User {
  final String id;
  final String name;
  final String email;
  final String? avatar;
  final String? userId;
  final String? tenantId;
  final List<Role>? roles;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
    this.userId,
    this.tenantId,
    this.roles,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    List<Role>? rolesList;
    if (json['roles'] != null) {
      rolesList = (json['roles'] as List)
          .map((role) => Role.fromJson(role as Map<String, dynamic>))
          .toList();
    }

    return User(
      id: json['id'] ?? json['user_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      avatar: json['avatar'],
      userId: json['user_id'],
      tenantId: json['tenant_id'],
      roles: rolesList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatar': avatar,
      'user_id': userId,
      'tenant_id': tenantId,
      'roles': roles?.map((role) => role.toJson()).toList(),
    };
  }

  // Helper method to get role names as strings
  List<String> get roleNames => roles?.map((r) => r.roleName).toList() ?? [];

  // Helper method to check if user has a specific role
  bool hasRole(String roleName) {
    return roles?.any((r) => r.roleName == roleName) ?? false;
  }
}

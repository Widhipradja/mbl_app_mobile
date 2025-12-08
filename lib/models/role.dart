class Role {
  final String userId;
  final String roleId;
  final String roleName;

  Role({required this.userId, required this.roleId, required this.roleName});

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      userId: json['user_id'] ?? '',
      roleId: json['role_id'] ?? '',
      roleName: json['role_name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'user_id': userId, 'role_id': roleId, 'role_name': roleName};
  }
}

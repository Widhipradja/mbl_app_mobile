import 'role.dart';

class User {
  final String id;
  final String name;
  final String email;
  final String? avatar;
  final String? userId;
  final String? tenantId;
  final String? firstname;
  final String? lastname;
  final String? surname;
  final String? phone;
  final bool? isActive;
  final String gender;
  final String? remark;
  final List<Role>? roles;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
    this.userId,
    this.tenantId,
    this.firstname,
    this.lastname,
    this.surname,
    this.phone,
    this.isActive,
    this.gender = 'male',
    this.roles,
    this.remark,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    List<Role>? rolesList;
    if (json['roles'] != null) {
      rolesList = (json['roles'] as List)
          .map((role) => Role.fromJson(role as Map<String, dynamic>))
          .toList();
    }

    final firstname = json['firstname'] ?? '';
    final lastname = json['lastname'] ?? '';
    final fullName = firstname.isNotEmpty || lastname.isNotEmpty
        ? '$firstname $lastname'.trim()
        : (json['name'] ?? '');

    // Map sex (M/F) to gender (male/female)
    String gender = 'male';
    final sexValue = json['sex'] ?? json['gender'];
    if (sexValue != null && sexValue.toString().isNotEmpty) {
      if (sexValue == 'M' || sexValue.toString().toLowerCase() == 'male') {
        gender = 'male';
      } else if (sexValue == 'F' ||
          sexValue.toString().toLowerCase() == 'female') {
        gender = 'female';
      }
    }

    final remark = json['remark'] ?? '';

    return User(
      id: json['id'] ?? json['user_id'] ?? '',
      name: fullName,
      email: json['email'] ?? '',
      avatar: json['avatar'],
      userId: json['user_id'],
      tenantId: json['tenant_id'],
      firstname: json['firstname'],
      lastname: json['lastname'],
      surname: json['surname'],
      phone: json['phone'],
      isActive: json['is_active'],
      gender: gender,
      remark: remark,
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
      'firstname': firstname,
      'lastname': lastname,
      'surname': surname,
      'phone': phone,
      'is_active': isActive,
      'gender': gender,
      'remark': remark,
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

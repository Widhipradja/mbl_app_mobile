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
  final String? groupName;

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
    this.groupName,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    List<Role>? rolesList;
    if (json['roles'] != null) {
      rolesList = (json['roles'] as List)
        .map((role) => Role.fromJson(role as Map<String, dynamic>))
        .toList();
    }

    // Accept multiple possible keys from different API responses
    final firstname = (json['firstname'] ?? json['first_name'] ?? json['firstName'])?.toString() ?? '';
    final lastname = (json['lastname'] ?? json['last_name'] ?? json['lastName'])?.toString() ?? '';
    final fullNameFromFields = (firstname.isNotEmpty || lastname.isNotEmpty)
      ? '$firstname $lastname'.trim()
      : '';
    final fullName = fullNameFromFields.isNotEmpty
      ? fullNameFromFields
      : (json['name'] ?? json['full_name'] ?? json['fullName'] ?? '');

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
      id: json['id'] ?? json['user_id'] ?? json['userId'] ?? '',
      name: fullName,
      email: json['email'] ?? '',
      avatar: json['avatar'],
      userId: json['user_id'],
      tenantId: json['tenant_id'],
      firstname: firstname.isNotEmpty ? firstname : null,
      lastname: lastname.isNotEmpty ? lastname : null,
      surname: json['surname'],
      phone: json['phone'],
      isActive: json['is_active'],
      gender: gender,
      remark: remark,
      roles: rolesList,
      groupName: json['group_name'],
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
      'first_name': firstname,
      'last_name': lastname,
      'surname': surname,
      'phone': phone,
      'is_active': isActive,
      'gender': gender,
      'remark': remark,
      'roles': roles?.map((role) => role.toJson()).toList(),
      'group_name': groupName,
    };
  }

  // Helper method to get role names as strings
  List<String> get roleNames => roles?.map((r) => r.roleName).toList() ?? [];

  // Helper method to check if user has a specific role
  bool hasRole(String roleName) {
    return roles?.any((r) => r.roleName == roleName) ?? false;
  }
}

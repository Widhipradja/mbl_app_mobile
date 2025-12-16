class Member {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final bool isActive;
  final String surname;
  final String sex; // M/F
  final String address;
  final String category; // Umum, Generus
  final String relationship; // suami, istri, anak, dll
  final String? familyId;
  final bool isHeadOfFamily;

  Member({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone = '',
    this.isActive = true,
    this.surname = '',
    required this.sex,
    this.address = '',
    this.category = 'Umum',
    this.relationship = '',
    this.familyId,
    this.isHeadOfFamily = false,
  });

  String get fullName => '$firstName $lastName'.trim();

  String get gender => sex == 'M' ? 'male' : 'female';

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      isActive: json['is_active'] ?? true,
      surname: json['surname'] ?? '',
      sex: json['sex'] ?? 'M',
      address: json['address'] ?? '',
      category: json['category'] ?? 'Umum',
      relationship: json['relationship'] ?? '',
      familyId: json['family_id'],
      isHeadOfFamily: json['is_head_of_family'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'is_active': isActive,
      'surname': surname,
      'sex': sex,
      'address': address,
      'category': category,
      'relationship': relationship,
      if (familyId != null) 'family_id': familyId,
      'is_head_of_family': isHeadOfFamily,
    };
  }
}

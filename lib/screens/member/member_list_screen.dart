import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/member.dart';
import '../../services/api_service.dart';
import '../../widgets/family_group_card.dart';

class MemberListScreen extends StatefulWidget {
  const MemberListScreen({super.key});

  @override
  State<MemberListScreen> createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen> {
  final ApiService _apiService = ApiService();
  List<Member> _members = [];
  final Map<String, List<Member>> _familyGroups = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.getMembers();
      if (response.statusCode == 200) {
        final List<dynamic> memberData = response.data is List
            ? response.data
            : (response.data['members'] ?? []);
        setState(() {
          _members = memberData.map((json) => Member.fromJson(json)).toList();
          _members.sort(
            (a, b) =>
                a.firstName.toLowerCase().compareTo(b.firstName.toLowerCase()),
          );
          _groupMembersByFamily();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _groupMembersByFamily() {
    _familyGroups.clear();
    for (var member in _members) {
      final familyKey = member.familyId ?? 'no-family-${member.id}';
      if (!_familyGroups.containsKey(familyKey)) {
        _familyGroups[familyKey] = [];
      }
      _familyGroups[familyKey]!.add(member);
    }

    // Sort members within each family: head of family first, then by name
    for (var family in _familyGroups.values) {
      family.sort((a, b) {
        if (a.isHeadOfFamily && !b.isHeadOfFamily) return -1;
        if (!a.isHeadOfFamily && b.isHeadOfFamily) return 1;
        return a.firstName.toLowerCase().compareTo(b.firstName.toLowerCase());
      });
    }
  }

  void _showMemberDialog({Member? member, String? familyId}) {
    final formKey = GlobalKey<FormState>();
    final firstnameController = TextEditingController(
      text: member?.firstName ?? '',
    );
    final lastnameController = TextEditingController(
      text: member?.lastName ?? '',
    );
    final surnameController = TextEditingController(
      text: member?.surname ?? '',
    );
    final emailController = TextEditingController(text: member?.email ?? '');
    final phoneController = TextEditingController(text: member?.phone ?? '');
    final addressController = TextEditingController(
      text: member?.address ?? '',
    );
    final relationshipController = TextEditingController(
      text: member?.relationship ?? '',
    );
    String selectedGender = member?.gender ?? 'male';
    String selectedCategory = member?.category ?? 'Umum';
    bool isHeadOfFamily = member?.isHeadOfFamily ?? false;
    final String? memberFamilyId = member?.familyId ?? familyId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(member == null ? 'Add Member' : 'Edit Member'),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: firstnameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter first name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: lastnameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: surnameController,
                      decoration: const InputDecoration(
                        labelText: 'Surname (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value != null &&
                            value.isNotEmpty &&
                            !value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: addressController,
                      decoration: const InputDecoration(
                        labelText: 'Address (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedGender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'male', child: Text('Male')),
                        DropdownMenuItem(
                          value: 'female',
                          child: Text('Female'),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedGender = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Umum', child: Text('Umum')),
                        DropdownMenuItem(
                          value: 'Generus',
                          child: Text('Generus'),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedCategory = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: relationshipController,
                      decoration: const InputDecoration(
                        labelText: 'Relationship (Optional)',
                        hintText: 'e.g., Suami, Istri, Anak',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('Head of Family'),
                      value: isHeadOfFamily,
                      onChanged: (value) {
                        setDialogState(() {
                          isHeadOfFamily = value ?? false;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  await _saveMember(
                    member: member,
                    firstname: firstnameController.text,
                    lastname: lastnameController.text,
                    surname: surnameController.text,
                    email: emailController.text,
                    phone: phoneController.text,
                    address: addressController.text,
                    gender: selectedGender,
                    category: selectedCategory,
                    relationship: relationshipController.text,
                    isHeadOfFamily: isHeadOfFamily,
                    familyId: memberFamilyId,
                  );
                }
              },
              child: Text(member == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveMember({
    Member? member,
    required String firstname,
    required String lastname,
    required String surname,
    required String email,
    required String phone,
    required String address,
    required String gender,
    required String category,
    required String relationship,
    required bool isHeadOfFamily,
    String? familyId,
  }) async {
    try {
      final data = {
        'first_name': firstname,
        'last_name': lastname,
        'surname': surname,
        'email': email,
        'phone': phone,
        'address': address,
        'sex': gender == 'male' ? 'M' : 'F',
        'category': category,
        'relationship': relationship,
        'is_head_of_family': isHeadOfFamily,
        'is_active': true,
        if (familyId != null) 'family_id': familyId,
      };

      if (member == null) {
        await _apiService.createMember(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Member added successfully')),
          );
        }
      } else {
        await _apiService.updateMember(member.id, data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Member updated successfully')),
          );
        }
      }
      _loadMembers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save member: $e')));
      }
    }
  }

  Future<void> _deleteMember(Member member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Member'),
        content: Text('Are you sure you want to delete ${member.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.deleteMember(member.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Member deleted successfully')),
          );
        }
        _loadMembers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete member: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        title: const Text('Member Management'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text('Error: $_error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadMembers,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : _members.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No members yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 80,
                ),
                itemCount: _familyGroups.length + 1,
                itemBuilder: (context, index) {
                  // First item is the summary
                  if (index == 0) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green[700]!, Colors.green[500]!],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Member Summary',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryItem(
                                  icon: Icons.family_restroom,
                                  label: 'Families',
                                  value: _familyGroups.values
                                      .where(
                                        (family) => !_familyGroups.keys
                                            .elementAt(
                                              _familyGroups.values
                                                  .toList()
                                                  .indexOf(family),
                                            )
                                            .startsWith('no-family-'),
                                      )
                                      .length
                                      .toString(),
                                ),
                              ),
                              Expanded(
                                child: _buildSummaryItem(
                                  icon: Icons.people,
                                  label: 'Members',
                                  value: _members.length.toString(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryItem(
                                  icon: Icons.male,
                                  label: 'Male',
                                  value: _members
                                      .where((m) => m.gender == 'male')
                                      .length
                                      .toString(),
                                ),
                              ),
                              Expanded(
                                child: _buildSummaryItem(
                                  icon: Icons.female,
                                  label: 'Female',
                                  value: _members
                                      .where((m) => m.gender == 'female')
                                      .length
                                      .toString(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryItem(
                                  icon: Icons.people_outline,
                                  label: 'Umum',
                                  value: _members
                                      .where((m) => m.category == 'Umum')
                                      .length
                                      .toString(),
                                ),
                              ),
                              Expanded(
                                child: _buildSummaryItem(
                                  icon: Icons.child_care,
                                  label: 'Generus',
                                  value: _members
                                      .where((m) => m.category == 'Generus')
                                      .length
                                      .toString(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }

                  // Family groups (index - 1 because first item is summary)
                  final familyIndex = index - 1;

                  // Sort family groups by head of family name
                  final sortedFamilyKeys = _familyGroups.keys.toList()
                    ..sort((a, b) {
                      final familyA = _familyGroups[a]!;
                      final familyB = _familyGroups[b]!;

                      // Find head of family in each group
                      final headA = familyA.firstWhere(
                        (m) => m.isHeadOfFamily,
                        orElse: () => familyA.first,
                      );
                      final headB = familyB.firstWhere(
                        (m) => m.isHeadOfFamily,
                        orElse: () => familyB.first,
                      );

                      return headA.firstName.toLowerCase().compareTo(
                        headB.firstName.toLowerCase(),
                      );
                    });

                  final familyId = sortedFamilyKeys[familyIndex];
                  final familyMembers = _familyGroups[familyId]!;
                  final isNoFamily = familyId.startsWith('no-family-');

                  return FamilyGroupCard(
                    familyId: familyId,
                    familyMembers: familyMembers,
                    isNoFamily: isNoFamily,
                    onEditMember: (member) => _showMemberDialog(member: member),
                    onDeleteMember: _deleteMember,
                    onAddFamilyMember: _showMemberDialog,
                  );
                  /*return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isNoFamily)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(4),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.family_restroom,
                                  size: 20,
                                  color: Colors.blue[700],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Family Group',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.person_add),
                                  color: Colors.blue[700],
                                  iconSize: 20,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: 'Add family member',
                                  onPressed: () =>
                                      _showMemberDialog(familyId: familyId),
                                ),
                              ],
                            ),
                          ),
                        // Separate Umum (adults) and Generus (children)
                        ...familyMembers
                            .where((m) => m.category == 'Umum')
                            .map(
                              (member) => ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: member.gender == 'male'
                                      ? Colors.blue[100]
                                      : Colors.pink[100],
                                  child: Text(
                                    member.fullName.isNotEmpty
                                        ? member.fullName[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color: member.gender == 'male'
                                          ? Colors.blue[700]
                                          : Colors.pink[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    if (member.isHeadOfFamily)
                                      Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.amber[700],
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Text(
                                          'HEAD',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    Expanded(
                                      child: Text(
                                        member.fullName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (member.surname.isNotEmpty)
                                      Text('Surname: ${member.surname}'),
                                    if (member.relationship.isNotEmpty &&
                                        !member.isHeadOfFamily)
                                      Text(
                                        'Relationship: ${member.relationship}',
                                      ),
                                    Text(member.email),
                                    if (member.phone.isNotEmpty)
                                      Text(member.phone),
                                  ],
                                ),
                                trailing: PopupMenuButton(
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, size: 20),
                                          SizedBox(width: 8),
                                          Text('Edit'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.delete,
                                            size: 20,
                                            color: Colors.red,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Delete',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _showMemberDialog(member: member);
                                    } else if (value == 'delete') {
                                      _deleteMember(member);
                                    }
                                  },
                                ),
                              ),
                            )
                            .toList(),
                        // Generus (children) section
                        if (familyMembers.any((m) => m.category == 'Generus'))
                          Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.purple[200]!,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.purple[100],
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(7),
                                      topRight: Radius.circular(7),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.child_care,
                                        size: 18,
                                        color: Colors.purple[700],
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Children',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.purple[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ...familyMembers
                                    .where((m) => m.category == 'Generus')
                                    .map(
                                      (member) => Container(
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Colors.purple[100]!,
                                              width: 0.5,
                                            ),
                                          ),
                                        ),
                                        child: ListTile(
                                          dense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 4,
                                              ),
                                          leading: CircleAvatar(
                                            radius: 18,
                                            backgroundColor:
                                                member.gender == 'male'
                                                ? Colors.purple[100]
                                                : Colors.pink[100],
                                            child: Icon(
                                              Icons.child_care,
                                              size: 16,
                                              color: member.gender == 'male'
                                                  ? Colors.purple[700]
                                                  : Colors.pink[700],
                                            ),
                                          ),
                                          title: Text(
                                            member.fullName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 14,
                                              color: Colors.purple[900],
                                            ),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (member.surname.isNotEmpty)
                                                Text(
                                                  'Surname: ${member.surname}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              if (member
                                                  .relationship
                                                  .isNotEmpty)
                                                Text(
                                                  'Relationship: ${member.relationship}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              if (member.email.isNotEmpty)
                                                Text(
                                                  member.email,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              if (member.phone.isNotEmpty)
                                                Text(
                                                  member.phone,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          trailing: PopupMenuButton(
                                            itemBuilder: (context) => [
                                              const PopupMenuItem(
                                                value: 'edit',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.edit, size: 18),
                                                    SizedBox(width: 8),
                                                    Text('Edit'),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.delete,
                                                      size: 18,
                                                      color: Colors.red,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      'Delete',
                                                      style: TextStyle(
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                            onSelected: (value) {
                                              if (value == 'edit') {
                                                _showMemberDialog(
                                                  member: member,
                                                );
                                              } else if (value == 'delete') {
                                                _deleteMember(member);
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );*/
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMemberDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

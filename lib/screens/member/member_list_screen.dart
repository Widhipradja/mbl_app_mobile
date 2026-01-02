import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/member.dart';
import '../../services/api_service.dart';
import '../../widgets/family_group_card.dart';
import 'member_statistics_category_screen.dart';

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
  int _selectedTab = 0; // 0: Tambah, 1: Daftar Keluarga, 2: Statistik

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

  Widget _buildTabButton(String label, int index) {
    final isActive = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white
              : Colors.grey.shade200.withOpacity(0.85),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? Colors.indigo.shade600 : Colors.indigo.shade400,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildAddTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tambah Member Baru',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tambahkan anggota keluarga baru',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showMemberDialog(),
              icon: const Icon(Icons.person_add),
              label: const Text('Tambah Member'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tips Mengelola Member',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTipItem('Tandai kepala keluarga untuk setiap keluarga'),
                _buildTipItem(
                  'Gunakan relationship untuk menunjukkan hubungan',
                ),
                _buildTipItem('Pisahkan kategori Umum dan Generus'),
                _buildTipItem(
                  'Lengkapi data kontak untuk kemudahan komunikasi',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.blue.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersListTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Terjadi Kesalahan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMembers,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }
    if (_members.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline,
                size: 60,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Belum ada member',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tambahkan member pertama Anda',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }
    // List of family groups
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ..._familyGroups.entries.map((entry) {
          final familyId = entry.key;
          final familyMembers = entry.value;
          final isNoFamily = familyId.startsWith('no-family-');
          return FamilyGroupCard(
            familyId: familyId,
            familyMembers: familyMembers,
            isNoFamily: isNoFamily,
            onEditMember: (member) => _showMemberDialog(member: member),
            onDeleteMember: _deleteMember,
            onAddFamilyMember: _showMemberDialog,
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade50, Colors.indigo.shade50],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Gradient Header
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.indigo.shade600, Colors.purple.shade600],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.groups,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Anggota Keluarga',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Kelola data anggota keluarga',
                                  style: TextStyle(
                                    color: Colors.indigo.shade100,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => context.go('/dashboard'),
                            icon: const Icon(
                              Icons.home_outlined,
                              color: Colors.white,
                            ),
                            tooltip: 'Dashboard',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Stats Row (example)
                      Row(
                        children: [
                          _buildHeaderStat(
                            'Keluarga',
                            _familyGroups.length.toString(),
                            Icons.family_restroom,
                          ),
                          const SizedBox(width: 16),
                          _buildHeaderStat(
                            'Member',
                            _members.length.toString(),
                            Icons.people,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Tab Navigation
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _buildTabButton('Tambah', 0)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTabButton('Daftar', 1)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTabButton('Statistik', 2)),
                    ],
                  ),
                ),
              ),
              // Tab Content
              Expanded(
                child: _selectedTab == 0
                    ? _buildAddTab()
                    : _selectedTab == 1
                    ? _buildMembersListTab()
                    : _buildStatisticsTab(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildStatisticsTab() {
    final familiesCount = _familyGroups.values
        .where(
          (family) => !_familyGroups.keys
              .elementAt(_familyGroups.values.toList().indexOf(family))
              .startsWith('no-family-'),
        )
        .length;
    final maleCount = _members.where((m) => m.gender == 'male').length;
    final femaleCount = _members.where((m) => m.gender == 'female').length;
    final umumCount = _members.where((m) => m.category == 'Umum').length;
    final generusCount = _members.where((m) => m.category == 'Generus').length;
    final currentYear = DateTime.now().year;

    void openStatistics({
      String category = 'all',
      String sex = 'all',
      String familyId = 'all',
    }) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MemberStatisticsCategoryScreen(
            category: category,
            year: currentYear,
            sex: sex,
            familyId: familyId,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth,
              maxWidth: constraints.maxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Statistik Member',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 20),
                // Total Overview
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.indigo.shade600, Colors.purple.shade600],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigo.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.people,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Member',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              _members.length.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Statistics Grid (tappable cards)
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    GestureDetector(
                      onTap: () => openStatistics(
                        category: 'all',
                        sex: 'all',
                        familyId: 'all',
                      ),
                      child: _buildStatCard(
                        'Keluarga',
                        familiesCount.toString(),
                        Icons.family_restroom,
                        Colors.green,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => openStatistics(
                        category: 'all',
                        sex: 'M',
                        familyId: 'all',
                      ),
                      child: _buildStatCard(
                        'Laki-laki',
                        maleCount.toString(),
                        Icons.male,
                        Colors.blue,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => openStatistics(
                        category: 'all',
                        sex: 'F',
                        familyId: 'all',
                      ),
                      child: _buildStatCard(
                        'Wanita',
                        femaleCount.toString(),
                        Icons.female,
                        Colors.pink,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => openStatistics(
                        category: 'Umum',
                        sex: 'all',
                        familyId: 'all',
                      ),
                      child: _buildStatCard(
                        'Umum',
                        umumCount.toString(),
                        Icons.people_outline,
                        Colors.orange,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => openStatistics(
                        category: 'Generus',
                        sex: 'all',
                        familyId: 'all',
                      ),
                      child: _buildStatCard(
                        'Generus',
                        generusCount.toString(),
                        Icons.child_care,
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

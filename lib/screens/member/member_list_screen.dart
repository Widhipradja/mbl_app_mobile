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
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
      } else {
        setState(() {
          _error = 'Server error: ${response.statusCode}';
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
    String selectedCategory = member?.category ?? 'Dewasa';
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
                      value: selectedGender,
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
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Dewasa',
                          child: Text('Dewasa'),
                        ),
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
                _buildTipItem(
                  'Gunakan relationship "Anak" untuk menandai anak',
                ),
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
    // Filter family groups by search query
    final query = _searchQuery.toLowerCase();
    final filteredGroups = query.isEmpty
        ? _familyGroups
        : Map.fromEntries(
            _familyGroups.entries
                .map((entry) {
                  final matchingMembers = entry.value
                      .where((m) => m.fullName.toLowerCase().contains(query))
                      .toList();
                  return MapEntry(entry.key, matchingMembers);
                })
                .where((entry) => entry.value.isNotEmpty),
          );

    if (filteredGroups.isEmpty && query.isNotEmpty) {
      return Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    'Tidak ada member "$_searchQuery"',
                    style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // List of family groups
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              ...filteredGroups.entries.map((entry) {
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
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Cari nama member...',
          prefixIcon: const Icon(Icons.search, color: Colors.indigo),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() {
                    _searchQuery = '';
                    _searchController.clear();
                  }),
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.indigo.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.indigo.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.indigo.shade500, width: 1.5),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final familiesCount = _familyGroups.values
        .where(
          (family) => !_familyGroups.keys
              .elementAt(_familyGroups.values.toList().indexOf(family))
              .startsWith('no-family-'),
        )
        .length;
    final maleCount = _members.where((m) => m.gender == 'male').length;
    final femaleCount = _members.where((m) => m.gender == 'female').length;
    final generusCount = _members.where((m) => m.relationship == 'Anak').length;
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
                      // Stats Row
                      Row(
                        children: [
                          Expanded(child: _buildHeaderStat('KK', familiesCount.toString(), Icons.family_restroom)),
                          Expanded(child: _buildHeaderStat('Member', _members.length.toString(), Icons.people)),
                          Expanded(child: _buildHeaderStat('L', maleCount.toString(), Icons.male)),
                          Expanded(child: _buildHeaderStat('P', femaleCount.toString(), Icons.female)),
                          Expanded(child: _buildHeaderStat('Anak', generusCount.toString(), Icons.child_care)),
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth,
              maxWidth: constraints.maxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Per-Category breakdown
                Builder(
                  builder: (context) {
                    // Count per category
                    final Map<String, int> categoryCount = {};
                    // Count per category per sex
                    final Map<String, int> categoryMale = {};
                    final Map<String, int> categoryFemale = {};
                    for (final m in _members) {
                      categoryCount[m.category] =
                          (categoryCount[m.category] ?? 0) + 1;
                      if (m.sex == 'M') {
                        categoryMale[m.category] =
                            (categoryMale[m.category] ?? 0) + 1;
                      } else {
                        categoryFemale[m.category] =
                            (categoryFemale[m.category] ?? 0) + 1;
                      }
                    }
                    final categoryOrder = [
                      'Dewasa',
                      'Usia Nikah',
                      'Remaja',
                      'Pra Remaja',
                      'Generus',
                      'CR',
                    ];
                    final sortedCategories = categoryCount.entries.toList()
                      ..sort((a, b) {
                        final idxA = categoryOrder.indexOf(a.key);
                        final idxB = categoryOrder.indexOf(b.key);
                        if (idxA == -1 && idxB == -1) {
                          return a.key.compareTo(b.key);
                        }
                        if (idxA == -1) return 1;
                        if (idxB == -1) return -1;
                        return idxA.compareTo(idxB);
                      });
                    final maxCount = sortedCategories.isEmpty
                        ? 1
                        : sortedCategories.first.value;

                    IconData categoryIcon(String cat) {
                      switch (cat) {
                        case 'Dewasa':
                          return Icons.people_outline;
                        case 'Balita':
                          return Icons.child_care;
                        case 'Remaja':
                          return Icons.school;
                        case 'CR':
                          return Icons.boy;
                        case 'Generus':
                          return Icons.star_outline;
                        default:
                          return Icons.group_outlined;
                      }
                    }

                    final categoryColors = [
                      Colors.indigo,
                      Colors.teal,
                      Colors.orange,
                      Colors.purple,
                      Colors.green,
                      Colors.pink,
                      Colors.cyan,
                      Colors.amber,
                    ];

                    // Helper: small column header
                    Widget colHeader(String label, Color color) => SizedBox(
                      width: 36,
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    );

                    // Helper: small count cell
                    Widget colCell(int count, Color color) => SizedBox(
                      width: 36,
                      child: Text(
                        count.toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    );

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          // Table header
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 28),
                                Expanded(
                                  child: Text(
                                    'Kategori',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo.shade700,
                                    ),
                                  ),
                                ),
                                colHeader('L', Colors.blue.shade700),
                                const SizedBox(width: 4),
                                colHeader('P', Colors.pink.shade700),
                                const SizedBox(width: 4),
                                colHeader('Total', Colors.indigo.shade700),
                              ],
                            ),
                          ),
                          // Table rows
                          ...sortedCategories.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final cat = entry.value.key;
                            final count = entry.value.value;
                            final male = categoryMale[cat] ?? 0;
                            final female = categoryFemale[cat] ?? 0;
                            final color =
                                categoryColors[idx % categoryColors.length];
                            final isLast = idx == sortedCategories.length - 1;

                            return InkWell(
                              onTap: () => openStatistics(
                                category: cat,
                                sex: 'all',
                                familyId: 'all',
                              ),
                              borderRadius: isLast
                                  ? const BorderRadius.vertical(
                                      bottom: Radius.circular(16),
                                    )
                                  : BorderRadius.zero,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  border: isLast
                                      ? null
                                      : Border(
                                          bottom: BorderSide(
                                            color: Colors.grey.shade100,
                                          ),
                                        ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      categoryIcon(cat),
                                      size: 20,
                                      color: color,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cat,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            child: LinearProgressIndicator(
                                              value: count / maxCount,
                                              backgroundColor: color
                                                  .withOpacity(0.1),
                                              valueColor:
                                                  AlwaysStoppedAnimation(
                                                    color.withOpacity(0.7),
                                                  ),
                                              minHeight: 5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    colCell(male, Colors.blue.shade600),
                                    const SizedBox(width: 4),
                                    colCell(female, Colors.pink.shade600),
                                    const SizedBox(width: 4),
                                    SizedBox(
                                      width: 36,
                                      child: Text(
                                        count.toString(),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

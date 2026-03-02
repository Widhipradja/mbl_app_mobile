import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/zakat_provider.dart';
import '../../services/api_service.dart';
import '../../models/muzakki.dart';

class AddMuzakkiScreen extends StatefulWidget {
  const AddMuzakkiScreen(
      {super.key, this.initialFamilyId = '', this.initialMuzakki});

  /// Pre-filled family ID. Empty = create new family.
  final String initialFamilyId;

  /// If provided, screen will work in edit mode for this muzakki.
  final Muzakki? initialMuzakki;

  @override
  State<AddMuzakkiScreen> createState() => _AddMuzakkiScreenState();
}

class _AddMuzakkiScreenState extends State<AddMuzakkiScreen> {
  final _formKey = GlobalKey<FormState>();

  // Personal info
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _groupNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  // Family
  final _familyIdController = TextEditingController(); // empty = new family
  String _sex = 'M';
  String _relationship = 'Suami';
  bool _isHeadOfFamily = false;
  bool _isInternal = true;

  bool _isLoading = false;

  bool get _isJoiningFamily => widget.initialFamilyId.isNotEmpty;

  static const _green = Color(0xFF066046);
  static const _greenLight = Color(0xFFE8F5F0);

  static const _sexOptions = ['M', 'F'];
  static const _sexLabels = {'M': '♂ Laki-laki', 'F': '♀ Perempuan'};

  static const _relationships = [
    'Suami',
    'Istri',
    'Anak',
    'Orang Tua',
    'Saudara',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    // If editing an existing muzakki, pre-fill fields
    if (widget.initialMuzakki != null) {
      final m = widget.initialMuzakki!;
      _firstNameController.text = m.firstName;
      _lastNameController.text = m.lastName;
      _surnameController.text = m.surname;
      _groupNameController.text = m.groupName;
      _phoneController.text = m.phone;
      _addressController.text = m.address;
      _familyIdController.text = m.familyId;
      _sex = m.sex;
      _relationship =
          m.relationship.isNotEmpty ? m.relationship : _relationship;
      _isHeadOfFamily = m.isHeadOfFamily;
      _isInternal = m.isInternal;
    } else if (widget.initialFamilyId.isNotEmpty) {
      _familyIdController.text = widget.initialFamilyId;
      _isHeadOfFamily = false;
      _relationship = 'Istri';
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _surnameController.dispose();
    _groupNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _familyIdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ZakatProvider>();
    final yearId = provider.selectedYear?.id ?? '';
    if (yearId.isEmpty) {
      _showError('Pilih tahun zakat terlebih dahulu');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final api = ApiService();
      if (widget.initialMuzakki != null) {
        // Edit existing muzakki via PUT
        await api.updateZakatMuzakki(widget.initialMuzakki!.id, {
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'surname': _surnameController.text.trim(),
          'sex': _sex,
          'relationship': _relationship,
          'is_head_of_family': _isHeadOfFamily,
          'is_internal': _isInternal,
          'family_id': _familyIdController.text.trim(),
          'address': _addressController.text.trim(),
          'phone': _phoneController.text.trim(),
          'group_name': widget.initialMuzakki?.groupName ?? '',
        });
      } else {
        await api.createMuzakki(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          surname: _surnameController.text.trim(),
          sex: _sex,
          relationship: _relationship,
          isHeadOfFamily: _isHeadOfFamily,
          isInternal: _isInternal,
          familyId: _familyIdController.text.trim(),
          address: _addressController.text.trim(),
          phone: _phoneController.text.trim(),
          groupName: _isJoiningFamily ? '' : _groupNameController.text.trim(),
          yearId: yearId,
        );
      }

      final name =
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
              .trim();

      // Re-fetch the list from API to get updated data
      await provider.fetchMuzakki();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.initialMuzakki != null
                ? 'Muzakki "$name" berhasil diperbarui'
                : 'Muzakki "$name" berhasil ditambahkan'),
            backgroundColor: _green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        _closeAfterSubmit();
      }
    } catch (e) {
      if (mounted) _showError('Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _closeAfterSubmit() {
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go('/zakat-fitrah');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: _closeAfterSubmit,
        ),
        title: Text(
          _isJoiningFamily ? 'Tambah Anggota Keluarga' : 'Tambah Muzakki',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
            fontSize: 18,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Year info banner ──────────────────────────────────────
              Consumer<ZakatProvider>(
                builder: (_, p, __) => Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _greenLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _green.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          color: _green, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        p.selectedYear?.label ?? 'Tidak ada tahun dipilih',
                        style: const TextStyle(
                          fontSize: 13,
                          color: _green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ─────────────────────────────────────────────────────────
              // Section 1: Data Pribadi
              // ─────────────────────────────────────────────────────────
              _sectionHeader('Data Pribadi'),
              const SizedBox(height: 12),

              _label('Nama Depan *'),
              const SizedBox(height: 6),
              _textField(
                controller: _firstNameController,
                hint: 'Contoh: Abdul',
                icon: Icons.person_outline,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Nama depan wajib diisi' : null,
              ),
              const SizedBox(height: 14),

              _label('Nama Belakang'),
              const SizedBox(height: 6),
              _textField(
                controller: _lastNameController,
                hint: 'Contoh: Aziz',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 14),

              _label('Nama Keluarga / Marga'),
              const SizedBox(height: 6),
              _textField(
                controller: _surnameController,
                hint: 'Contoh: Aziz (dipakai utk pengelompokan keluarga)',
                icon: Icons.family_restroom_outlined,
              ),
              if (!_isJoiningFamily && widget.initialMuzakki == null) ...[
                const SizedBox(height: 14),
                _label('Group Name *'),
                const SizedBox(height: 6),
                _textField(
                  controller: _groupNameController,
                  hint: 'Contoh: MBL 1',
                  icon: Icons.group_work_outlined,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Group name wajib diisi'
                      : null,
                ),
              ],
              const SizedBox(height: 14),

              // Sex toggle
              _label('Jenis Kelamin *'),
              const SizedBox(height: 8),
              Row(
                children: _sexOptions
                    .map(
                      (s) => Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: s == 'M' ? 8 : 0),
                          child: _ToggleButton(
                            label: _sexLabels[s]!,
                            isSelected: _sex == s,
                            onTap: () {
                              setState(() {
                                _sex = s;
                                // Auto-suggest relationship by sex
                                if (s == 'M' && _relationship == 'Istri') {
                                  _relationship = 'Suami';
                                } else if (s == 'F' &&
                                    _relationship == 'Suami') {
                                  _relationship = 'Istri';
                                }
                              });
                            },
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),

              _label('No. HP'),
              const SizedBox(height: 6),
              _textField(
                controller: _phoneController,
                hint: 'Contoh: 08123456789',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 14),

              _label('Alamat'),
              const SizedBox(height: 6),
              _textField(
                controller: _addressController,
                hint: 'Contoh: MBL 1',
                icon: Icons.home_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // ─────────────────────────────────────────────────────────
              // Section 2: Data Keluarga
              // ─────────────────────────────────────────────────────────
              _sectionHeader('Data Keluarga'),
              const SizedBox(height: 12),

              // Relationship dropdown
              _label('Hubungan dalam Keluarga *'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _relationships.map((r) {
                  final isSelected = _relationship == r;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _relationship = r;
                      // Auto-set head of family if Suami
                      if (r == 'Suami') _isHeadOfFamily = true;
                      if (r == 'Istri' || r == 'Anak') {
                        _isHeadOfFamily = false;
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? _green : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? _green : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        r,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isInternal ? _green : const Color(0xFFE2E8F0),
                    width: _isInternal ? 1.5 : 1,
                  ),
                ),
                child: SwitchListTile(
                  value: _isInternal,
                  onChanged: (v) => setState(() => _isInternal = v),
                  activeColor: _green,
                  title: const Text(
                    'Anggota Internal Komunitas',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  subtitle: Text(
                    _isInternal
                        ? 'Tercatat sebagai anggota komunitas'
                        : 'Muzakki eksternal (join hanya untuk zakat)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  secondary: Icon(
                    _isInternal ? Icons.groups_rounded : Icons.public_rounded,
                    color: _isInternal
                        ? const Color(0xFF1D4ED8)
                        : const Color(0xFF7E22CE),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Head of family toggle
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isHeadOfFamily ? _green : const Color(0xFFE2E8F0),
                    width: _isHeadOfFamily ? 1.5 : 1,
                  ),
                ),
                child: SwitchListTile(
                  value: _isHeadOfFamily,
                  onChanged: (v) => setState(() => _isHeadOfFamily = v),
                  activeColor: _green,
                  title: const Text(
                    'Kepala Keluarga (KK)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  subtitle: const Text(
                    'Tandai jika anggota ini adalah kepala keluarga',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                  secondary: Icon(
                    Icons.star_rounded,
                    color: _isHeadOfFamily
                        ? const Color(0xFFE65100)
                        : const Color(0xFFCBD5E1),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Family ID
              _label('ID Keluarga'),
              const SizedBox(height: 4),
              if (_isJoiningFamily) ...[
                // Read-only: show locked chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline,
                          size: 18, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.initialFamilyId,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5F0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Bergabung',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const Text(
                  'Kosongkan untuk membuat keluarga baru.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 8),
                _textField(
                  controller: _familyIdController,
                  hint: 'Kosong = buat keluarga baru',
                  icon: Icons.link_outlined,
                ),
              ],
              const SizedBox(height: 32),

              // ── Submit ─────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(
                    _isLoading ? 'Menyimpan…' : 'Simpan Data Muzakki',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _green.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _closeAfterSubmit,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Batal',
                    style: TextStyle(
                        color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title) => Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: _green,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      );

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF334155),
          fontSize: 13,
        ),
      );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
          prefixIcon: Icon(icon, size: 20, color: const Color(0xFF94A3B8)),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _green, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1.5),
          ),
        ),
      );
}

// ─────────────────────────────────────────────
// Sex Toggle Button
// ─────────────────────────────────────────────
class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  static const _green = Color(0xFF066046);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F5F0) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _green : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? _green : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

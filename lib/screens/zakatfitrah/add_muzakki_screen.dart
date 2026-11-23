import '../../config/baraka_tokens.dart';
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
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  // Family
  final _familyIdController = TextEditingController(); // empty = new family
  String _sex = 'M';
  String _relationship = 'Suami';
  bool _isHeadOfFamily = false;
  bool _isInternal = true;

  // Master Eksternal (global). Required for external muzakki, optional
  // (afiliasi) for internal ones.
  String? _selectedExternalId;

  bool _isLoading = false;

  bool get _isJoiningFamily => widget.initialFamilyId.isNotEmpty;

  static const _green = Color(0xFF066046);

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
      _phoneController.text = m.phone;
      _addressController.text = m.address;
      _familyIdController.text = m.familyId;
      _sex = m.sex;
      _relationship =
          m.relationship.isNotEmpty ? m.relationship : _relationship;
      _isHeadOfFamily = m.isHeadOfFamily;
      _isInternal = m.isInternal;
      _selectedExternalId = m.externalId.isNotEmpty ? m.externalId : null;
      // Older records only have the external's name; match it to the master
      // list once that is loaded.
      if (_selectedExternalId == null && m.externalName.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final match = context
              .read<ZakatProvider>()
              .externals
              .where((e) => e.name == m.externalName);
          if (match.isNotEmpty) {
            setState(() => _selectedExternalId = match.first.id);
          }
        });
      }
    } else if (widget.initialFamilyId.isNotEmpty) {
      _familyIdController.text = widget.initialFamilyId;
      _isHeadOfFamily = false;
      _relationship = 'Istri';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final zakat = context.read<ZakatProvider>();
      if (zakat.externals.isEmpty && !zakat.isLoadingExternals) {
        zakat.fetchExternals();
      }
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _surnameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _familyIdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Jika external, wajib pilih eksternal
    if (!_isInternal && _selectedExternalId == null) {
      _showError('Pilih eksternal untuk muzakki ini');
      return;
    }

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
          // `external_id` is authoritative; the name fields keep older
          // backends working until they are migrated.
          'external_id': _isInternal ? '' : (_selectedExternalId ?? ''),
          'group_name': _isInternal
              ? (widget.initialMuzakki?.groupName ?? '')
              : _selectedExternalName,
          'afiliasi': '',
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
          groupName: _isInternal ? '' : _selectedExternalName,
          externalId: _isInternal ? '' : (_selectedExternalId ?? ''),
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

  String get _selectedExternalName {
    final id = _selectedExternalId;
    if (id == null) return '';
    final match =
        context.read<ZakatProvider>().externals.where((e) => e.id == id);
    return match.isNotEmpty ? match.first.name : '';
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

  /// Returns to the Muzakki list, keeping its search/filter state when this
  /// screen was pushed on top of it.
  void _closeAfterSubmit() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/zakat-fitrah/muzakki');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeAfterSubmit();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7F6),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
            onPressed: _closeAfterSubmit,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.initialMuzakki != null
                    ? 'Edit Muzakki'
                    : _isJoiningFamily
                        ? 'Tambah Anggota Keluarga'
                        : 'Tambah Muzakki',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                  fontSize: 18,
                ),
              ),
              Text(
                context.watch<ZakatProvider>().selectedYear?.label ??
                    'Tidak ada tahun dipilih',
                style: const TextStyle(fontSize: 12, color: _green),
              ),
            ],
          ),
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Nama ──────────────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _field(
                        controller: _firstNameController,
                        label: 'Nama Depan *',
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Wajib diisi'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _field(
                        controller: _lastNameController,
                        label: 'Nama Belakang',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _field(
                  controller: _surnameController,
                  label: 'Marga / Nama Keluarga',
                  helper: 'Dipakai untuk pengelompokan keluarga',
                ),
                const SizedBox(height: 12),

                // ── Jenis kelamin ─────────────────────────────────────────
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
                const SizedBox(height: 12),

                // ── Hubungan ──────────────────────────────────────────────
                _label('Hubungan dalam Keluarga *'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _relationships.map((r) {
                    final isSelected = _relationship == r;
                    return ChoiceChip(
                      label: Text(r),
                      selected: isSelected,
                      showCheckmark: false,
                      selectedColor: _green,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: isSelected ? _green : const Color(0xFFE3EAE6),
                      ),
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            isSelected ? Colors.white : const Color(0xFF334155),
                      ),
                      onSelected: (_) => setState(() {
                        _relationship = r;
                        // Auto-set head of family if Suami
                        if (r == 'Suami') _isHeadOfFamily = true;
                        if (r == 'Istri' || r == 'Anak') {
                          _isHeadOfFamily = false;
                        }
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                // ── Kontak ────────────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _field(
                        controller: _phoneController,
                        label: 'No. HP',
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _field(
                        controller: _addressController,
                        label: 'Alamat',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Status: internal + kepala keluarga, one card ──────────
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE3EAE6)),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        dense: true,
                        value: _isInternal,
                        onChanged: (v) {
                          setState(() {
                            _isInternal = v;
                            // Internal members belong to no external.
                            if (v) _selectedExternalId = null;
                          });
                        },
                        activeColor: _green,
                        title: const Text(
                          'Anggota internal komunitas',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          _isInternal
                              ? 'Tercatat sebagai anggota komunitas'
                              : 'Muzakki eksternal (hanya untuk zakat)',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF5B6B65)),
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE3EAE6)),
                      SwitchListTile(
                        dense: true,
                        value: _isHeadOfFamily,
                        onChanged: (v) => setState(() => _isHeadOfFamily = v),
                        activeColor: _green,
                        title: const Text(
                          'Kepala keluarga (KK)',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Eksternal picker (Master Eksternal) — non-internal only ──
                if (!_isInternal) ...[
                  const SizedBox(height: 14),
                  Consumer<ZakatProvider>(
                    builder: (context, zakat, _) {
                      // Keep the saved choice visible even if it was since
                      // deactivated.
                      final options = zakat.externals
                          .where(
                              (e) => e.isActive || e.id == _selectedExternalId)
                          .toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Pilih Eksternal *'),
                          const SizedBox(height: 8),
                          if (zakat.isLoadingExternals && options.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: _green),
                                ),
                              ),
                            )
                          else if (options.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: const Color(0xFFFED7AA)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      size: 15, color: Color(0xFFD97706)),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Belum ada data eksternal. Tambahkan di Config → Master Eksternal.',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFD97706)),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: options.map((e) {
                                final isSelected = _selectedExternalId == e.id;
                                return GestureDetector(
                                  // Exactly one external; tapping another switches.
                                  onTap: () => setState(
                                      () => _selectedExternalId = e.id),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF7E22CE)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF7E22CE)
                                            : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Text(
                                      e.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFF7E22CE),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      );
                    },
                  ),
                ],
                const SizedBox(height: 12),

                // Family: show the family's name, not its raw id.
                if (_isJoiningFamily)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Bk.brandSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.family_restroom_rounded,
                            size: 18, color: _green),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Bergabung ke $_joiningFamilyName',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Bk.brandDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  // Rarely needed, so it stays out of the way.
                  Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 8),
                      title: const Text(
                        'Gabung ke keluarga yang sudah ada (opsional)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Bk.textMuted,
                        ),
                      ),
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Lebih mudah: buka kartu keluarga di daftar Muzakki '
                            'lalu pilih "Tambah Anggota Keluarga". Atau isi ID '
                            'keluarga di sini; kosong = keluarga baru.',
                            style: TextStyle(fontSize: 12, color: Bk.textMuted),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _textField(
                          controller: _familyIdController,
                          hint: 'ID keluarga',
                          icon: Icons.link_outlined,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 32),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        // Save stays reachable without scrolling to the end of the form.
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Bk.line)),
          ),
          padding: EdgeInsets.fromLTRB(
              16, 10, 16, 10 + MediaQuery.viewInsetsOf(context).bottom),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _green.withOpacity(0.5),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Bk.radiusButton),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(
                        _isJoiningFamily ? 'Simpan Anggota' : 'Simpan Muzakki',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get _joiningFamilyName {
    final members = context
        .read<ZakatProvider>()
        .muzakkiList
        .where((m) => m.familyId == widget.initialFamilyId)
        .toList();
    if (members.isEmpty) return 'keluarga ini';
    final head = members.firstWhere((m) => m.isHeadOfFamily,
        orElse: () => members.first);
    return 'Keluarga ${head.surname.isNotEmpty ? head.surname : head.firstName}';
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? helper,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperStyle: const TextStyle(fontSize: 11),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE3EAE6)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE3EAE6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _green, width: 1.5),
          ),
        ),
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
        padding: const EdgeInsets.symmetric(vertical: 11),
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

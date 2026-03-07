import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/muzakki.dart';
import '../../providers/zakat_provider.dart';
import '../../services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Amil model (from /api/zakat-fitrah/amil)
// ─────────────────────────────────────────────────────────────────────────────
class _Amil {
  final String id;
  final String name;
  final String groupName;

  const _Amil({required this.id, required this.name, this.groupName = ''});

  factory _Amil.fromJson(Map<String, dynamic> j) => _Amil(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        groupName: j['group_name'] as String? ?? '',
      );
}

enum _ZakatType { beras, uang, campuran }

enum _SerahTerimaMode { none, titip, akad }

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class ZakatTransactionScreen extends StatefulWidget {
  const ZakatTransactionScreen({super.key, required this.muzakki});

  final Muzakki muzakki;

  @override
  State<ZakatTransactionScreen> createState() => _ZakatTransactionScreenState();
}

class _ZakatTransactionScreenState extends State<ZakatTransactionScreen> {
  static const _green = Color(0xFF066046);
  static const _greenLight = Color(0xFFE8F5F0);
  static const _bg = Color(0xFFF4F7F6);

  // ── Form state ────────────────────────────────────────────────────────────
  _ZakatType _type = _ZakatType.beras;

  /// IDs of selected family members
  final Set<String> _selectedIds = {};
  final Set<String> _moneyIds = {};
  int _externalSouls = 0;
  int _externalMoneySouls = 0;

  _Amil? _selectedAmil;
  final _catatanCtrl = TextEditingController();

  // ── Serah Terima state ────────────────────────────────────────────────────
  _SerahTerimaMode _serahTerimaMode = _SerahTerimaMode.none;

  // ── Amil list ─────────────────────────────────────────────────────────────
  List<_Amil> _amilList = [];
  bool _loadingAmil = true;
  double _titipUangRate = 45000;
  String _ikrarZakat = '';
  bool _loadingIkrar = true;

  bool _isSubmitting = false;

  bool get _isEditMode => widget.muzakki.isPaid;

  // ── Computed helpers ─────────────────────────────────────────────────────
  double get _riceRatePerSo =>
      context.read<ZakatProvider>().selectedYear?.riceRatePerSo ??
      _titipUangRate;

  int get _jiwa => _selectedIds.length;
  int get _totalSouls => _jiwa + _externalSouls;
  int get _moneyJiwa {
    if (_type == _ZakatType.uang) return _totalSouls;
    if (_type != _ZakatType.campuran) return 0;
    return _selectedIds.where((id) => _moneyIds.contains(id)).length +
        _externalMoneySouls;
  }

  int get _riceJiwa => _totalSouls - _moneyJiwa;
  double get _totalUang => _moneyJiwa * _riceRatePerSo;
  int get _externalRiceSouls => _externalSouls - _externalMoneySouls;

  /// All members of the same family from the loaded muzakki list.
  List<Muzakki> get _familyMembers {
    final provider = context.read<ZakatProvider>();
    final fid = widget.muzakki.familyId;
    if (fid.isEmpty) return [widget.muzakki];
    final members =
        provider.muzakkiList.where((m) => m.familyId == fid).toList();
    return members.isEmpty ? [widget.muzakki] : members;
  }

  bool get _allSelected =>
      _familyMembers.isNotEmpty &&
      _familyMembers.every((m) => _selectedIds.contains(m.id));

  @override
  void initState() {
    super.initState();
    final externalData = context
        .read<ZakatProvider>()
        .getExternalByFamilyId(widget.muzakki.familyId);

    // If opened from "Edit Bayar Zakat" (paid muzakki), pre-select paid members.
    if (widget.muzakki.isPaid) {
      final paidMembers = _familyMembers.where((m) => m.isPaid).toList();
      _selectedIds.addAll(paidMembers.map((m) => m.id));
      if (_selectedIds.isEmpty) {
        _selectedIds.add(widget.muzakki.id);
      }

      _moneyIds.addAll(
        paidMembers
            .where((m) => m.paymentType == PaymentType.uang)
            .map((m) => m.id),
      );

      if (externalData != null) {
        _externalSouls = externalData.externalTotalSouls;
        _externalMoneySouls = externalData.externalTotalMoneySouls;
      }

      final hasMoney = _moneyIds.isNotEmpty || _externalMoneySouls > 0;
      final registeredRiceCount = _selectedIds.length - _moneyIds.length;
      final externalRiceSouls = _externalSouls - _externalMoneySouls;
      final hasRice = registeredRiceCount > 0 || externalRiceSouls > 0;

      if (hasMoney && hasRice) {
        _type = _ZakatType.campuran;
      } else if (hasMoney) {
        _type = _ZakatType.uang;
      } else {
        _type = _ZakatType.beras;
      }
    } else {
      // Default behavior for new payment flow.
      _selectedIds.add(widget.muzakki.id);
    }
    _fetchTitipUangRate();
    _fetchAmil();
    _fetchIkrarZakat();
  }

  @override
  void dispose() {
    _catatanCtrl.dispose();
    super.dispose();
  }

  // ── Data fetching ────────────────────────────────────────────────────────
  Future<void> _fetchAmil() async {
    setState(() => _loadingAmil = true);
    try {
      final api = ApiService();
      final yearId = context.read<ZakatProvider>().selectedYear?.id ?? '';
      final resp = await api.getZakatAmilList(
        yearId: yearId.isNotEmpty ? yearId : null,
      );
      final raw = resp.data;
      final list = raw is List
          ? raw
          : (raw as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];
      setState(() {
        _amilList = list
            .map((j) => _Amil.fromJson(j as Map<String, dynamic>))
            .where((a) => a.id.isNotEmpty && a.name.isNotEmpty)
            .toList();
      });
    } catch (e) {
      debugPrint('ZakatTransactionScreen._fetchAmil error: $e');
    } finally {
      setState(() => _loadingAmil = false);
    }
  }

  Future<void> _fetchTitipUangRate() async {
    try {
      final api = ApiService();
      final resp = await api.getZakatConfigurationByModuleAndCode(
        'ZAKATFITRAH',
        'TITIP_UANG',
      );
      final raw = resp.data;
      final map = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
      final payload = map['data'] is Map<String, dynamic>
          ? map['data'] as Map<String, dynamic>
          : map;
      final value = payload['value']?.toString() ?? '';
      final parsed = double.tryParse(value);
      if (parsed != null && parsed > 0 && mounted) {
        setState(() => _titipUangRate = parsed);
      }
    } catch (e) {
      debugPrint('ZakatTransactionScreen._fetchTitipUangRate error: $e');
    }
  }

  Future<void> _fetchIkrarZakat() async {
    try {
      final api = ApiService();
      final resp = await api.getZakatConfigurationByModuleAndCode(
        'ZAKATFITRAH',
        'IKRAR_ZAKAT',
      );
      final raw = resp.data;
      final map = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
      final payload = map['data'] is Map<String, dynamic>
          ? map['data'] as Map<String, dynamic>
          : map;
      final value = payload['value']?.toString() ?? '';
      if (mounted) {
        setState(() {
          _ikrarZakat = value;
          _loadingIkrar = false;
        });
      }
    } catch (e) {
      debugPrint('ZakatTransactionScreen._fetchIkrarZakat error: $e');
      if (mounted) setState(() => _loadingIkrar = false);
    }
  }

  // ── Selection helpers ────────────────────────────────────────────────────
  void _toggleMember(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        _moneyIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleAll() {
    setState(() {
      if (_allSelected) {
        _selectedIds.clear();
        _moneyIds.clear();
      } else {
        _selectedIds.addAll(_familyMembers.map((m) => m.id));
      }
    });
  }

  void _toggleMoneyForMember(String id) {
    if (!_selectedIds.contains(id)) return;
    setState(() {
      if (_moneyIds.contains(id)) {
        _moneyIds.remove(id);
      } else {
        _moneyIds.add(id);
      }
    });
  }

  void _changeExternalSouls(int delta) {
    setState(() {
      final next = (_externalSouls + delta).clamp(0, 99);
      _externalSouls = next;
      if (_externalMoneySouls > _externalSouls) {
        _externalMoneySouls = _externalSouls;
      }
    });
  }

  void _changeExternalMoneySouls(int delta) {
    if (_type != _ZakatType.campuran) return;
    setState(() {
      final next = (_externalMoneySouls + delta).clamp(0, _externalSouls);
      _externalMoneySouls = next;
    });
  }

  // ── Submit ───────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_selectedIds.isEmpty) {
      _showSnack('Pilih minimal 1 muzakki sebagai perwakilan', isError: true);
      return;
    }

    if (_totalSouls <= 0) {
      _showSnack('Total jiwa harus lebih dari 0', isError: true);
      return;
    }

    final provider = context.read<ZakatProvider>();
    final selectedYear = provider.selectedYear;
    final yearId = selectedYear?.id ?? '';
    if (yearId.isEmpty) {
      _showSnack('Tidak ada tahun zakat yang dipilih', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final api = ApiService();
      final notes = _catatanCtrl.text.trim();
      final amilName = _selectedAmil?.name ?? '';
      final year = selectedYear?.hijriYear ?? 0;

      final registeredAllocations = _selectedIds.map((id) {
        final allocationType = _type == _ZakatType.campuran
            ? (_moneyIds.contains(id) ? 'money' : 'rice')
            : (_type == _ZakatType.uang ? 'money' : 'rice');
        return {
          'muzakki_id': id,
          'type': allocationType,
        };
      }).toList();

      final externalRiceSouls = _type == _ZakatType.uang
          ? 0
          : _type == _ZakatType.beras
              ? _externalSouls
              : _externalRiceSouls;
      final externalMoneySouls = _type == _ZakatType.uang
          ? _externalSouls
          : _type == _ZakatType.beras
              ? 0
              : _externalMoneySouls;

      final externalBreakdown = {
        'rice_souls': externalRiceSouls,
        'money_souls': externalMoneySouls,
        'notes': _externalSouls > 0 ? notes : '',
      };

      final paymentBreakdown = [
        {
          'type': 'rice',
          'souls': _riceJiwa,
          'quantity': _riceJiwa,
          'amount': '0',
        },
        {
          'type': 'money',
          'souls': _moneyJiwa,
          'quantity': 0,
          'amount': (_moneyJiwa * _riceRatePerSo).toStringAsFixed(0),
        },
      ];

      await api.createZakatTransactionBulk(
        yearId: yearId,
        year: year,
        amilName: amilName,
        notes: notes,
        registeredAllocations: registeredAllocations,
        externalBreakdown: externalBreakdown,
        paymentBreakdown: paymentBreakdown,
        totalSouls: _totalSouls,
        serahTerima:
            _selectedAmil != null && _serahTerimaMode != _SerahTerimaMode.none
                ? {
                    'mode': _serahTerimaMode == _SerahTerimaMode.akad
                        ? 'akad'
                        : 'titip',
                    'amil_name': _selectedAmil!.name,
                  }
                : null,
      );

      await provider.fetchMuzakki();

      if (mounted) {
        _showSnack('Transaksi berhasil disimpan!');
        context.go('/zakat-fitrah');
      }
    } catch (e) {
      if (mounted) _showSnack('Gagal menyimpan transaksi: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : _green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final members = _familyMembers;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/zakat-fitrah');
      },
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
            onPressed: () => context.go('/zakat-fitrah'),
          ),
        title: const Text(
          'Transaksi Zakat',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section 1: Pilih Anggota Keluarga ────────────────────────
            _buildFamilyHeader(members),
            const SizedBox(height: 8),
            _buildMemberList(members),
            const SizedBox(height: 20),

            // ── Section 2: Pilih Jenis Zakat ─────────────────────────────
            _sectionLabel('PILIH JENIS ZAKAT'),
            const SizedBox(height: 8),
            Consumer<ZakatProvider>(
              builder: (_, provider, __) => Row(
                children: [
                  Expanded(
                    child: _ZakatTypeCard(
                      icon: '🌾',
                      title: 'Beras',
                      subtitle: '$_totalSouls So\'',
                      isSelected: _type == _ZakatType.beras,
                      onTap: () => setState(() => _type = _ZakatType.beras),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ZakatTypeCard(
                      icon: '💵',
                      title: 'Uang Tunai',
                      subtitle:
                          'Rp ${_formatRp(provider.selectedYear?.riceRatePerSo ?? _titipUangRate)}/jiwa',
                      isSelected: _type == _ZakatType.uang,
                      onTap: () => setState(() => _type = _ZakatType.uang),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _ZakatTypeCard(
              icon: '⚖️',
              title: 'Campuran',
              subtitle: '$_riceJiwa beras • $_moneyJiwa uang',
              isSelected: _type == _ZakatType.campuran,
              onTap: () => setState(() => _type = _ZakatType.campuran),
            ),
            const SizedBox(height: 12),
            _buildExternalSoulsCard(),
            if (_type == _ZakatType.campuran) ...[
              const SizedBox(height: 12),
              _buildMixedAllocation(members),
            ],
            const SizedBox(height: 20),

            // ── Section 3: Total ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Pembayaran',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _type == _ZakatType.campuran
                            ? '$_riceJiwa beras • $_moneyJiwa uang'
                            : '$_totalSouls jiwa dihitung',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _totalSouls == 0
                          ? '—'
                          : _type == _ZakatType.beras
                              ? '$_totalSouls So\' Beras'
                              : _type == _ZakatType.uang
                                  ? 'Rp ${_formatRp(_totalUang)}'
                                  : _moneyJiwa == 0
                                      ? '$_totalSouls So\' Beras'
                                      : _riceJiwa == 0
                                          ? 'Rp ${_formatRp(_totalUang)}'
                                          : '$_riceJiwa So\' + Rp ${_formatRp(_totalUang)}',
                      key: ValueKey('$_type$_totalSouls$_moneyJiwa'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color:
                            _totalSouls == 0 ? const Color(0xFFCBD5E1) : _green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Section 4: Pilih Amil ─────────────────────────────────────
            _sectionLabel('PILIH AMIL'),
            const SizedBox(height: 8),
            _buildAmilSelector(),
            const SizedBox(height: 20),

            // ── Section 5: Serah Terima ───────────────────────────────────
            _sectionLabel('SERAH TERIMA (OPSIONAL)'),
            const SizedBox(height: 8),
            _buildSerahTerimaSection(),
            const SizedBox(height: 20),

            // ── Section 6: Catatan ────────────────────────────────────────
            _sectionLabel('CATATAN (OPSIONAL)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _catatanCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Contoh: Niat zakat untuk keluarga...',
                hintStyle:
                    const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
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
              ),
            ),
            const SizedBox(height: 12),

            // ── Ikrar Zakat ────────────────────────────────────────────────
            if (_loadingIkrar)
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 16,
                  height: 16,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: _green),
                ),
              )
            else if (_ikrarZakat.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.format_quote_rounded,
                            size: 16, color: _green),
                        const SizedBox(width: 6),
                        const Text(
                          'Ikrar Zakat',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _ikrarZakat,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF166534),
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 32),

            // ── Bayar Button ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed:
                    (_isSubmitting || _selectedIds.isEmpty) ? null : _submit,
                icon: _isSubmitting
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
                  _isSubmitting
                      ? 'Menyimpan…'
                      : _totalSouls == 0
                          ? 'Pilih Anggota'
                          : 'Bayar Zakat ($_totalSouls jiwa)',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _green.withOpacity(0.4),
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                  shadowColor: _green.withOpacity(0.4),
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

  Widget _buildExternalSoulsCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Jiwa Tanggungan Non-Terdaftar',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Gunakan untuk pembayaran mewakili anggota keluarga yang belum terdaftar.',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 10),
          _buildCounterRow(
            label: 'Total jiwa non-terdaftar',
            value: _externalSouls,
            onMinus: () => _changeExternalSouls(-1),
            onPlus: () => _changeExternalSouls(1),
          ),
          if (_type == _ZakatType.campuran) ...[
            const SizedBox(height: 8),
            _buildCounterRow(
              label: 'Dari total di atas, yang bayar uang',
              value: _externalMoneySouls,
              onMinus: () => _changeExternalMoneySouls(-1),
              onPlus: () => _changeExternalMoneySouls(1),
            ),
            const SizedBox(height: 4),
            Text(
              'Sisa $_externalRiceSouls jiwa akan dihitung sebagai beras',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCounterRow({
    required String label,
    required int value,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
        ),
        IconButton(
          onPressed: onMinus,
          icon: const Icon(Icons.remove_circle_outline),
          color: const Color(0xFF64748B),
          visualDensity: VisualDensity.compact,
        ),
        Container(
          width: 30,
          alignment: Alignment.center,
          child: Text(
            '$value',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
        IconButton(
          onPressed: onPlus,
          icon: const Icon(Icons.add_circle_outline),
          color: _green,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  // ── Family header row ────────────────────────────────────────────────────
  Widget _buildFamilyHeader(List<Muzakki> members) {
    final head = members.firstWhere(
      (m) => m.isHeadOfFamily,
      orElse: () => members.first,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('PILIH ANGGOTA KELUARGA'),
              const SizedBox(height: 2),
              Text(
                'Keluarga ${head.surname.isNotEmpty ? head.surname : head.fullName}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              if (_isEditMode) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: const Text(
                    'Mode Edit • Data lunas terpilih otomatis',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9A3412),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _toggleAll,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _allSelected ? _green : const Color(0xFFE8F5F0),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _green),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _allSelected
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 15,
                  color: _allSelected ? Colors.white : _green,
                ),
                const SizedBox(width: 5),
                Text(
                  _allSelected
                      ? 'Semua Dipilih'
                      : 'Pilih Semua (${members.length})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _allSelected ? Colors.white : _green,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Family members list ──────────────────────────────────────────────────
  Widget _buildMemberList(List<Muzakki> members) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: members.asMap().entries.map((entry) {
          final i = entry.key;
          final m = entry.value;
          final isSelected = _selectedIds.contains(m.id);
          final isMale = m.isMale;
          final isLast = i == members.length - 1;

          return Column(
            children: [
              InkWell(
                onTap: () => _toggleMember(m.id),
                borderRadius: BorderRadius.vertical(
                  top: i == 0 ? const Radius.circular(14) : Radius.zero,
                  bottom: isLast ? const Radius.circular(14) : Radius.zero,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFE8F5F0)
                        : Colors.transparent,
                    borderRadius: BorderRadius.vertical(
                      top: i == 0 ? const Radius.circular(14) : Radius.zero,
                      bottom: isLast ? const Radius.circular(14) : Radius.zero,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Checkbox
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: isSelected ? _green : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color:
                                isSelected ? _green : const Color(0xFFCBD5E1),
                            width: 1.5,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),

                      // Avatar
                      CircleAvatar(
                        radius: 16,
                        backgroundColor:
                            isMale ? _greenLight : const Color(0xFFFCE4EC),
                        child: Text(
                          m.initials,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isMale ? _green : const Color(0xFFC2185B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Name + relationship
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    m.fullName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (m.isHeadOfFamily) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.star_rounded,
                                      size: 13, color: Color(0xFFE65100)),
                                ],
                              ],
                            ),
                            if (m.relationship.isNotEmpty)
                              Text(
                                m.relationship,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Payment badge
                      if (m.isPaid)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '✓ Lunas',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                const Divider(height: 1, indent: 48, color: Color(0xFFEEF2F7)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMixedAllocation(List<Muzakki> members) {
    final selectedMembers =
        members.where((m) => _selectedIds.contains(m.id)).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilih anggota yang bayar uang',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Anggota yang tidak dipilih akan dibayar beras.',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 8),
          if (selectedMembers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Belum ada anggota dipilih.',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            )
          else
            ...selectedMembers.map(
              (m) {
                final isMoney = _moneyIds.contains(m.id);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    tileColor: const Color(0xFFF8FAFC),
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFFE8F5F0),
                      child: Text(
                        m.initials,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _green,
                        ),
                      ),
                    ),
                    title: Text(
                      m.fullName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      isMoney ? 'Uang Tunai' : 'Beras',
                      style: TextStyle(
                        fontSize: 11,
                        color: isMoney
                            ? const Color(0xFF1D4ED8)
                            : const Color(0xFF16A34A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: Switch(
                      value: isMoney,
                      activeColor: const Color(0xFF1D4ED8),
                      onChanged: (_) => _toggleMoneyForMember(m.id),
                    ),
                    onTap: () => _toggleMoneyForMember(m.id),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ── Serah Terima section ─────────────────────────────────────────────────
  Widget _buildSerahTerimaSection() {
    final hasAmil = _selectedAmil != null;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Option 1: Titip Zakat ────────────────────────────────────────
          _SerahTerimaOption(
            icon: Icons.handshake_outlined,
            title: 'Titip Zakat',
            subtitle: hasAmil && _serahTerimaMode == _SerahTerimaMode.titip
                ? 'Dititipkan ke ${_selectedAmil!.name}, belum ucap akad'
                : 'Zakat dititipkan ke amil, belum mengucapkan akad',
            isSelected: _serahTerimaMode == _SerahTerimaMode.titip,
            iconBg: const Color(0xFFFFF7ED),
            iconColor: const Color(0xFFD97706),
            onTap: () => setState(() {
              _serahTerimaMode = _serahTerimaMode == _SerahTerimaMode.titip
                  ? _SerahTerimaMode.none
                  : _SerahTerimaMode.titip;
            }),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // ── Option 2: Langsung Akad ke Amil ─────────────────────────────
          _SerahTerimaOption(
            icon: Icons.verified_outlined,
            title: 'Langsung Akad ke Amil',
            subtitle: hasAmil && _serahTerimaMode == _SerahTerimaMode.akad
                ? 'Akad zakat fitrah ke ${_selectedAmil!.name} ✓'
                : 'Serahkan zakat sambil ucap akad titip zakat fitrah',
            isSelected: _serahTerimaMode == _SerahTerimaMode.akad,
            iconBg: const Color(0xFFE8F5F0),
            iconColor: _green,
            onTap: () => setState(() {
              _serahTerimaMode = _serahTerimaMode == _SerahTerimaMode.akad
                  ? _SerahTerimaMode.none
                  : _SerahTerimaMode.akad;
            }),
          ),

          // ── Warning: amil belum dipilih ──────────────────────────────────
          if (_serahTerimaMode != _SerahTerimaMode.none && !hasAmil)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 14, color: Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Pilih nama amil di section "Pilih Amil" di atas agar tercatat.',
                      style: TextStyle(fontSize: 11, color: Color(0xFFD97706)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Amil selector ────────────────────────────────────────────────────────
  Widget _buildAmilSelector() {
    if (_loadingAmil) {
      return Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: _green),
        ),
      );
    }

    if (_amilList.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 18, color: Color(0xFFF59E0B)),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Tidak ada data amil',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            ),
            TextButton(
              onPressed: _fetchAmil,
              child: const Text('Coba lagi',
                  style: TextStyle(fontSize: 12, color: _green)),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _showAmilPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedAmil != null ? _green : const Color(0xFFE2E8F0),
            width: _selectedAmil != null ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.person_outline,
                size: 20,
                color:
                    _selectedAmil != null ? _green : const Color(0xFF94A3B8)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedAmil?.name ?? 'Pilih Nama Amil...',
                style: TextStyle(
                  fontSize: 14,
                  color: _selectedAmil != null
                      ? const Color(0xFF1A1A1A)
                      : const Color(0xFFCBD5E1),
                  fontWeight: _selectedAmil != null
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ),
            const Icon(Icons.expand_more, color: Color(0xFF94A3B8), size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _showAmilPicker() async {
    final picked = await showModalBottomSheet<_Amil>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        builder: (_, sc) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text('Pilih Nama Amil',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: sc,
                itemCount: _amilList.length,
                itemBuilder: (_, i) {
                  final a = _amilList[i];
                  final isSelected = _selectedAmil?.id == a.id;
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: _greenLight,
                      child: Text(
                        a.name.isNotEmpty ? a.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: _green, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(a.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: a.groupName.isNotEmpty ? Text(a.groupName) : null,
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: _green)
                        : null,
                    selected: isSelected,
                    onTap: () => Navigator.pop(ctx, a),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (picked != null) setState(() => _selectedAmil = picked);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF94A3B8),
          letterSpacing: 0.8,
        ),
      );

  String _formatRp(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)} jt';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)} rb';
    return v.toStringAsFixed(0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Zakat Type Card
// ─────────────────────────────────────────────────────────────────────────────
class _ZakatTypeCard extends StatelessWidget {
  const _ZakatTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  static const _green = Color(0xFF066046);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F5F0) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _green : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isSelected ? _green : const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
            if (isSelected)
              const Positioned(
                top: 0,
                right: 0,
                child:
                    Icon(Icons.check_circle_rounded, size: 20, color: _green),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Serah Terima Option Row
// ─────────────────────────────────────────────────────────────────────────────
class _SerahTerimaOption extends StatelessWidget {
  const _SerahTerimaOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback onTap;

  static const _green = Color(0xFF066046);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F5F0) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // Icon badge
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected ? iconBg : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? iconColor : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(width: 12),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFF1A1A1A)
                          : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            // Radio indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? _green : Colors.white,
                border: Border.all(
                  color: isSelected ? _green : const Color(0xFFCBD5E1),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.circle, size: 8, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

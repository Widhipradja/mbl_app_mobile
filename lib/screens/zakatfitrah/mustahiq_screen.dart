import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/zakat_provider.dart';
import '../../services/api_service.dart';

class MustahiqScreen extends StatefulWidget {
  const MustahiqScreen({super.key});

  @override
  State<MustahiqScreen> createState() => _MustahiqScreenState();
}

class _MustahiqScreenState extends State<MustahiqScreen> {
  static const _green = Color(0xFF066046);

  final ApiService _api = ApiService();

  bool _isLoading = false;
  bool _isSavingBobot = false;
  String? _error;
  String _lastObservedYearId = '';

  List<_AsnafBobot> _asnafBobot = const [];
  List<_MustahiqItem> _mustahiq = const [];
  String? _selectedAsnafType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  String? _pickYearIdFromProvider(ZakatProvider provider) {
    final selectedId = provider.selectedYear?.id;
    if (selectedId != null && selectedId.isNotEmpty) return selectedId;

    if (provider.years.isEmpty) return null;

    final active = provider.years.where((y) => y.isActive).toList();
    final fallback = active.isNotEmpty ? active.first : provider.years.first;
    return fallback.id;
  }

  Future<String?> _resolveYearId() async {
    final provider = context.read<ZakatProvider>();

    var yearId = _pickYearIdFromProvider(provider);
    if (yearId != null && yearId.isNotEmpty) {
      return yearId;
    }

    if (!provider.isLoadingYears) {
      await provider.fetchYears();
    }

    yearId = _pickYearIdFromProvider(provider);
    if (yearId != null && yearId.isNotEmpty) {
      final currentSelected = provider.selectedYear?.id;
      if (currentSelected == null || currentSelected.isEmpty) {
        final target = provider.years.firstWhere(
          (y) => y.id == yearId,
          orElse: () => provider.years.first,
        );
        await provider.selectYear(target);
      }
      return yearId;
    }

    return null;
  }

  Future<void> _bootstrap() async {
    final provider = context.read<ZakatProvider>();
    if (provider.years.isEmpty && !provider.isLoadingYears) {
      await provider.fetchYears();
    }
    await _loadData();
  }

  Future<void> _loadData() async {
    final yearId = await _resolveYearId();
    if (yearId == null || yearId.isEmpty) {
      setState(() {
        _error = 'Tahun zakat belum dipilih.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final baseResults = await Future.wait([
        _api.getZakatAsnafBobot(yearId: yearId),
        _api.getZakatMustahiq(yearId: yearId),
      ]);

      final asnafListFromCrud = _extractList(baseResults.first.data);
      final mustahiqList = _extractList(baseResults.last.data);

      final configuredTypes = asnafListFromCrud
          .map(
              (raw) => _normalizeAsnafType(raw['asnaf_type']?.toString() ?? ''))
          .where((type) => type.isNotEmpty)
          .toSet()
          .toList();

      final lookupResults = configuredTypes.isEmpty
          ? const <dynamic>[]
          : await Future.wait(
              configuredTypes.map(
                (asnafType) => _api.getZakatAsnafBobotLookup(
                  yearId: yearId,
                  asnafType: asnafType,
                ),
              ),
            );

      final asnafList = <Map<String, dynamic>>[];
      for (final item in lookupResults) {
        asnafList.addAll(_extractList(item.data));
      }

      final asnafByType = <String, _AsnafBobot>{};

      for (final raw in asnafListFromCrud) {
        final type = _normalizeAsnafType(raw['asnaf_type']?.toString() ?? '');
        if (type.isEmpty) continue;

        asnafByType[type] = _AsnafBobot(
          id: raw['id']?.toString() ?? raw['oid']?.toString() ?? '',
          yearId: raw['year_id']?.toString() ?? yearId,
          asnafType: type,
          bobot: _parseDouble(raw['bobot'], fallback: 1),
          notes: raw['notes']?.toString() ?? '',
        );
      }

      for (final raw in asnafList) {
        final type = _normalizeAsnafType(raw['asnaf_type']?.toString() ?? '');
        if (type.isEmpty) continue;

        final current = asnafByType[type];
        asnafByType[type] = _AsnafBobot(
          id: current?.id ?? '',
          yearId: current?.yearId ?? (raw['year_id']?.toString() ?? yearId),
          asnafType: type,
          bobot: _parseDouble(raw['bobot'], fallback: current?.bobot ?? 1),
          notes: current?.notes ?? (raw['notes']?.toString() ?? ''),
        );
      }

      final asnaf = asnafByType.values.toList()
        ..sort((a, b) => a.label.compareTo(b.label));

      final mustahiq = <_MustahiqItem>[];
      for (final raw in mustahiqList) {
        final id = raw['id']?.toString() ?? '';
        final name = (raw['name']?.toString() ?? '').trim();
        final type = _normalizeAsnafType(raw['asnaf_type']?.toString() ?? '');
        final souls = _parseInt(raw['souls'], fallback: 1);
        if (id.isEmpty || name.isEmpty || type.isEmpty) continue;

        final bobot = asnafByType[type]?.bobot ?? 1;
        mustahiq.add(
          _MustahiqItem(
            id: id,
            yearId: raw['year_id']?.toString() ?? yearId,
            name: name,
            asnafType: type,
            souls: souls,
            bobot: bobot,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _asnafBobot = asnaf;
        _mustahiq = mustahiq;
        final selectedStillValid = _selectedAsnafType != null &&
            asnaf.any((item) => item.asnafType == _selectedAsnafType);
        _selectedAsnafType = selectedStillValid
            ? _selectedAsnafType
            : (asnaf.isNotEmpty ? asnaf.first.asnafType : null);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat data mustahiq / asnaf & bobot.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _extractList(dynamic raw) {
    dynamic source = raw;
    if (raw is Map<String, dynamic> && raw['data'] != null) {
      source = raw['data'];
    }

    if (source is List) {
      return source.whereType<Map<String, dynamic>>().toList();
    }

    if (source is Map<String, dynamic>) {
      return [source];
    }

    return const [];
  }

  int _parseInt(dynamic raw, {required int fallback}) {
    final value = int.tryParse(raw?.toString() ?? '');
    return value ?? fallback;
  }

  double _parseDouble(dynamic raw, {required double fallback}) {
    final value = double.tryParse(raw?.toString() ?? '');
    return value ?? fallback;
  }

  String _normalizeAsnafType(String input) {
    return input.trim().toLowerCase();
  }

  ButtonStyle _primaryAddButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: _green,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Future<void> _addMustahiq({
    required String name,
    required int souls,
    required String asnafType,
  }) async {
    final yearId = await _resolveYearId();
    if (!mounted) return;

    if (yearId == null || yearId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tahun zakat belum dipilih.')),
      );
      return;
    }

    if (name.isEmpty || souls <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Isi nama, tipe asnaf, dan jumlah jiwa dengan benar.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _api.createZakatMustahiq(
        yearId: yearId,
        name: name,
        asnafType: asnafType,
        souls: souls,
      );

      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mustahiq berhasil ditambahkan.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menambah mustahiq.')),
      );
    }
  }

  Future<void> _openAddMustahiqDialog() async {
    if (_asnafBobot.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Tambahkan Asnaf & Bobot di Configuration terlebih dahulu.'),
        ),
      );
      return;
    }

    final nameCtrl = TextEditingController();
    final soulsCtrl = TextEditingController(text: '1');
    var asnafType = _selectedAsnafType ?? _asnafBobot.first.asnafType;

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Tambah Mustahiq'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Mustahiq'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: asnafType,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Asnaf Type'),
                items: _asnafBobot
                    .map(
                      (row) => DropdownMenuItem<String>(
                        value: row.asnafType,
                        child: Text(
                          '${row.label} (bobot ${row.bobot.toStringAsFixed(row.bobot.truncateToDouble() == row.bobot ? 0 : 2)})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setLocal(() {
                    asnafType = value;
                  });
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: soulsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Jiwa'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final souls = int.tryParse(soulsCtrl.text.trim()) ?? 0;
                if (name.isEmpty || souls <= 0) return;
                Navigator.pop(ctx, {
                  'name': name,
                  'souls': souls,
                  'asnaf_type': asnafType,
                });
              },
              style: _primaryAddButtonStyle(),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    nameCtrl.dispose();
    soulsCtrl.dispose();
    if (payload == null) return;

    await _addMustahiq(
      name: payload['name'] as String,
      souls: payload['souls'] as int,
      asnafType: payload['asnaf_type'] as String,
    );
  }

  Future<void> _showMustahiqActions(_MustahiqItem item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: _green),
              title: const Text('Edit Mustahiq'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
              title: const Text('Hapus Mustahiq'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (action == 'edit') {
      await _editMustahiq(item);
    } else if (action == 'delete') {
      await _deleteMustahiq(item.id);
    }
  }

  Future<void> _deleteMustahiq(String id) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _api.deleteZakatMustahiq(id);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mustahiq berhasil dihapus.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menghapus mustahiq.')),
      );
    }
  }

  Future<void> _editMustahiq(_MustahiqItem item) async {
    final yearId = await _resolveYearId();
    if (!mounted) return;
    if (yearId == null || yearId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tahun zakat belum dipilih.')),
      );
      return;
    }

    final nameCtrl = TextEditingController(text: item.name);
    final soulsCtrl = TextEditingController(text: item.souls.toString());
    var asnafType = item.asnafType;

    final updated = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Edit Mustahiq'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: asnafType,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Asnaf Type'),
                  items: _asnafBobot
                      .map(
                        (row) => DropdownMenuItem<String>(
                          value: row.asnafType,
                          child: Text(row.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setLocal(() {
                      asnafType = value;
                    });
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: soulsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Souls'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  final souls = int.tryParse(soulsCtrl.text.trim()) ?? 0;
                  if (name.isEmpty || souls <= 0) return;
                  Navigator.pop(ctx, {
                    'name': name,
                    'asnaf_type': asnafType,
                    'souls': souls,
                  });
                },
                style: _primaryAddButtonStyle(),
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );

    nameCtrl.dispose();
    soulsCtrl.dispose();
    if (updated == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _api.updateZakatMustahiq(item.id, {
        'year_id': yearId,
        'name': updated['name'],
        'asnaf_type': updated['asnaf_type'],
        'souls': updated['souls'],
      });
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mustahiq berhasil diperbarui.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memperbarui mustahiq.')),
      );
    }
  }

  Future<void> _editBobot(_AsnafBobot asnaf) async {
    final controller = TextEditingController(
      text: asnaf.bobot.toStringAsFixed(
          asnaf.bobot.truncateToDouble() == asnaf.bobot ? 0 : 2),
    );

    final nextBobot = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Bobot ${asnaf.label}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Bobot baru',
            hintText: 'Contoh: 2',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim());
              if (parsed == null || parsed < 0 || parsed > 100) return;
              Navigator.pop(ctx, parsed);
            },
            style: _primaryAddButtonStyle(),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (nextBobot == null) return;

    final yearId = await _resolveYearId();
    if (yearId == null || yearId.isEmpty) return;

    setState(() {
      _isSavingBobot = true;
    });

    try {
      final payload = {
        'year_id': yearId,
        'asnaf_type': asnaf.asnafType,
        'bobot': nextBobot,
        'notes': asnaf.notes,
      };

      if (asnaf.id.isEmpty) {
        await _api.createZakatAsnafBobot(payload);
      } else {
        await _api.updateZakatAsnafBobot(asnaf.id, payload);
      }

      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bobot ${asnaf.label} berhasil disimpan.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan bobot ${asnaf.label}.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingBobot = false;
        });
      }
    }
  }

  Future<void> _addAsnafBobot() async {
    final yearId = await _resolveYearId();
    if (!mounted) return;
    if (yearId == null || yearId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tahun zakat belum dipilih.')),
      );
      return;
    }

    var asnafTypeInput = '';
    var bobotInput = '1';
    var notesInput = '';

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Asnaf Bobot'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: asnafTypeInput,
              onChanged: (value) => asnafTypeInput = value,
              decoration: const InputDecoration(
                labelText: 'Asnaf Type',
                hintText: 'Contoh: fakir',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: bobotInput,
              onChanged: (value) => bobotInput = value,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Bobot'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: notesInput,
              onChanged: (value) => notesInput = value,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final asnafType = _normalizeAsnafType(asnafTypeInput.trim());
              final bobot = double.tryParse(bobotInput.trim());
              if (asnafType.isEmpty ||
                  bobot == null ||
                  bobot < 0 ||
                  bobot > 100) {
                return;
              }

              final alreadyExists = _asnafBobot.any(
                (item) => item.asnafType == asnafType && item.id.isNotEmpty,
              );
              if (alreadyExists) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Asnaf type sudah ada, gunakan edit bobot.'),
                  ),
                );
                return;
              }

              Navigator.pop(ctx, {
                'year_id': yearId,
                'asnaf_type': asnafType,
                'bobot': bobot,
                'notes': notesInput.trim(),
              });
            },
            style: _primaryAddButtonStyle(),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (payload == null) return;

    setState(() {
      _isSavingBobot = true;
    });

    try {
      await _api.createZakatAsnafBobot(payload);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asnaf bobot berhasil ditambahkan.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menambah asnaf bobot.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingBobot = false;
        });
      }
    }
  }

  Future<void> _deleteBobot(_AsnafBobot asnaf) async {
    if (asnaf.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Data bobot ini belum tersimpan di database.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Bobot Asnaf'),
        content: Text('Hapus bobot untuk ${asnaf.label}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isSavingBobot = true;
    });

    try {
      await _api.deleteZakatAsnafBobot(asnaf.id);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bobot asnaf berhasil dihapus.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menghapus bobot asnaf.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingBobot = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedYearId =
        context.watch<ZakatProvider>().selectedYear?.id ?? '';
    if (selectedYearId != _lastObservedYearId) {
      _lastObservedYearId = selectedYearId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadData();
      });
    }

    final totalSouls = _mustahiq.fold<int>(0, (sum, item) => sum + item.souls);
    final soulsByAsnaf = <String, int>{};
    for (final row in _mustahiq) {
      soulsByAsnaf[row.asnafType] =
          (soulsByAsnaf[row.asnafType] ?? 0) + row.souls;
    }

    return RefreshIndicator(
      color: _green,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pendataan Mustahiq',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Payload add: year_id, name, asnaf_type, souls',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
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
                    'Tambah data mustahiq melalui popup form.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  if (_asnafBobot.isEmpty) ...[
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Tambahkan Asnaf & Bobot di tabel bawah terlebih dahulu.',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: (_isLoading || _asnafBobot.isEmpty)
                          ? null
                          : _openAddMustahiqDialog,
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text(
                        'Tambah',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildMustahiqStats(
              totalSouls: totalSouls,
              soulsByAsnaf: soulsByAsnaf,
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: _green),
                ),
              )
            else
              _buildMustahiqTable(totalSouls: totalSouls),
            const SizedBox(height: 12),
            // _buildAsnafSummaryTable(_asnafBobot),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: Color(0xFFB45309)),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMustahiqStats({
    required int totalSouls,
    required Map<String, int> soulsByAsnaf,
  }) {
    final labelByType = {
      for (final item in _asnafBobot) item.asnafType: item.label,
    };

    final rows = soulsByAsnaf.entries.toList()
      ..sort((a, b) {
        final labelA = labelByType[a.key] ?? a.key;
        final labelB = labelByType[b.key] ?? b.key;
        return labelA.compareTo(labelB);
      });

    const asnafColors = [
      Color(0xFF1D4ED8),
      Color(0xFF16A34A),
      Color(0xFFD97706),
      Color(0xFF7E22CE),
    ];

    final topAsnafRows = rows.take(3).toList();
    final remainingAsnafCount = rows.length - topAsnafRows.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          _MustahiqStatCompactItem(
            value: '$totalSouls',
            label: 'Total Jiwa',
            color: _green,
          ),
          if (rows.isEmpty)
            const _MustahiqStatCompactItem(
              value: '-',
              label: 'Belum ada asnaf',
              color: Color(0xFF64748B),
            )
          else ...[
            ...topAsnafRows.asMap().entries.map(
              (entry) {
                final index = entry.key;
                final item = entry.value;
                return _MustahiqStatCompactItem(
                  value: '${item.value}',
                  label: labelByType[item.key] ?? item.key,
                  color: asnafColors[index % asnafColors.length],
                );
              },
            ),
            if (remainingAsnafCount > 0)
              _MustahiqStatCompactItem(
                value: '+$remainingAsnafCount',
                label: 'Asnaf Lain',
                color: const Color(0xFF64748B),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildMustahiqTable({required int totalSouls}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: _mustahiq.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Belum ada data mustahiq',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 46,
                columns: const [
                  DataColumn(label: Text('Nama')),
                  DataColumn(label: Text('Asnaf')),
                  DataColumn(numeric: true, label: Text('Jiwa')),
                ],
                rows: [
                  ..._mustahiq.map(
                    (item) => DataRow(
                      onLongPress: () => _showMustahiqActions(item),
                      cells: [
                        DataCell(Text(item.name)),
                        DataCell(Text(item.asnafType)),
                        DataCell(Text('${item.souls}')),
                      ],
                    ),
                  ),
                  DataRow(
                    color: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                    cells: [
                      const DataCell(
                        Text(
                          'TOTAL',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const DataCell(SizedBox.shrink()),
                      DataCell(
                        Text(
                          '$totalSouls',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAsnafSummaryTable(List<_AsnafBobot> asnafRows) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                'Asnaf & Bobot',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Penambahan Asnaf dilakukan di tab Configuration.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 36,
              dataRowMinHeight: 38,
              dataRowMaxHeight: 44,
              columns: const [
                DataColumn(label: Text('Asnaf')),
                DataColumn(numeric: true, label: Text('Bobot')),
                DataColumn(label: Text('Aksi')),
              ],
              rows: asnafRows
                  .map(
                    (asnaf) => DataRow(
                      cells: [
                        DataCell(Text(asnaf.label)),
                        DataCell(Text(asnaf.bobot.toStringAsFixed(
                            asnaf.bobot.truncateToDouble() == asnaf.bobot
                                ? 0
                                : 2))),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: _isSavingBobot
                                    ? null
                                    : () => _editBobot(asnaf),
                                icon: _isSavingBobot
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                        color: Color(0xFF066046),
                                      ),
                                tooltip: 'Edit bobot',
                              ),
                              IconButton(
                                onPressed: _isSavingBobot
                                    ? null
                                    : () => _deleteBobot(asnaf),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Color(0xFFDC2626),
                                ),
                                tooltip: 'Hapus bobot',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MustahiqStatCompactItem extends StatelessWidget {
  const _MustahiqStatCompactItem({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef MustahiqBody = MustahiqScreen;

class _AsnafBobot {
  const _AsnafBobot({
    required this.id,
    required this.yearId,
    required this.asnafType,
    required this.bobot,
    required this.notes,
  });

  final String id;
  final String yearId;
  final String asnafType;
  final double bobot;
  final String notes;

  String get label {
    return asnafType
        .split('_')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

class _MustahiqItem {
  const _MustahiqItem({
    required this.id,
    required this.yearId,
    required this.name,
    required this.asnafType,
    required this.souls,
    required this.bobot,
  });

  final String id;
  final String yearId;
  final String name;
  final String asnafType;
  final int souls;
  final double bobot;

  double get calculatedSo => bobot * souls;
}

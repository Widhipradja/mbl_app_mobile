import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_configuration.dart';
import '../../providers/zakat_provider.dart';
import '../../providers/configuration_provider.dart';
import '../../services/api_service.dart';

class ConfigurationScreen extends StatefulWidget {
  const ConfigurationScreen({super.key});

  @override
  State<ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<ConfigurationScreen> {
  static const _green = Color(0xFF066046);

  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoadingAsnaf = false;
  String? _asnafError;
  String _lastObservedYearId = '';
  List<_AsnafBobotItem> _asnafBobot = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ConfigurationProvider>();
      if (provider.configurations.isEmpty && !provider.isLoading) {
        provider.fetchConfigurations(
          module: ConfigurationProvider.moduleZakatFitrah,
        );
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
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

  Future<void> _loadAsnafBobot() async {
    final yearId = _pickYearIdFromProvider(context.read<ZakatProvider>());
    if (yearId == null || yearId.isEmpty) {
      setState(() {
        _asnafBobot = const [];
        _asnafError = 'Tahun zakat belum dipilih.';
      });
      return;
    }

    setState(() {
      _isLoadingAsnaf = true;
      _asnafError = null;
    });

    try {
      final response = await _api.getZakatAsnafBobot(yearId: yearId);
      final rows = _extractList(response.data)
          .map(
            (raw) => _AsnafBobotItem(
              id: raw['id']?.toString() ?? raw['oid']?.toString() ?? '',
              yearId: raw['year_id']?.toString() ?? yearId,
              asnafType:
                  _normalizeAsnafType(raw['asnaf_type']?.toString() ?? ''),
              bobot: _parseDouble(raw['bobot'], fallback: 1),
              notes: raw['notes']?.toString() ?? '',
            ),
          )
          .where((item) => item.id.isNotEmpty && item.asnafType.isNotEmpty)
          .toList()
        ..sort((a, b) => a.label.compareTo(b.label));

      if (!mounted) return;
      setState(() {
        _asnafBobot = rows;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _asnafError = 'Gagal memuat data Asnaf & Bobot.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAsnaf = false;
        });
      }
    }
  }

  Future<void> _openConfigDialog({AppConfiguration? initial}) async {
    final provider = context.read<ConfigurationProvider>();
    final codeCtrl = TextEditingController(text: initial?.code ?? '');
    final descCtrl = TextEditingController(text: initial?.description ?? '');
    final valueCtrl = TextEditingController(text: initial?.value ?? '');
    final dataTypeCtrl =
        TextEditingController(text: initial?.dataType ?? 'string');
    bool isActive = initial?.isActive ?? true;

    final isEdit = initial != null;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              title:
                  Text(isEdit ? 'Edit Configuration' : 'Tambah Configuration'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Text(
                        'Module: ZAKATFITRAH',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _InputField(label: 'Code', controller: codeCtrl),
                    const SizedBox(height: 8),
                    _InputField(label: 'Description', controller: descCtrl),
                    const SizedBox(height: 8),
                    _InputField(label: 'Value', controller: valueCtrl),
                    const SizedBox(height: 8),
                    _InputField(label: 'Data Type', controller: dataTypeCtrl),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: isActive,
                      activeColor: _green,
                      onChanged: (v) => setLocal(() => isActive = v),
                      title: const Text('Is Active'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (codeCtrl.text.trim().isEmpty ||
                        dataTypeCtrl.text.trim().isEmpty) {
                      return;
                    }

                    final payload = AppConfiguration(
                      oid: initial?.oid ?? '',
                      module: ConfigurationProvider.moduleZakatFitrah,
                      code: codeCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      value: valueCtrl.text,
                      dataType: dataTypeCtrl.text.trim(),
                      isActive: isActive,
                    );

                    final ok = isEdit
                        ? await provider.updateConfiguration(payload)
                        : await provider.createConfiguration(payload);
                    if (ctx.mounted) Navigator.pop(ctx, ok);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isEdit ? 'Simpan' : 'Tambah'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? 'Configuration berhasil diubah'
                : 'Configuration berhasil ditambah',
          ),
          backgroundColor: _green,
        ),
      );
    }
  }

  Future<void> _openAsnafDialog({_AsnafBobotItem? initial}) async {
    final yearId = _pickYearIdFromProvider(context.read<ZakatProvider>());
    if (yearId == null || yearId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tahun zakat belum dipilih.')),
      );
      return;
    }

    final isEdit = initial != null;
    var asnafType = initial?.asnafType ?? '';
    var bobotText = (initial?.bobot ?? 1)
        .toStringAsFixed(((initial?.bobot ?? 1) % 1 == 0) ? 0 : 2);
    var notes = initial?.notes ?? '';

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit Asnaf & Bobot' : 'Tambah Asnaf & Bobot'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: asnafType,
              enabled: !isEdit,
              onChanged: (value) => asnafType = value,
              decoration: const InputDecoration(
                labelText: 'Asnaf Type',
                hintText: 'Contoh: fakir',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: bobotText,
              onChanged: (value) => bobotText = value,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Bobot'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: notes,
              onChanged: (value) => notes = value,
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
              final normalizedType = _normalizeAsnafType(asnafType);
              final bobot = double.tryParse(bobotText.trim());
              if (normalizedType.isEmpty ||
                  bobot == null ||
                  bobot < 0 ||
                  bobot > 100) {
                return;
              }

              final exists = _asnafBobot.any(
                (row) =>
                    row.asnafType == normalizedType && row.id != initial?.id,
              );
              if (exists) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Asnaf type sudah ada.')),
                );
                return;
              }

              Navigator.pop(ctx, {
                'year_id': yearId,
                'asnaf_type': normalizedType,
                'bobot': bobot,
                'notes': notes.trim(),
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
            ),
            child: Text(isEdit ? 'Simpan' : 'Tambah'),
          ),
        ],
      ),
    );

    if (payload == null) return;

    try {
      if (isEdit) {
        await _api.updateZakatAsnafBobot(initial.id, payload);
      } else {
        await _api.createZakatAsnafBobot(payload);
      }
      await _loadAsnafBobot();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? 'Asnaf & Bobot berhasil diubah'
                : 'Asnaf & Bobot berhasil ditambah',
          ),
          backgroundColor: _green,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan Asnaf & Bobot.')),
      );
    }
  }

  Future<bool> _confirmDelete(AppConfiguration item) async {
    final provider = context.read<ConfigurationProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Configuration'),
        content: Text('Hapus ${item.module}.${item.code}?'),
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

    if (ok != true) return false;

    final deleted = await provider.deleteConfiguration(item.oid);
    if (mounted && deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuration berhasil dihapus')),
      );
    }
    return deleted;
  }

  Future<bool> _confirmDeleteAsnaf(_AsnafBobotItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Asnaf & Bobot'),
        content: Text('Hapus ${item.label}?'),
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

    if (ok != true) return false;

    try {
      await _api.deleteZakatAsnafBobot(item.id);
      await _loadAsnafBobot();
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asnaf & Bobot berhasil dihapus')),
      );
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menghapus Asnaf & Bobot.')),
      );
      return false;
    }
  }

  List<Map<String, dynamic>> _extractList(dynamic raw) {
    dynamic source = raw;
    if (raw is Map<String, dynamic> && raw['data'] != null) {
      source = raw['data'];
    }

    if (source is List)
      return source.whereType<Map<String, dynamic>>().toList();
    if (source is Map<String, dynamic>) return [source];
    return const [];
  }

  double _parseDouble(dynamic raw, {required double fallback}) {
    final parsed = double.tryParse(raw?.toString() ?? '');
    return parsed ?? fallback;
  }

  String _normalizeAsnafType(String value) => value.trim().toLowerCase();

  Widget _swipeBackground({
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: alignment,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: alignment == Alignment.centerLeft
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          if (alignment == Alignment.centerRight)
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Icon(icon, color: Colors.white, size: 18),
          if (alignment == Alignment.centerLeft) const SizedBox(width: 8),
          if (alignment == Alignment.centerLeft)
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _sectionBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5F0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF066046),
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConfigurationProvider>(
      builder: (context, provider, _) {
        final selectedYearId =
            context.watch<ZakatProvider>().selectedYear?.id ?? '';
        if (selectedYearId != _lastObservedYearId) {
          _lastObservedYearId = selectedYearId;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _loadAsnafBobot();
          });
        }

        final query = _searchQuery.toLowerCase();
        final items = provider.configurations.where((c) {
          if (query.isEmpty) return true;
          return c.module.toLowerCase().contains(query) ||
              c.code.toLowerCase().contains(query) ||
              c.description.toLowerCase().contains(query) ||
              c.value.toLowerCase().contains(query);
        }).toList();

        return RefreshIndicator(
          color: _green,
          onRefresh: () => provider.fetchConfigurations(
              module: ConfigurationProvider.moduleZakatFitrah),
          child: Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionBadge('MASTER ASNAF & BOBOT'),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Asnaf & Bobot',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _openAsnafDialog,
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Tambah Asnaf'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _green,
                                  foregroundColor: Colors.white,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Swipe kanan untuk Edit, swipe kiri untuk Hapus.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (_isLoadingAsnaf)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            )
                          else if (_asnafBobot.isEmpty)
                            const Text(
                              'Belum ada data Asnaf & Bobot',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                              ),
                            )
                          else
                            Column(
                              children: _asnafBobot.map((item) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Dismissible(
                                    key: ValueKey('asnaf-${item.id}'),
                                    background: _swipeBackground(
                                      alignment: Alignment.centerLeft,
                                      color: const Color(0xFF059669),
                                      icon: Icons.edit_outlined,
                                      label: 'Edit',
                                    ),
                                    secondaryBackground: _swipeBackground(
                                      alignment: Alignment.centerRight,
                                      color: const Color(0xFFDC2626),
                                      icon: Icons.delete_outline,
                                      label: 'Hapus',
                                    ),
                                    confirmDismiss: (direction) async {
                                      if (direction ==
                                          DismissDirection.startToEnd) {
                                        await _openAsnafDialog(initial: item);
                                        return false;
                                      }
                                      return _confirmDeleteAsnaf(item);
                                    },
                                    child: _AsnafBobotTile(item: item),
                                  ),
                                );
                              }).toList(),
                            ),
                          if (_asnafError != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              _asnafError!,
                              style: const TextStyle(
                                color: Color(0xFFDC2626),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionBadge('MODULE CONFIGURATION'),
                          const SizedBox(height: 6),
                          const Text(
                            'Configuration ZAKATFITRAH',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Swipe kanan untuk Edit, swipe kiri untuk Hapus.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (v) =>
                                      setState(() => _searchQuery = v),
                                  decoration: InputDecoration(
                                    hintText: 'Cari module, code, value…',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 10,
                                    ),
                                    prefixIcon: const Icon(Icons.search),
                                    filled: true,
                                    fillColor: const Color(0xFFF4F7F6),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: () => _openConfigDialog(),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Tambah'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _green,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 48),
                                ),
                              ),
                            ],
                          ),
                          if (provider.errorMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              provider.errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFDC2626),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: provider.isLoading
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 140),
                          Center(
                            child: CircularProgressIndicator(color: _green),
                          ),
                        ],
                      )
                    : items.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 140),
                              Center(
                                child: Text(
                                  'Belum ada data configuration',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 84),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return Dismissible(
                                key: ValueKey('cfg-${item.oid}'),
                                background: _swipeBackground(
                                  alignment: Alignment.centerLeft,
                                  color: const Color(0xFF059669),
                                  icon: Icons.edit_outlined,
                                  label: 'Edit',
                                ),
                                secondaryBackground: _swipeBackground(
                                  alignment: Alignment.centerRight,
                                  color: const Color(0xFFDC2626),
                                  icon: Icons.delete_outline,
                                  label: 'Hapus',
                                ),
                                confirmDismiss: (direction) async {
                                  if (direction ==
                                      DismissDirection.startToEnd) {
                                    await _openConfigDialog(initial: item);
                                    return false;
                                  }
                                  return _confirmDelete(item);
                                },
                                child: _ConfigurationTile(item: item),
                              );
                            },
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 6),
                            itemCount: items.length,
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

typedef ConfigurationBody = ConfigurationScreen;

class _ConfigurationTile extends StatelessWidget {
  const _ConfigurationTile({required this.item});

  final AppConfiguration item;

  @override
  Widget build(BuildContext context) {
    final activeColor =
        item.isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        title: Text(
          item.code,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.description.isNotEmpty)
                Text(
                  item.description,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 4),
              Text(
                'Value: ${item.value.isEmpty ? '-' : item.value}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Type: ${item.dataType}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: activeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item.isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                  color: activeColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AsnafBobotTile extends StatelessWidget {
  const _AsnafBobotTile({required this.item});

  final _AsnafBobotItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                if (item.notes.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.notes,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Bobot ${item.bobot.toStringAsFixed(item.bobot % 1 == 0 ? 0 : 2)}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _AsnafBobotItem {
  const _AsnafBobotItem({
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

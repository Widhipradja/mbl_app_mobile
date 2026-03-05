import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/zakat_distribution.dart';
import '../../providers/zakat_provider.dart';
import '../../services/api_service.dart';

/// A self-contained section widget for managing Zakat Fitrah Distribution
/// configuration. Intended to be embedded in [ConfigurationScreen].
class DistributionConfigSection extends StatefulWidget {
  const DistributionConfigSection({super.key});

  @override
  State<DistributionConfigSection> createState() =>
      DistributionConfigSectionState();
}

class DistributionConfigSectionState
    extends State<DistributionConfigSection> {
  static const _green = Color(0xFF066046);

  final ApiService _api = ApiService();

  bool _isLoading = false;
  String? _error;
  String _lastYearId = '';
  List<ZakatDistribution> _roots = const [];

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final yearId = _currentYearId;
    if (yearId != _lastYearId) {
      _lastYearId = yearId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get _currentYearId =>
      context.read<ZakatProvider>().selectedYear?.id ?? '';

  List<Map<String, dynamic>> _extractList(dynamic raw) {
    dynamic source = raw;
    if (raw is Map<String, dynamic> && raw['data'] != null) {
      source = raw['data'];
    }
    if (source is List) {
      return source.whereType<Map<String, dynamic>>().toList();
    }
    if (source is Map<String, dynamic>) return [source];
    return const [];
  }

  /// Returns a flat list of all distribution nodes (all depths) for
  /// use as dropdown options when choosing a parent.
  List<ZakatDistribution> get _allNodes {
    final flat = <ZakatDistribution>[];
    for (final r in _roots) {
      flat.addAll(r.flatten());
    }
    return flat;
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  /// Called externally (e.g. parent pull-to-refresh) to force reload.
  Future<void> reload() => _load();

  Future<void> _load() async {
    final yearId = _currentYearId;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response =
          await _api.getZakatDistributions(yearId: yearId.isEmpty ? null : yearId);
      final rows = _extractList(response.data)
          .map(ZakatDistribution.fromJson)
          .toList();

      if (!mounted) return;
      setState(() => _roots = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Gagal memuat data distribusi.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Create / Edit dialog ──────────────────────────────────────────────────

  Future<void> _openDialog({
    ZakatDistribution? initial,
    String? presetParentId,
    String? presetParentName,
  }) async {
    final yearId = _currentYearId;
    if (yearId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tahun zakat belum dipilih.')),
      );
      return;
    }

    final isEdit = initial != null;
    final nameCtrl = TextEditingController(text: initial?.name ?? '');
    final pctCtrl = TextEditingController(
      text: initial != null
          ? (initial.percentage % 1 == 0
              ? initial.percentage.toStringAsFixed(0)
              : initial.percentage.toStringAsFixed(2))
          : '',
    );
    final notesCtrl = TextEditingController(text: initial?.notes ?? '');
    String? parentId = isEdit ? initial.parentId : presetParentId;

    final allNodes = _allNodes;
    final available = allNodes
        .where((n) => isEdit ? n.id != initial.id : true)
        .toList();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              title: Text(isEdit ? 'Edit Distribusi' : 'Tambah Distribusi'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Parent selector
                    DropdownButtonFormField<String?>(
                      value: parentId,
                      decoration: InputDecoration(
                        labelText: 'Parent (opsional)',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('— Root (tanpa parent) —'),
                        ),
                        ...available.map(
                          (n) => DropdownMenuItem<String?>(
                            value: n.id,
                            child: Text(
                              n.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: isEdit
                          ? null
                          : (v) => setLocal(() => parentId = v),
                    ),
                    const SizedBox(height: 10),
                    _InputField(label: 'Nama *', controller: nameCtrl),
                    const SizedBox(height: 10),
                    _InputField(
                      label: 'Persentase (0–100) *',
                      controller: pctCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                    ),
                    const SizedBox(height: 10),
                    _InputField(
                      label: 'Catatan',
                      controller: notesCtrl,
                      maxLines: 2,
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final pct = double.tryParse(pctCtrl.text.trim());
                    if (name.isEmpty || pct == null || pct < 0 || pct > 100) {
                      return;
                    }

                    final payload = <String, dynamic>{
                      'year_id': yearId,
                      'name': name,
                      'percentage': pct,
                      'notes': notesCtrl.text.trim(),
                      if (parentId != null) 'parent_id': parentId,
                    };

                    try {
                      if (isEdit) {
                        await ApiService().updateZakatDistribution(
                            initial.id, payload);
                      } else {
                        await ApiService().createZakatDistribution(payload);
                      }
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (_) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Gagal menyimpan distribusi.'),
                          ),
                        );
                      }
                    }
                  },
                  child: Text(isEdit ? 'Simpan' : 'Tambah'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true && mounted) {
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? 'Distribusi berhasil diperbarui'
                : 'Distribusi berhasil ditambah',
          ),
          backgroundColor: _green,
        ),
      );
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _delete(ZakatDistribution item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Distribusi'),
        content: Text(
            'Hapus "${item.name}"? Seluruh data turunannya juga akan terhapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _api.deleteZakatDistribution(item.id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Distribusi berhasil dihapus')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menghapus distribusi.')),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Observe year changes
    context.watch<ZakatProvider>().selectedYear;

    return Container(
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
          // ── Header ──────────────────────────────────────────────────────
          _SectionBadge(label: 'DISTRIBUSI ZAKAT FITRAH'),
          const SizedBox(height: 6),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Konfigurasi Distribusi',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Tambah Root'),
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
            'Tap ikon pensil untuk edit, ikon hapus untuk hapus, atau "+" untuk tambah child.',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),

          // ── Content ──────────────────────────────────────────────────────
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_error != null)
            Text(
              _error!,
              style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
            )
          else if (_roots.isEmpty)
            const Text(
              'Belum ada data distribusi.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            )
          else
            Column(
              children: _roots
                  .map((node) => _DistributionNodeTile(
                        node: node,
                        depth: 0,
                        onEdit: (n) => _openDialog(initial: n),
                        onAddChild: (n) => _openDialog(
                          presetParentId: n.id,
                          presetParentName: n.name,
                        ),
                        onDelete: _delete,
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

// ── Recursive tile ─────────────────────────────────────────────────────────────

class _DistributionNodeTile extends StatelessWidget {
  const _DistributionNodeTile({
    required this.node,
    required this.depth,
    required this.onEdit,
    required this.onAddChild,
    required this.onDelete,
  });

  final ZakatDistribution node;
  final int depth;
  final void Function(ZakatDistribution) onEdit;
  final void Function(ZakatDistribution) onAddChild;
  final void Function(ZakatDistribution) onDelete;

  static const _green = Color(0xFF066046);

  @override
  Widget build(BuildContext context) {
    final indentOffset = depth * 14.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Node row
        Padding(
          padding: EdgeInsets.only(left: indentOffset, bottom: 4),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: depth == 0
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                // Depth indicator stripe
                if (depth > 0)
                  Container(
                    width: 4,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _green.withOpacity(0.3 + depth * 0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(10),
                        bottomLeft: Radius.circular(10),
                      ),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          node.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: depth == 0 ? 13 : 12,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            _PctBadge(value: node.percentage),
                            if (node.notes.trim().isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  node.notes,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Actions
                _ActionButtons(
                  onEdit: () => onEdit(node),
                  onAddChild: () => onAddChild(node),
                  onDelete: () => onDelete(node),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
        // Children
        if (node.children.isNotEmpty)
          ...node.children.map(
            (child) => _DistributionNodeTile(
              node: child,
              depth: depth + 1,
              onEdit: onEdit,
              onAddChild: onAddChild,
              onDelete: onDelete,
            ),
          ),
      ],
    );
  }
}

// ── Small sub-widgets ──────────────────────────────────────────────────────────

class _PctBadge extends StatelessWidget {
  const _PctBadge({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2)}%',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF166534),
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.onEdit,
    required this.onAddChild,
    required this.onDelete,
  });

  final VoidCallback onEdit;
  final VoidCallback onAddChild;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _IconBtn(icon: Icons.add_circle_outline, color: const Color(0xFF059669), onTap: onAddChild, tooltip: 'Tambah child'),
        _IconBtn(icon: Icons.edit_outlined, color: const Color(0xFF0EA5E9), onTap: onEdit, tooltip: 'Edit'),
        _IconBtn(icon: Icons.delete_outline, color: const Color(0xFFDC2626), onTap: onDelete, tooltip: 'Hapus'),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class _SectionBadge extends StatelessWidget {
  const _SectionBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
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
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

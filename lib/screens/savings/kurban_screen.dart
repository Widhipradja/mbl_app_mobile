import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import '../../models/savings_ledgers.dart';
import '../../services/api_service.dart';
import '../launcher/launcher_models.dart' show monthsShort, rupiah;
import 'ledger_widgets.dart';

/// Item code of kurban in the shodaqoh service.
const _kurbanItemCode = 'K-07';

/// Tabungan Kurban of the logged-in member: the whole family for a head of
/// family (KK), only themself otherwise.
class KurbanScreen extends StatefulWidget {
  const KurbanScreen({super.key});

  @override
  State<KurbanScreen> createState() => _KurbanScreenState();
}

class _KurbanScreenState extends State<KurbanScreen> {
  bool _loading = true;
  String? _error;
  QurbanSavings? _data;
  CollectionSummary? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = ApiService();
    try {
      final resp = await api.getQurbanSavings();
      if (!mounted) return;
      setState(() => _data = QurbanSavings.parse(resp.data));
    } catch (e) {
      if (!mounted) return;
      debugPrint('KurbanScreen error: $e');
      setState(() {
        _data = null;
        _summary = null;
        _error = ledgerFailure(e);
        _loading = false;
      });
      return;
    }

    // The target card is extra: its failure never hides the savings.
    CollectionSummary? summary;
    try {
      final resp = await api.getFamilyCollectionSummary(_kurbanItemCode);
      summary = CollectionSummary.parse(resp.data);
    } catch (e) {
      debugPrint('KurbanScreen summary error: $e');
    }
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final family = d?.scope.family ?? false;

    return LedgerPage(
      title: 'Tabungan Kurban',
      onRefresh: _load,
      loading: _loading,
      error: _error,
      emptyText: 'Belum ada siklus tabungan kurban yang berjalan.',
      children: [
        // No running cycle: the empty text above is shown.
        if (d != null && d.hasCycle) ...[
          LedgerTotalCard(
            label: d.cycleName.isEmpty
                ? 'Total tabungan'
                : 'Total tabungan · ${d.cycleName}',
            total: rupiah(d.total),
            caption: family
                ? '${d.members.length} anggota keluarga'
                : 'Tabungan Anda',
            emoji: '🐐',
          ),
          if (_summary != null && _summary!.hasData)
            _TargetCard(summary: _summary!),
          for (final m in d.members)
            KurbanMemberCard(
              key: ValueKey(m.name),
              name: m.name,
              badge: family && m.isHead ? 'Kepala keluarga' : '',
              total: m.total,
              months: d.months,
              amountOf: m.paid,
            ),
          // Everyone together, per month.
          if (family && d.members.length > 1)
            KurbanMemberCard(
              name: 'Total per bulan',
              badge: '',
              total: d.total,
              months: d.months,
              amountOf: (k) => d.byMonth[k] ?? 0,
              highlight: true,
            ),
        ],
      ],
    );
  }
}

/// Collected against target for the kurban item.
class _TargetCard extends StatelessWidget {
  const _TargetCard({required this.summary});

  final CollectionSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return Container(
      margin: const EdgeInsets.only(bottom: Lx.s12),
      padding: const EdgeInsets.all(Lx.s12),
      decoration: Lx.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                  child: Text('Target kurban', style: Lx.moduleLabel)),
              if (s.target > 0)
                Text('${(s.progress * 100).round()}%',
                    style: Lx.moduleLabel.copyWith(color: Lx.primary)),
            ],
          ),
          if (s.target > 0) ...[
            const SizedBox(height: Lx.s8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: s.progress,
                minHeight: 7,
                backgroundColor: Lx.primaryLight,
                valueColor: const AlwaysStoppedAnimation(Lx.primary),
                semanticsLabel: 'Tabungan terhadap target',
                semanticsValue: '${(s.progress * 100).round()}%',
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            s.target > 0
                ? '${rupiah(s.collected)} dari ${rupiah(s.target)}'
                : 'Terkumpul ${rupiah(s.collected)}',
            style: Lx.metadata,
          ),
        ],
      ),
    );
  }
}

/// One person's savings (or the family total): name and total, with the
/// months of the cycle folded under a tap.
class KurbanMemberCard extends StatefulWidget {
  const KurbanMemberCard({
    super.key,
    required this.name,
    required this.badge,
    required this.total,
    required this.months,
    required this.amountOf,
    this.highlight = false,
  });

  final String name;

  /// Small tag beside the name, e.g. "Kepala keluarga"; empty for none.
  final String badge;
  final double total;
  final List<CycleMonth> months;

  /// Amount saved for a month key.
  final double Function(String monthKey) amountOf;
  final bool highlight;

  @override
  State<KurbanMemberCard> createState() => _KurbanMemberCardState();
}

class _KurbanMemberCardState extends State<KurbanMemberCard> {
  bool _open = false;

  int get _filled =>
      widget.months.where((m) => widget.amountOf(m.key) > 0).length;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return Padding(
      padding: const EdgeInsets.only(bottom: Lx.s8),
      child: Semantics(
        button: true,
        expanded: _open,
        label: '${w.name}, total ${rupiah(w.total)}',
        child: Material(
          color: w.highlight ? Lx.primaryLight : Lx.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Lx.rCard),
            side:
                BorderSide(color: w.highlight ? Colors.transparent : Lx.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap:
                w.months.isEmpty ? null : () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.all(Lx.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(w.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Lx.cardHeading),
                            if (w.badge.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(w.badge,
                                    style: Lx.metadata
                                        .copyWith(color: Lx.secondary)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Lx.s8),
                      Text(rupiah(w.total),
                          style: Lx.cardHeading.copyWith(color: Lx.primary)),
                      if (w.months.isNotEmpty)
                        Icon(
                          _open
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: Lx.textSecondary,
                        ),
                    ],
                  ),
                  if (w.months.isNotEmpty) ...[
                    const SizedBox(height: Lx.s8),
                    _dots(),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 180),
                      crossFadeState: _open
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: const SizedBox(width: double.infinity),
                      secondChild: _grid(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// One dot per month, filled where something was paid, and a count.
  Widget _dots() {
    final months = widget.months;
    return Row(
      children: [
        Flexible(
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final m in months)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.amountOf(m.key) > 0
                        ? Lx.primary
                        : (widget.highlight ? Colors.white : Lx.border),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: Lx.s8),
        Text('$_filled/${months.length} bulan', style: Lx.metadata),
      ],
    );
  }

  Widget _grid() {
    final months = widget.months;
    return Padding(
      padding: const EdgeInsets.only(top: Lx.s12),
      child: Column(
        children: [
          for (var i = 0; i < months.length; i += 3)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : Lx.s8),
              child: Row(
                children: [
                  for (var c = 0; c < 3; c++) ...[
                    if (c > 0) const SizedBox(width: Lx.s8),
                    Expanded(
                      child: i + c < months.length
                          ? _cell(months[i + c])
                          : const SizedBox(),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _cell(CycleMonth m) {
    final amount = widget.amountOf(m.key);
    final filled = amount > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Lx.s8, vertical: 6),
      decoration: BoxDecoration(
        color: filled
            ? (widget.highlight ? Colors.white : Lx.primaryLight)
            : (widget.highlight ? Colors.white54 : Lx.background),
        borderRadius: BorderRadius.circular(Lx.rSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(m.label(monthsShort), style: Lx.metadata),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              filled ? rupiah(amount) : '—',
              maxLines: 1,
              style: Lx.moduleLabel
                  .copyWith(color: filled ? Lx.primaryDark : Lx.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

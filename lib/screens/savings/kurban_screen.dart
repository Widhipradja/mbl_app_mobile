import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import '../../models/savings_ledgers.dart';
import '../../services/api_service.dart';
import '../launcher/launcher_models.dart' show monthsShort, rupiah;
import '../budget/budget_widgets.dart' show InitialsAvatar;
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
            icon: Icons.mosque_outlined,
            colors: const [Color(0xFFC2410C), Color(0xFFEA580C)],
          ),
          if (_summary != null && _summary!.hasData)
            _TargetCard(summary: _summary!),
          Padding(
            padding: const EdgeInsets.fromLTRB(Lx.s4, Lx.s4, Lx.s4, Lx.s8),
            child: Row(
              children: [
                Expanded(
                  child: Text(family ? 'Per anggota keluarga' : 'Rincian',
                      style: Lx.cardHeading),
                ),
                Text('Ketuk untuk rincian bulan', style: Lx.metadata),
              ],
            ),
          ),
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
    final pct = (s.progress * 100).round();
    final left = s.target - s.collected;
    const accent = Color(0xFFEA580C);
    return Container(
      margin: const EdgeInsets.only(bottom: Lx.s12),
      padding: const EdgeInsets.all(Lx.s16),
      decoration: Lx.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.flag_outlined, color: accent, size: 20),
              ),
              const SizedBox(width: Lx.s12),
              const Expanded(child: Text('Target kurban', style: Lx.cardHeading)),
              if (s.target > 0)
                Text('$pct%',
                    style: Lx.sectionHeading
                        .copyWith(color: accent, fontSize: 18)),
            ],
          ),
          if (s.target > 0) ...[
            const SizedBox(height: Lx.s12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: s.progress,
                minHeight: 10,
                backgroundColor: const Color(0xFFFFEDD5),
                valueColor: const AlwaysStoppedAnimation(accent),
                semanticsLabel: 'Tabungan terhadap target',
                semanticsValue: '$pct%',
              ),
            ),
          ],
          const SizedBox(height: Lx.s8),
          Row(
            children: [
              Expanded(
                child: Text(
                  s.target > 0
                      ? '${rupiah(s.collected)} dari ${rupiah(s.target)}'
                      : 'Terkumpul ${rupiah(s.collected)}',
                  style: Lx.metadata.copyWith(color: Lx.text),
                ),
              ),
              if (s.target > 0)
                Text(
                  left > 0 ? 'Kurang ${rupiah(left)}' : 'Target tercapai',
                  style: Lx.metadata.copyWith(
                      color: left > 0 ? Lx.textSecondary : Lx.success,
                      fontWeight: FontWeight.w700),
                ),
            ],
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
  static const _accent = Color(0xFFEA580C);
  static const _tint = Color(0xFFFFEDD5);
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
          color: w.highlight ? const Color(0xFFFFF7ED) : Lx.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Lx.rCard),
            side: BorderSide(
                color: w.highlight ? const Color(0xFFFED7AA) : Lx.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap:
                w.months.isEmpty ? null : () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.all(Lx.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (w.highlight)
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                              color: _tint, shape: BoxShape.circle),
                          child: const Icon(Icons.functions_rounded,
                              color: _accent, size: 20),
                        )
                      else
                        InitialsAvatar(w.name),
                      const SizedBox(width: Lx.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(w.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Lx.cardHeading.copyWith(fontSize: 14)),
                            if (w.badge.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 3),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Lx.secondaryLight,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(w.badge,
                                    style: Lx.metadata.copyWith(
                                        fontSize: 10,
                                        color: Lx.secondary,
                                        fontWeight: FontWeight.w700)),
                              )
                            else if (w.months.isNotEmpty)
                              Text('$_filled dari ${w.months.length} bulan terisi',
                                  style: Lx.metadata),
                          ],
                        ),
                      ),
                      const SizedBox(width: Lx.s8),
                      Text(rupiah(w.total),
                          style: Lx.cardHeading.copyWith(
                              color: Lx.text,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ])),
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
                    const SizedBox(height: Lx.s12),
                    _segments(),
                    if (w.badge.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                            '$_filled dari ${w.months.length} bulan terisi',
                            style: Lx.metadata),
                      ),
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

  /// One segment per month of the cycle, filled where something was paid.
  Widget _segments() {
    final months = widget.months;
    return Row(
      children: [
        for (var i = 0; i < months.length; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: widget.amountOf(months[i].key) > 0
                    ? _accent
                    : (widget.highlight ? Colors.white : const Color(0xFFEDF1F8)),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: Lx.s8, vertical: Lx.s8),
      decoration: BoxDecoration(
        color: filled ? _tint : (widget.highlight ? Colors.white : Lx.background),
        borderRadius: BorderRadius.circular(Lx.rSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                  filled
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 12,
                  color: filled ? _accent : Lx.textMuted),
              const SizedBox(width: 4),
              Text(m.label(monthsShort), style: Lx.metadata),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              filled ? rupiah(amount) : 'Belum',
              maxLines: 1,
              style: Lx.moduleLabel.copyWith(
                  color: filled ? const Color(0xFF9A3412) : Lx.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

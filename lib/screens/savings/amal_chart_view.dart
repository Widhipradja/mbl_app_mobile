import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import '../../models/savings_ledgers.dart';
import '../../widgets/app_ui.dart' show SectionCard;
import '../finance/finance_data.dart' show rpShort;
import '../launcher/launcher_models.dart' show rupiah;
import 'ledger_widgets.dart' show monthNames;

/// Colours of the three kinds, the same as on the Buku Amal Jariyah cards.
const amalFrColor = Color(0xFF2563EB);
const amalShodaqohColor = Color(0xFF0D9488);
const amalInfaqColor = Color(0xFF7C3AED);

/// "Grafik" tab of Buku Amal Jariyah: one year as a summary, a stacked bar
/// per month (FR, Shodaqoh, Infaq) and the running total against the year
/// before. Built from the yearly report only.
class AmalChartView extends StatefulWidget {
  const AmalChartView({
    super.key,
    required this.year,
    required this.data,
    required this.previous,
    required this.onOpenMonth,
  });

  final int year;
  final AmalJariyahYear data;

  /// The year before, for the comparison; null when unknown or not loaded.
  final AmalJariyahYear? previous;
  final void Function(int year, int month) onOpenMonth;

  @override
  State<AmalChartView> createState() => _AmalChartViewState();
}

/// FR, Shodaqoh and Infaq of one month.
typedef _Amounts = ({double fr, double shodaqoh, double infaq});

extension on _Amounts {
  double get total => fr + shodaqoh + infaq;
}

/// Twelve months, January first; months the report leaves out are zero.
List<_Amounts> _byMonth(AmalJariyahYear? d) {
  final out = List<_Amounts>.filled(12, (fr: 0, shodaqoh: 0, infaq: 0));
  for (final m in d?.months ?? const <AmalJariyahMonth>[]) {
    final n = m.monthNumber;
    if (n == null || n < 1 || n > 12) continue;
    final o = out[n - 1];
    out[n - 1] = (
      fr: o.fr + m.fr,
      shodaqoh: o.shodaqoh + m.shodaqoh,
      infaq: o.infaq + m.infaq,
    );
  }
  return out;
}

List<double> _running(List<_Amounts> months, int upTo) {
  var sum = 0.0;
  return [for (var i = 0; i < upTo; i++) sum += months[i].total];
}

class _AmalChartViewState extends State<AmalChartView> {
  /// Selected month, 0-based; null for none.
  int? _selected;

  late List<_Amounts> _months, _prevMonths;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(AmalChartView old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data ||
        old.previous != widget.previous ||
        old.year != widget.year) {
      _prepare();
    }
  }

  void _prepare() {
    _months = _byMonth(widget.data);
    _prevMonths = _byMonth(widget.previous);
    final last = _lastWithData;
    _selected = last < 0 ? null : last;
  }

  /// Index of the last month with an amount; -1 for none.
  int get _lastWithData => _months.lastIndexWhere((m) => m.total > 0);

  /// Months that have begun: all twelve for a past year.
  int get _monthsSoFar {
    final now = DateTime.now();
    if (widget.year < now.year) return 12;
    if (widget.year > now.year) return 0;
    return now.month;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _summary(),
        _bars(),
        _cumulative(),
      ],
    );
  }

  // ── Summary ──────────────────────────────────────────────────────────────

  Widget _summary() {
    final total = widget.data.total;
    final recorded = _months.where((m) => m.total > 0).length;
    final soFar = math.max(_monthsSoFar, _lastWithData + 1);
    final avg = recorded == 0 ? 0.0 : total / recorded;

    // Same stretch of the year before: January up to the last month recorded.
    String? compare;
    final upTo = _lastWithData + 1;
    if (widget.previous != null && upTo > 0) {
      final prev = _running(_prevMonths, upTo).last;
      final now = _running(_months, upTo).last;
      final span = upTo == 12
          ? 'tahun ${widget.year - 1}'
          : 'Jan–${monthNames[upTo - 1].substring(0, 3)} ${widget.year - 1}';
      if (prev > 0) {
        final pct = ((now - prev) / prev * 100).round();
        compare = pct == 0
            ? 'Sama dengan $span'
            : '${pct > 0 ? '▲' : '▼'} ${pct.abs()}% dibanding $span';
      }
    }

    Widget stat(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Lx.metadata.copyWith(color: Colors.white70)),
              const SizedBox(height: 2),
              Text(value,
                  style: Lx.cardHeading
                      .copyWith(color: Colors.white, fontSize: 15)),
            ],
          ),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: Lx.s12),
      padding: const EdgeInsets.all(Lx.s16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Lx.rCard),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E7490), Color(0xFF0891B2)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total tahun ${widget.year}',
              style: Lx.metadata.copyWith(color: Colors.white70)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(rupiah(total),
                style: Lx.userName.copyWith(
                    color: Colors.white,
                    fontSize: 24,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ),
          if (compare != null) ...[
            const SizedBox(height: Lx.s4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(compare,
                  style: Lx.metadata.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
          const SizedBox(height: Lx.s12),
          Row(
            children: [
              stat('Rata-rata / bulan', rpShort(avg.round())),
              stat('Bulan tercatat', '$recorded dari ${soFar.clamp(1, 12)}'),
            ],
          ),
        ],
      ),
    );
  }

  // ── Stacked bars ─────────────────────────────────────────────────────────

  static Widget _legend(String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 4),
          Text(label, style: Lx.metadata),
        ],
      );

  Widget _bars() {
    final top = _months.fold<double>(0, (a, m) => math.max(a, m.total));
    const height = 150.0;
    final sel = _selected;

    Widget column(int i) {
      final m = _months[i];
      final on = sel == null || sel == i;
      final empty = m.total <= 0;
      double h(double v) => top <= 0 ? 0 : height * v / top;
      Widget seg(double v, Color c, {bool top = false}) => v <= 0
          ? const SizedBox.shrink()
          : Container(
              height: h(v),
              decoration: BoxDecoration(
                color: on ? c : c.withOpacity(0.3),
                borderRadius: top
                    ? const BorderRadius.vertical(top: Radius.circular(4))
                    : null,
              ),
            );
      // Top segment rounded: the highest kind that has an amount.
      final topKind = m.infaq > 0
          ? 2
          : m.shodaqoh > 0
              ? 1
              : 0;
      return Expanded(
        child: Semantics(
          button: !empty,
          selected: sel == i,
          label: '${monthNames[i]}: ${rupiah(m.total)}',
          child: InkWell(
            borderRadius: BorderRadius.circular(Lx.rSmall),
            onTap: empty ? null : () => setState(() => _selected = i),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: empty
                      ? Container(
                          height: 3,
                          decoration: BoxDecoration(
                              color: Lx.border,
                              borderRadius: BorderRadius.circular(2)),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            seg(m.infaq, amalInfaqColor, top: topKind == 2),
                            seg(m.shodaqoh, amalShodaqohColor,
                                top: topKind == 1),
                            seg(m.fr, amalFrColor, top: topKind == 0),
                          ],
                        ),
                ),
                const SizedBox(height: 6),
                Text(monthNames[i].substring(0, 1),
                    style: Lx.metadata.copyWith(
                        color: sel == i ? Lx.text : Lx.textMuted,
                        fontWeight: sel == i ? FontWeight.w800 : null)),
              ],
            ),
          ),
        ),
      );
    }

    return SectionCard(
      title: 'Per bulan',
      subtitle: 'Ketuk batang untuk melihat rinciannya',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: Lx.s16,
            runSpacing: 4,
            children: [
              _legend('FR', amalFrColor),
              _legend('Shodaqoh', amalShodaqohColor),
              _legend('Infaq', amalInfaqColor),
            ],
          ),
          const SizedBox(height: Lx.s12),
          SizedBox(
            height: height + 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [for (var i = 0; i < 12; i++) column(i)],
            ),
          ),
          if (sel != null) ...[
            const SizedBox(height: Lx.s12),
            _monthDetail(sel),
          ],
        ],
      ),
    );
  }

  Widget _monthDetail(int i) {
    final m = _months[i];
    Widget row(String label, double v, Color c) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: c, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: Lx.s8),
              Text(label, style: Lx.body),
              const Spacer(),
              Text(v > 0 ? rupiah(v) : '—',
                  style: Lx.body.copyWith(
                      color: v > 0 ? Lx.text : Lx.textMuted,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(Lx.s12, Lx.s12, Lx.s12, Lx.s4),
      decoration: BoxDecoration(
        color: Lx.background,
        borderRadius: BorderRadius.circular(Lx.rButton),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${monthNames[i]} ${widget.year}',
                    style: Lx.cardHeading.copyWith(fontSize: 14)),
              ),
              Text(rupiah(m.total),
                  style: Lx.cardHeading.copyWith(
                      fontSize: 14,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
          const SizedBox(height: Lx.s4),
          row('FR', m.fr, amalFrColor),
          row('Shodaqoh', m.shodaqoh, amalShodaqohColor),
          row('Infaq', m.infaq, amalInfaqColor),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => widget.onOpenMonth(widget.year, i + 1),
              icon: const Icon(Icons.chevron_right_rounded, size: 18),
              label: const Text('Rincian bulan ini'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Running total ────────────────────────────────────────────────────────

  Widget _cumulative() {
    // This year up to the last month with data (or the current month);
    // the year before for all twelve.
    final upTo = math.max(_lastWithData + 1, math.min(_monthsSoFar, 12));
    if (upTo <= 0) return const SizedBox.shrink();
    final now = _running(_months, upTo);
    final hasPrev =
        widget.previous != null && _prevMonths.any((m) => m.total > 0);
    final prev = hasPrev ? _running(_prevMonths, 12) : const <double>[];
    final maxY = [...now, ...prev, 1.0].reduce(math.max) * 1.1;

    LineChartBarData line(List<double> v, Color c,
            {bool fill = false, bool dashed = false}) =>
        LineChartBarData(
          spots: [
            for (var i = 0; i < v.length; i++) FlSpot(i.toDouble(), v[i])
          ],
          isCurved: true,
          preventCurveOverShooting: true,
          color: c,
          barWidth: dashed ? 2 : 3,
          dashArray: dashed ? [5, 4] : null,
          dotData: FlDotData(show: !dashed && v.length <= 2),
          belowBarData: BarAreaData(
            show: fill,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [c.withOpacity(0.25), c.withOpacity(0)],
            ),
          ),
        );

    return SectionCard(
      title: 'Akumulasi',
      subtitle: hasPrev
          ? 'Jumlah berjalan, dibanding tahun ${widget.year - 1}'
          : 'Jumlah berjalan sepanjang tahun',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: Lx.s16,
            children: [
              _legend('${widget.year}', const Color(0xFF0891B2)),
              if (hasPrev) _legend('${widget.year - 1}', Lx.textMuted),
            ],
          ),
          const SizedBox(height: Lx.s12),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 11,
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: Lx.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      interval: maxY / 4,
                      getTitlesWidget: (v, meta) => v == meta.max
                          ? const SizedBox.shrink()
                          : Text(rpShort(v.round()),
                              style: Lx.metadata.copyWith(fontSize: 10)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 22,
                      getTitlesWidget: (v, meta) {
                        final i = v.round();
                        if (i < 0 || i > 11 || i.isOdd) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(monthNames[i].substring(0, 3),
                              style: Lx.metadata.copyWith(fontSize: 10)),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => Lx.text,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (spots) => [
                      for (final s in spots)
                        LineTooltipItem(
                          '${monthNames[s.x.round()].substring(0, 3)} '
                          '${s.barIndex == 0 ? widget.year : widget.year - 1}'
                          '\n${rupiah(s.y)}',
                          Lx.metadata.copyWith(
                              color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),
                lineBarsData: [
                  line(now, const Color(0xFF0891B2), fill: true),
                  if (hasPrev) line(prev, Lx.textMuted, dashed: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

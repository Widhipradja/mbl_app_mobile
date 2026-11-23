import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import '../../models/savings_ledgers.dart';
import '../../services/api_service.dart';
import '../launcher/launcher_models.dart' show rupiah;
import 'amal_deposit_form_screen.dart';
import '../../widgets/app_ui.dart' show InitialsAvatar, SoftTabs;
import 'ledger_widgets.dart';

enum _Mode { monthly, yearly }

/// Buku Amal Jariyah of the logged-in member: FR, shodaqoh and infaq, for the
/// whole family when the member is a head of family (KK), else for themself.
/// Shown for one month, or as a year of months.
class AmalJariyahScreen extends StatefulWidget {
  const AmalJariyahScreen({super.key});

  @override
  State<AmalJariyahScreen> createState() => _AmalJariyahScreenState();
}

class _AmalJariyahScreenState extends State<AmalJariyahScreen> {
  static final _now = DateTime.now();

  _Mode _mode = _Mode.monthly;
  DateTime _month = DateTime(_now.year, _now.month);
  int _year = _now.year;
  bool _loading = true;
  String? _error;
  AmalJariyahMonth? _monthData;
  AmalJariyahYear? _yearData;

  /// Months the backend lists as pending (`YYYY-MM`); null while unknown or if
  /// the call failed: no deposit button is shown then.
  Set<String>? _pending;

  /// Oldest year with data, once a yearly report has said so.
  int? _earliestYear;

  /// Furthest month the user may page forward to: the current month, or a
  /// later one when the backend already generated it (data or pending).
  DateTime _lastMonth = DateTime(_now.year, _now.month);

  void _extendLast(DateTime m) {
    if (m.isAfter(_lastMonth)) _lastMonth = DateTime(m.year, m.month);
  }

  @override
  void initState() {
    super.initState();
    _start();
    _loadPending();
  }

  /// Opens on the latest month that has data (looking back year by year, as
  /// far as the oldest year the API reports), not on the current month. If
  /// there is none, or the lookup fails, it stays on the current month.
  Future<void> _start() async {
    try {
      final api = ApiService();
      for (var y = _now.year;; y--) {
        final data =
            AmalJariyahYear.parse((await api.getFamilyReportYearly(y)).data);
        _earliestYear = data.earliestYear ?? _earliestYear;
        final withData = data.months
            .where((m) => !m.isEmpty && m.monthNumber != null)
            .toList()
          ..sort((a, b) => a.monthNumber!.compareTo(b.monthNumber!));
        if (withData.isNotEmpty) {
          _extendLast(DateTime(y, withData.last.monthNumber!));
          _month = DateTime(y, withData.last.monthNumber!);
          _year = y;
          break;
        }
        final earliest = data.earliestYear;
        if (earliest == null || y <= earliest || y <= _now.year - 10) break;
      }
    } catch (e) {
      debugPrint('AmalJariyahScreen start error: $e');
    }
    if (mounted) _load();
  }

  Future<void> _loadPending() async {
    try {
      final resp = await ApiService().getPendingPeriods();
      var src = resp.data;
      if (src is! List || !mounted) return;
      final set = <String>{};
      for (final e in src) {
        final v = e is Map ? (e['period_month'] ?? e['period']) : e;
        final m = RegExp(r'^\d{4}-\d{2}').firstMatch(v?.toString() ?? '');
        if (m != null) set.add(m.group(0)!);
      }
      setState(() {
        _pending = set;
        for (final p in set) {
          _extendLast(DateTime(int.parse(p.substring(0, 4)),
              int.parse(p.substring(5, 7))));
        }
      });
    } catch (e) {
      debugPrint('AmalJariyahScreen pending error: $e');
    }
  }

  static String _param(DateTime m) =>
      '${m.year}-${m.month.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    final mode = _mode;
    final month = _month;
    final year = _year;
    bool stale() =>
        !mounted || mode != _mode || month != _month || year != _year;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ApiService();
      if (mode == _Mode.monthly) {
        final resp = await api.getFamilyReport(_param(month));
        if (stale()) return;
        setState(() => _monthData = AmalJariyahMonth.parse(resp.data));
      } else {
        final resp = await api.getFamilyReportYearly(year);
        if (stale()) return;
        final data = AmalJariyahYear.parse(resp.data);
        setState(() {
          _yearData = data;
          _earliestYear = data.earliestYear ?? _earliestYear;
        });
      }
    } catch (e) {
      if (stale()) return;
      debugPrint('AmalJariyahScreen error: $e');
      setState(() {
        _monthData = null;
        _yearData = null;
        _error = ledgerFailure(e);
      });
    } finally {
      if (!stale()) setState(() => _loading = false);
    }
  }

  void _setMode(_Mode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      // Both views start from where the other one is.
      if (mode == _Mode.yearly) _year = _month.year;
    });
    _load();
  }

  void _setMonth(DateTime m) {
    setState(() => _month = DateTime(m.year, m.month));
    _load();
  }

  void _setYear(int y) {
    setState(() => _year = y);
    _load();
  }

  /// Opens one month of the yearly list in the monthly view.
  void _openMonth(int year, int month) {
    setState(() {
      _mode = _Mode.monthly;
      _month = DateTime(year, month);
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final monthly = _mode == _Mode.monthly;
    final earliest = _earliestYear;
    final canGoBackYear = earliest == null || _year > earliest;
    final canGoForwardYear = _year < _lastMonth.year;
    final canGoForwardMonth = _month.isBefore(_lastMonth);

    final label = monthly
        ? '${monthNames[_month.month - 1]} ${_month.year}'
        : 'Tahun $_year';

    return LedgerPage(
      title: 'Buku Amal Jariyah',
      header: SoftTabs<_Mode>(
        value: _mode,
        items: const [
          (_Mode.monthly, 'Bulanan', Icons.calendar_view_month_rounded),
          (_Mode.yearly, 'Tahunan', Icons.calendar_today_rounded),
        ],
        onChanged: _setMode,
      ),
      periodLabel: label,
      previousTooltip: monthly ? 'Bulan sebelumnya' : 'Tahun sebelumnya',
      nextTooltip: monthly ? 'Bulan berikutnya' : 'Tahun berikutnya',
      onPrevious: monthly
          ? () => _setMonth(DateTime(_month.year, _month.month - 1))
          : (canGoBackYear ? () => _setYear(_year - 1) : null),
      onNext: monthly
          ? (canGoForwardMonth
              ? () => _setMonth(DateTime(_month.year, _month.month + 1))
              : null)
          : (canGoForwardYear ? () => _setYear(_year + 1) : null),
      onRefresh: _load,
      loading: _loading,
      error: _error,
      emptyText: monthly
          ? 'Belum ada catatan amal jariyah di $label.'
          : 'Belum ada catatan amal jariyah di tahun $_year.',
      children: monthly ? _monthly(label) : _yearly(),
    );
  }

  // ── One month ────────────────────────────────────────────────────────────

  /// Opens the deposit form for the month on screen; on success the pending
  /// deposit is announced and the month reloads.
  Future<void> _deposit() async {
    final sent = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => AmalDepositFormScreen(month: _month),
    ));
    if (sent != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Setoran terkirim. Menunggu verifikasi bendahara.')));
    _load();
    _loadPending();
  }

  /// "Setoran bulan ini belum dikirim", with the button that sends it.
  Widget _depositCard(String label) => Container(
        margin: const EdgeInsets.only(bottom: Lx.s12),
        padding: const EdgeInsets.all(Lx.s16),
        decoration: BoxDecoration(
          color: const Color(0xFFECFEFF),
          borderRadius: BorderRadius.circular(Lx.rCard),
          border: Border.all(color: const Color(0xFFA5F3FC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.volunteer_activism_outlined,
                    color: _amalAccent),
                const SizedBox(width: Lx.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Setoran $label belum dikirim',
                          style: Lx.cardHeading.copyWith(fontSize: 14)),
                      Text('Kirim dengan bukti transfer; bendahara akan '
                          'memverifikasi.',
                          style: Lx.metadata),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Lx.s12),
            FilledButton.icon(
              onPressed: _deposit,
              style: FilledButton.styleFrom(
                  backgroundColor: _amalAccent,
                  minimumSize: const Size.fromHeight(46)),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Setor Sekarang'),
            ),
          ],
        ),
      );

  /// Other months still waiting for a deposit, with a way to the oldest.
  Widget? _otherPendingBanner() {
    final pending = _pending;
    if (pending == null) return null;
    final others = pending.where((p) => p != _param(_month)).toList()..sort();
    if (others.isEmpty) return null;
    final first = others.first;
    final y = int.parse(first.substring(0, 4));
    final m = int.parse(first.substring(5, 7));
    return Padding(
      padding: const EdgeInsets.only(bottom: Lx.s12),
      child: Material(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(Lx.rCard),
        child: InkWell(
          borderRadius: BorderRadius.circular(Lx.rCard),
          onTap: () => _setMonth(DateTime(y, m)),
          child: Container(
            padding: const EdgeInsets.all(Lx.s12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Lx.rCard),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, color: Color(0xFFEA580C)),
                const SizedBox(width: Lx.s12),
                Expanded(
                  child: Text(
                      others.length == 1
                          ? '${monthNames[m - 1]} $y belum disetor'
                          : '${others.length} bulan lain belum disetor, '
                              'mulai ${monthNames[m - 1]} $y',
                      style: Lx.metadata.copyWith(
                          color: Lx.text, fontWeight: FontWeight.w600)),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Lx.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _monthly(String label) {
    final d = _monthData;
    if (d == null) return const [];
    final pending = _pending;
    // Only the backend's word counts (month listed as pending), never the amounts.
    final canDeposit = pending != null && pending.contains(_param(_month));
    final banner = _otherPendingBanner();
    if (d.isEmpty) {
      return [
        if (banner != null) banner,
        if (canDeposit)
          _depositCard(label)
        else
          Container(
            padding: const EdgeInsets.all(Lx.s20),
            decoration: Lx.card(),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                      color: Color(0xFFECFEFF), shape: BoxShape.circle),
                  child: const Icon(Icons.menu_book_outlined,
                      size: 28, color: _amalAccent),
                ),
                const SizedBox(height: Lx.s12),
                Text('Belum ada catatan amal jariyah di $label.',
                    textAlign: TextAlign.center,
                    style: Lx.body.copyWith(height: 1.4)),
              ],
            ),
          ),
      ];
    }
    final family = d.scope.family;
    return [
      if (banner != null) banner,
      LedgerTotalCard(
        label: 'Total $label',
        total: rupiah(d.total),
        caption:
            family ? '${d.entries.length} anggota keluarga' : 'Catatan Anda',
        icon: Icons.menu_book_outlined,
        colors: const [Color(0xFF0E7490), Color(0xFF0891B2)],
        breakdown: [
          ('FR', rupiah(d.fr)),
          ('Shodaqoh', rupiah(d.shodaqoh)),
          ('Infaq', rupiah(d.infaq)),
        ],
      ),
      if (canDeposit) _depositCard(label),
      if (family)
        Padding(
          padding: const EdgeInsets.fromLTRB(Lx.s4, Lx.s4, Lx.s4, Lx.s8),
          child: Text('Per anggota keluarga', style: Lx.cardHeading),
        ),
      for (final e in d.entries)
        AmalEntryCard(entry: e, badge: family && e.isHead),
    ];
  }

  // ── One year ─────────────────────────────────────────────────────────────

  List<Widget> _yearly() {
    final d = _yearData;
    if (d == null) return const [];
    // Months with nothing recorded are left out; newest first.
    final months = d.months.where((m) => !m.isEmpty).toList().reversed.toList();
    if (months.isEmpty) return const [];
    return [
      LedgerTotalCard(
        label: 'Total tahun $_year',
        total: rupiah(d.total),
        caption: '${months.length} bulan tercatat · ketuk bulan untuk rincian',
        icon: Icons.calendar_today_outlined,
        colors: const [Color(0xFF0E7490), Color(0xFF0891B2)],
        breakdown: [
          ('FR', rupiah(d.fr)),
          ('Shodaqoh', rupiah(d.shodaqoh)),
          ('Infaq', rupiah(d.infaq)),
        ],
      ),
      for (final m in months) _MonthSummaryCard(month: m, onTap: _openMonth),
    ];
  }
}

const _amalAccent = Color(0xFF0891B2);

/// Colours of the three kinds, the same on every card.
const _frColor = Color(0xFF2563EB);
const _shodaqohColor = Color(0xFF0D9488);
const _infaqColor = Color(0xFF7C3AED);

/// One month of the yearly list: its total and the three columns. Tapping it
/// opens that month's per-person detail.
class _MonthSummaryCard extends StatelessWidget {
  const _MonthSummaryCard({required this.month, required this.onTap});

  final AmalJariyahMonth month;
  final void Function(int year, int month) onTap;

  @override
  Widget build(BuildContext context) {
    final n = month.monthNumber;
    final year = int.tryParse(month.period.split('-').first);
    final title = n == null
        ? month.period
        : '${monthNames[n - 1]}${year == null ? '' : ' $year'}';
    return Container(
      margin: const EdgeInsets.only(bottom: Lx.s8),
      child: Material(
        color: Lx.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Lx.rCard),
          side: const BorderSide(color: Lx.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: n == null || year == null ? null : () => onTap(year, n),
          child: Padding(
            padding: const EdgeInsets.all(Lx.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFEFF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                          n == null ? '–' : monthNames[n - 1].substring(0, 3),
                          style: Lx.metadata.copyWith(
                              color: _amalAccent,
                              fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: Lx.s12),
                    Expanded(child: Text(title, style: Lx.cardHeading)),
                    Text(rupiah(month.total),
                        style: Lx.cardHeading.copyWith(
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ])),
                    const Icon(Icons.chevron_right_rounded,
                        color: Lx.textSecondary),
                  ],
                ),
                const SizedBox(height: Lx.s12),
                AmalColumns(
                    fr: month.fr, shodaqoh: month.shodaqoh, infaq: month.infaq),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One person (or the whole report row): name, total and the three columns.
class AmalEntryCard extends StatelessWidget {
  const AmalEntryCard({super.key, required this.entry, this.badge = false});

  final AmalEntry entry;

  /// Marks the head of the family.
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    return Container(
      margin: const EdgeInsets.only(bottom: Lx.s8),
      padding: const EdgeInsets.all(Lx.s16),
      decoration: Lx.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InitialsAvatar(e.name),
              const SizedBox(width: Lx.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Lx.cardHeading.copyWith(fontSize: 14)),
                    if (badge)
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Lx.secondaryLight,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('Kepala keluarga',
                            style: Lx.metadata.copyWith(
                                fontSize: 10,
                                color: Lx.secondary,
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: Lx.s8),
              Text(rupiah(e.total),
                  style: Lx.cardHeading.copyWith(fontFeatures: const [
                    FontFeature.tabularFigures()
                  ])),
            ],
          ),
          const SizedBox(height: Lx.s12),
          AmalColumns(fr: e.fr, shodaqoh: e.shodaqoh, infaq: e.infaq),
        ],
      ),
    );
  }
}

/// A bar split in the share of FR, Shodaqoh and Infaq, then the three
/// amounts, each in its own colour.
class AmalColumns extends StatelessWidget {
  const AmalColumns({
    super.key,
    required this.fr,
    required this.shodaqoh,
    required this.infaq,
  });

  final double fr;
  final double shodaqoh;
  final double infaq;

  @override
  Widget build(BuildContext context) {
    final total = fr + shodaqoh + infaq;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (total > 0) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  if (fr > 0)
                    Expanded(
                        flex: (fr * 1000 / total).round().clamp(1, 1000),
                        child: Container(color: _frColor)),
                  if (shodaqoh > 0)
                    Expanded(
                        flex: (shodaqoh * 1000 / total).round().clamp(1, 1000),
                        child: Container(color: _shodaqohColor)),
                  if (infaq > 0)
                    Expanded(
                        flex: (infaq * 1000 / total).round().clamp(1, 1000),
                        child: Container(color: _infaqColor)),
                ],
              ),
            ),
          ),
          const SizedBox(height: Lx.s8),
        ],
        Row(
          children: [
            _cell('FR', fr, _frColor),
            const SizedBox(width: Lx.s8),
            _cell('Shodaqoh', shodaqoh, _shodaqohColor),
            const SizedBox(width: Lx.s8),
            _cell('Infaq', infaq, _infaqColor),
          ],
        ),
      ],
    );
  }

  Widget _cell(String label, double amount, Color color) {
    final filled = amount > 0;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: filled ? color : Lx.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Lx.metadata),
              ),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              // Digits only: the card is in rupiah, and equal sizes read better.
              filled ? rupiah(amount).substring(3) : '—',
              maxLines: 1,
              style: Lx.moduleLabel.copyWith(
                  color: filled ? Lx.text : Lx.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
        ],
      ),
    );
  }
}

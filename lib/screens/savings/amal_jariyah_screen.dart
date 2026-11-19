import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import '../../models/savings_ledgers.dart';
import '../../services/api_service.dart';
import '../launcher/launcher_models.dart' show rupiah;
import 'amal_deposit_form_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
    _loadPending();
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
      setState(() => _pending = set);
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
    final canGoForwardYear = _year < _now.year;
    final canGoForwardMonth = _month.year < _now.year ||
        (_month.year == _now.year && _month.month < _now.month);

    final label = monthly
        ? '${monthNames[_month.month - 1]} ${_month.year}'
        : 'Tahun $_year';

    return LedgerPage(
      title: 'Buku Amal Jariyah',
      header: SegmentedButton<_Mode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: _Mode.monthly, label: Text('Bulanan')),
          ButtonSegment(value: _Mode.yearly, label: Text('Tahunan')),
        ],
        selected: {_mode},
        onSelectionChanged: (s) => _setMode(s.first),
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

  Widget _depositButton({required bool first}) => SizedBox(
        width: double.infinity,
        child: first
            ? FilledButton.icon(
                onPressed: _deposit,
                icon: const Icon(Icons.volunteer_activism_rounded),
                label: const Text('Setor'),
              )
            : OutlinedButton.icon(
                onPressed: _deposit,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Setor'),
              ),
      );

  List<Widget> _monthly(String label) {
    final d = _monthData;
    if (d == null) return const [];
    final pending = _pending;
    // Only the backend's word counts (month listed as pending), never the amounts.
    final canDeposit = pending != null && pending.contains(_param(_month));
    if (d.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(Lx.s16),
          decoration: Lx.card(),
          child: Column(
            children: [
              const Icon(Icons.inbox_outlined, size: 40, color: Lx.border),
              const SizedBox(height: Lx.s8),
              Text('Belum ada catatan amal jariyah di $label.',
                  textAlign: TextAlign.center,
                  style: Lx.body.copyWith(height: 1.4)),
              const SizedBox(height: Lx.s12),
              if (canDeposit) _depositButton(first: true),
            ],
          ),
        ),
      ];
    }
    final family = d.scope.family;
    return [
      LedgerTotalCard(
        label: 'Total $label',
        total: rupiah(d.total),
        caption:
            family ? '${d.entries.length} anggota keluarga' : 'Catatan Anda',
        breakdown: [
          ('FR', rupiah(d.fr)),
          ('Shodaqoh', rupiah(d.shodaqoh)),
          ('Infaq', rupiah(d.infaq)),
        ],
      ),
      for (final e in d.entries)
        AmalEntryCard(entry: e, badge: family && e.isHead),
      if (canDeposit) ...[
        const SizedBox(height: Lx.s4),
        _depositButton(first: false),
      ],
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
        caption: '${months.length} bulan tercatat',
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
            padding: const EdgeInsets.all(Lx.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, style: Lx.cardHeading)),
                    Text(rupiah(month.total),
                        style: Lx.cardHeading.copyWith(color: Lx.primary)),
                    const Icon(Icons.chevron_right_rounded,
                        color: Lx.textSecondary),
                  ],
                ),
                const SizedBox(height: Lx.s8),
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
      padding: const EdgeInsets.all(Lx.s12),
      decoration: Lx.card(),
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
                    Text(e.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Lx.cardHeading),
                    if (badge)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('Kepala keluarga',
                            style: Lx.metadata.copyWith(color: Lx.secondary)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: Lx.s8),
              Text(rupiah(e.total),
                  style: Lx.cardHeading.copyWith(color: Lx.primary)),
            ],
          ),
          const SizedBox(height: Lx.s8),
          AmalColumns(fr: e.fr, shodaqoh: e.shodaqoh, infaq: e.infaq),
        ],
      ),
    );
  }
}

/// The FR, Shodaqoh and Infaq cells.
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
    return Row(
      children: [
        _cell('FR', fr),
        const SizedBox(width: Lx.s8),
        _cell('Shodaqoh', shodaqoh),
        const SizedBox(width: Lx.s8),
        _cell('Infaq', infaq),
      ],
    );
  }

  Widget _cell(String label, double amount) {
    final filled = amount > 0;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Lx.s8, vertical: 6),
        decoration: BoxDecoration(
          color: filled ? Lx.primaryLight : Lx.background,
          borderRadius: BorderRadius.circular(Lx.rSmall),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Lx.metadata),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                // Digits only: the card is in rupiah, and equal sizes read better.
                filled ? rupiah(amount).substring(3) : '—',
                maxLines: 1,
                style: Lx.moduleLabel
                    .copyWith(color: filled ? Lx.primaryDark : Lx.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

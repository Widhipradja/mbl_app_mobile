import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import '../../widgets/app_ui.dart';
import '../finance/finance_data.dart' show dateShort, rp;
import '../savings/ledger_widgets.dart' show monthNames;
import 'ringkasan_data.dart';

typedef RingkasanLoader = Future<RingkasanData> Function(String month);

/// Ringkasan: the community's numbers on the phone. Saldo Kas and Keanggotaan
/// are as of today; the month stepper under them drives Shodaqoh Bulanan and
/// Jimpitan only. Each card fails on its own (the server answers `{data}` or
/// `{error}` per section); Saldo Kas is left out when the module gate for
/// money is closed for this account.
class RingkasanScreen extends StatefulWidget {
  const RingkasanScreen({super.key, this.loader = loadRingkasan});

  /// Fetches one month; replaced in tests.
  final RingkasanLoader loader;

  @override
  State<RingkasanScreen> createState() => _RingkasanScreenState();
}

class _RingkasanScreenState extends State<RingkasanScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  RingkasanData? _data;
  bool _loading = true;
  String? _error;
  bool _allJimpitan = false;

  static const _recentRows = 4;
  static const _jimpitanRows = 5;

  @override
  void initState() {
    super.initState();
    _load();
  }

  static String _key(DateTime m) =>
      '${m.year}-${m.month.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    final month = _month;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.loader(_key(month));
      if (!mounted || month != _month) return;
      setState(() => _data = data);
    } catch (e) {
      debugPrint('Ringkasan load error: $e');
      if (mounted && month == _month) {
        setState(() {
          _data = null;
          _error = ringkasanFailure(e);
        });
      }
    } finally {
      if (mounted && month == _month) setState(() => _loading = false);
    }
  }

  void _setMonth(DateTime m) {
    setState(() {
      _month = DateTime(m.year, m.month);
      _allJimpitan = false;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Theme(
      data: Lx.theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Ringkasan')),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Lx.s16, Lx.s8, Lx.s16, Lx.s24),
            children: [
              if (d == null && _loading)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (d == null)
                RetryState(_error ?? 'Data belum bisa dimuat.', onRetry: _load)
              else ...[
                if (!d.finance.forbidden) _finance(d.finance),
                _members(d.members),
                Padding(
                  padding: const EdgeInsets.only(bottom: Lx.s12),
                  child: MonthPill(month: _month, onChanged: _setMonth),
                ),
                _shodaqoh(d.shodaqoh),
                _jimpitan(d.jimpitan),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Pieces ───────────────────────────────────────────────────────────────

  Widget _sectionError(String? code) {
    final retry = code == 'timeout' || code == 'unavailable' || code == null;
    return Column(
      children: [
        const Icon(Icons.cloud_off_rounded, size: 28, color: Lx.textMuted),
        const SizedBox(height: Lx.s8),
        Text(ringkasanErrorText(code),
            textAlign: TextAlign.center, style: Lx.metadata),
        if (retry) TextButton(onPressed: _load, child: const Text('Coba lagi')),
      ],
    );
  }

  Widget _stat(String label, String value, {Color? color}) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Lx.metadata),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  maxLines: 1,
                  style: Lx.cardHeading.copyWith(
                      fontSize: 15,
                      color: color ?? Lx.text,
                      fontFeatures: tabular)),
            ),
          ],
        ),
      );

  Widget _headline(String text) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(text,
            maxLines: 1,
            style: Lx.userName.copyWith(fontSize: 26, fontFeatures: tabular)),
      );

  /// An amount that shrinks instead of overflowing on a narrow screen.
  Widget _amount(String text, {Color? color}) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 150),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(text,
              maxLines: 1,
              style: Lx.cardHeading
                  .copyWith(fontSize: 14, color: color, fontFeatures: tabular)),
        ),
      );

  // ── Saldo Kas ────────────────────────────────────────────────────────────

  Widget _finance(RingkasanSection<RingkasanFinance> s) {
    final f = s.data;
    return SectionCard(
      title: 'Saldo Kas',
      subtitle: f?.asOf == null ? null : 'Per ${dateShort(f!.asOf!)}',
      child: f == null
          ? _sectionError(s.error)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headline(rp(f.balance)),
                const SizedBox(height: Lx.s12),
                Row(
                  children: [
                    _stat('Pemasukan bulan ini', rp(f.income),
                        color: Lx.success),
                    const SizedBox(width: Lx.s12),
                    _stat('Pengeluaran bulan ini', rp(f.expense),
                        color: Lx.danger),
                  ],
                ),
                if (f.recent.isNotEmpty) ...[
                  const SizedBox(height: Lx.s16),
                  Text('Transaksi terbaru', style: Lx.cardHeading),
                  for (final t in f.recent.take(_recentRows)) _trxRow(t),
                ],
                if (f.funds != null && f.funds!.items.isNotEmpty) ...[
                  const SizedBox(height: Lx.s16),
                  Text('Dana per kategori', style: Lx.cardHeading),
                  Text(
                      f.funds!.asOf == null
                          ? 'Saldo sampai hari ini'
                          : 'Saldo sampai ${dateShort(f.funds!.asOf!)}',
                      style: Lx.metadata),
                  for (final fund in f.funds!.items) _fundRow(fund),
                ] else if (f.fundsError != null && f.fundsError != 'forbidden')
                  Padding(
                    padding: const EdgeInsets.only(top: Lx.s12),
                    child: Text('Dana per kategori belum bisa dimuat.',
                        style: Lx.metadata),
                  ),
              ],
            ),
    );
  }

  Widget _trxRow(RingkasanTrx t) {
    final color = t.isIncome
        ? Lx.success
        : t.isExpense
            ? Lx.danger
            : Lx.text;
    final sign = t.isIncome ? '+' : (t.isExpense ? '-' : '');
    return Padding(
      padding: const EdgeInsets.only(top: Lx.s12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.description.isEmpty ? 'Transaksi' : t.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Lx.body.copyWith(color: Lx.text)),
                if (t.date != null)
                  Text(dateShort(t.date!), style: Lx.metadata),
              ],
            ),
          ),
          const SizedBox(width: Lx.s12),
          _amount('$sign${rp(t.amount)}', color: color),
        ],
      ),
    );
  }

  Widget _fundRow(RingkasanFund f) => Padding(
        padding: const EdgeInsets.only(top: Lx.s12),
        child: Row(
          children: [
            Expanded(
              child: Text(f.name.isEmpty ? f.key : f.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Lx.body.copyWith(color: Lx.text)),
            ),
            const SizedBox(width: Lx.s12),
            _amount(rp(f.balance)),
          ],
        ),
      );

  // ── Keanggotaan ──────────────────────────────────────────────────────────

  Widget _members(RingkasanSection<RingkasanMembers> s) {
    final m = s.data;
    return SectionCard(
      title: 'Keanggotaan',
      child: m == null
          ? _sectionError(s.error)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headline('${m.total}'),
                Text('anggota terdaftar', style: Lx.metadata),
                const SizedBox(height: Lx.s12),
                Row(
                  children: [
                    _stat('Aktif', '${m.active}'),
                    _stat('Baru bulan ini', '${m.newThisMonth}'),
                    _stat('Keluarga', '${m.families}'),
                  ],
                ),
                if (m.male + m.female > 0) ...[
                  const SizedBox(height: Lx.s16),
                  _genderBar(m.male, m.female),
                ],
                if (m.ageGroups.isNotEmpty) ...[
                  const SizedBox(height: Lx.s16),
                  Text('Kelompok usia', style: Lx.cardHeading),
                  for (final g in m.ageGroups) _ageRow(g, m.ageGroups),
                ],
              ],
            ),
    );
  }

  static const _maleColor = Color(0xFF2563EB);
  static const _femaleColor = Color(0xFFEC4899);

  Widget _genderBar(int male, int female) {
    final total = male + female;
    Widget part(int v, Color c) => v <= 0
        ? const SizedBox.shrink()
        : Expanded(
            flex: (v * 1000 / total).round().clamp(1, 1000),
            child: Container(color: c),
          );
    Widget legend(String label, int v, Color c) => Expanded(
          child: Row(
            children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: c, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 6),
              Flexible(
                child: Text('$label $v',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Lx.metadata.copyWith(color: Lx.text)),
              ),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(children: [
              part(male, _maleColor),
              part(female, _femaleColor),
            ]),
          ),
        ),
        const SizedBox(height: Lx.s8),
        Row(children: [
          legend('Laki-laki', male, _maleColor),
          legend('Perempuan', female, _femaleColor),
        ]),
      ],
    );
  }

  Widget _ageRow(RingkasanAgeGroup g, List<RingkasanAgeGroup> all) {
    final top = all.fold<int>(0, (a, b) => b.total > a ? b.total : a);
    return Padding(
      padding: const EdgeInsets.only(top: Lx.s8),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(g.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Lx.metadata.copyWith(color: Lx.text)),
          ),
          Expanded(
            child: RoundBar(
                value: top == 0 ? 0 : g.total / top,
                color: Lx.primary,
                height: 8),
          ),
          SizedBox(
            width: 40,
            child: Text('${g.total}',
                textAlign: TextAlign.end,
                style: Lx.metadata
                    .copyWith(color: Lx.text, fontFeatures: tabular)),
          ),
        ],
      ),
    );
  }

  // ── Shodaqoh Bulanan ─────────────────────────────────────────────────────

  Widget _shodaqoh(RingkasanSection<RingkasanShodaqoh> s) {
    final d = s.data;
    final progress = d == null || d.totalMembers <= 0
        ? 0.0
        : d.participants / d.totalMembers;
    return SectionCard(
      title: 'Shodaqoh Bulanan',
      child: d == null
          ? _sectionError(s.error)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headline(d.totalMembers > 0
                    ? '${d.participants} dari ${d.totalMembers} anggota'
                    : '${d.participants} anggota'),
                Text(
                    'sudah bershodaqoh di '
                    '${monthNames[_month.month - 1]} ${_month.year}',
                    style: Lx.metadata),
                if (d.totalMembers > 0) ...[
                  const SizedBox(height: Lx.s12),
                  RoundBar(value: progress, color: Lx.success, height: 8),
                  const SizedBox(height: 4),
                  Text('${(progress * 100).round()}% berpartisipasi',
                      style: Lx.metadata),
                ],
              ],
            ),
    );
  }

  // ── Jimpitan ─────────────────────────────────────────────────────────────

  Widget _jimpitan(RingkasanSection<RingkasanJimpitan> s) {
    final j = s.data;
    final items = j?.items ?? const <RingkasanJimpitanItem>[];
    final shown = _allJimpitan ? items : items.take(_jimpitanRows).toList();
    return SectionCard(
      title: 'Jimpitan',
      subtitle: '${monthNames[_month.month - 1]} ${_month.year}',
      child: j == null
          ? _sectionError(s.error)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headline(rp(j.total)),
                const SizedBox(height: Lx.s12),
                Row(
                  children: [
                    _stat('Setoran', rp(j.setoranTotal)),
                    const SizedBox(width: Lx.s12),
                    _stat('Dicatat di kas', rp(j.kasTotal)),
                  ],
                ),
                if (j.contributors > 0) ...[
                  const SizedBox(height: Lx.s8),
                  Text('${j.contributors} catatan', style: Lx.metadata),
                ],
                if (items.isEmpty && j.total == 0)
                  Padding(
                    padding: const EdgeInsets.only(top: Lx.s12),
                    child: Text('Belum ada jimpitan di bulan ini.',
                        style: Lx.metadata),
                  ),
                for (final i in shown) _jimpitanRow(i),
                if (items.length > _jimpitanRows)
                  TextButton(
                    onPressed: () =>
                        setState(() => _allJimpitan = !_allJimpitan),
                    child: Text(_allJimpitan
                        ? 'Ringkas'
                        : 'Lihat semua (${items.length})'),
                  ),
              ],
            ),
    );
  }

  Widget _jimpitanRow(RingkasanJimpitanItem i) => Padding(
        padding: const EdgeInsets.only(top: Lx.s12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(i.label.isEmpty ? 'Jimpitan' : i.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Lx.body.copyWith(color: Lx.text)),
                  Text(
                      [
                        i.isSetoran ? 'Setoran' : 'Kas',
                        if (i.date != null) dateShort(i.date!),
                      ].join(' · '),
                      style: Lx.metadata),
                ],
              ),
            ),
            const SizedBox(width: Lx.s12),
            _amount(rp(i.amount)),
          ],
        ),
      );
}

/// A message for a failed call (no section data at all).
String ringkasanFailure(Object e) {
  if (e is DioException) {
    switch (e.response?.statusCode) {
      case 403:
        return 'Ringkasan tidak aktif untuk akun Anda.';
      case 500:
      case 502:
      case 503:
      case 504:
        return 'Layanan sedang tidak tersedia. Coba lagi.';
    }
    if (e.response == null) {
      return 'Tidak bisa terhubung ke server. Periksa koneksi Anda.';
    }
  }
  return 'Data belum bisa dimuat. Coba lagi.';
}

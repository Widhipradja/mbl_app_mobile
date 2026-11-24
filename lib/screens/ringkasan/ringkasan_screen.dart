import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import '../../widgets/app_ui.dart';
import '../finance/finance_data.dart' show dateShort, rp;
import '../savings/ledger_widgets.dart' show monthNames;
import 'ringkasan_data.dart';

typedef RingkasanLoader = Future<RingkasanData> Function(String month);

/// Ringkasan: the community's numbers on the phone, in the look of the other
/// modules (a gradient balance card, then white section cards). Saldo Kas and
/// Keanggotaan are as of today; the month stepper under them drives Shodaqoh
/// Bulanan and Jimpitan only. Each card fails on its own (the server answers
/// `{data}` or `{error}` per section); Saldo Kas is left out when the module
/// gate for money is closed for this account.
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

  /// The month [_data] was loaded for: while another month loads, only the
  /// monthly cards wait.
  DateTime? _dataMonth;
  bool _loading = true;

  /// Nothing could be shown at all.
  String? _error;

  /// Another month failed while something is on screen: Saldo Kas and
  /// Keanggotaan stay, the monthly cards offer a retry.
  String? _monthError;
  bool _allJimpitan = false;

  static const _recentRows = 4;
  static const _jimpitanRows = 5;

  static const _maleColor = Color(0xFF2563EB);
  static const _femaleColor = Color(0xFFDB2777);

  @override
  void initState() {
    super.initState();
    _load();
  }

  static String _key(DateTime m) =>
      '${m.year}-${m.month.toString().padLeft(2, '0')}';

  String get _monthLabel => '${monthNames[_month.month - 1]} ${_month.year}';

  Future<void> _load() async {
    final month = _month;
    setState(() {
      _loading = true;
      _error = null;
      _monthError = null;
    });
    try {
      final data = await widget.loader(_key(month));
      if (!mounted || month != _month) return;
      setState(() {
        _data = data;
        _dataMonth = month;
      });
    } catch (e) {
      debugPrint('Ringkasan load error: $e');
      if (mounted && month == _month) {
        setState(() {
          if (_data == null) {
            _error = ringkasanFailure(e);
          } else {
            _monthError = ringkasanFailure(e);
          }
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
            padding: const EdgeInsets.fromLTRB(Lx.s16, 0, Lx.s16, Lx.s24),
            children: [
              _intro(),
              if (d == null && _loading)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (d == null)
                RetryState(_error ?? 'Data belum bisa dimuat.', onRetry: _load)
              else ...[
                ..._finance(d.finance),
                _members(d.members),
                _monthHeader(),
                ..._monthly(d),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared pieces ────────────────────────────────────────────────────────

  Widget _intro() => Padding(
        padding: const EdgeInsets.only(top: Lx.s8, bottom: Lx.s12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.groups_outlined,
                  size: 15, color: Lx.textSecondary),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Angka komunitas dalam satu layar. Saldo kas dan keanggotaan '
                'per hari ini; shodaqoh dan jimpitan per bulan yang dipilih.',
                style: Lx.metadata.copyWith(height: 1.4),
              ),
            ),
          ],
        ),
      );

  Widget _sectionError(String? code) {
    final retry = code == 'timeout' || code == 'unavailable' || code == null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Lx.s8),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 28, color: Lx.textMuted),
          const SizedBox(height: Lx.s8),
          Text(ringkasanErrorText(code),
              textAlign: TextAlign.center, style: Lx.metadata),
          if (retry)
            TextButton(onPressed: _load, child: const Text('Coba lagi')),
        ],
      ),
    );
  }

  /// The big number of a white card.
  Widget _headline(String text, {String? caption}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(text,
                maxLines: 1,
                style:
                    Lx.userName.copyWith(fontSize: 26, fontFeatures: tabular)),
          ),
          if (caption != null) Text(caption, style: Lx.metadata),
        ],
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

  /// A figure on a pale tile: icon, label, value.
  Widget _tile(
          IconData icon, String label, String value, Color color, Color tint) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(Lx.s12),
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(Lx.rButton),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    maxLines: 1,
                    style: Lx.cardHeading
                        .copyWith(fontSize: 16, fontFeatures: tabular)),
              ),
              // Shrinks rather than cut "Baru bulan ini" on a narrow phone.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(label, maxLines: 1, style: Lx.metadata),
              ),
            ],
          ),
        ),
      );

  /// A row of a list: an icon on its colour, two lines of text, an amount.
  Widget _row({
    required Widget leading,
    required String title,
    String? subtitle,
    required Widget trailing,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            leading,
            const SizedBox(width: Lx.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Lx.cardHeading.copyWith(fontSize: 14)),
                  if (subtitle != null && subtitle.isNotEmpty)
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Lx.metadata),
                ],
              ),
            ),
            const SizedBox(width: Lx.s8),
            trailing,
          ],
        ),
      );

  Widget _iconBox(IconData icon, Color color, Color tint) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: tint, borderRadius: BorderRadius.circular(12.8)),
        child: Icon(icon, size: 20, color: color),
      );

  // ── Saldo Kas ────────────────────────────────────────────────────────────

  List<Widget> _finance(RingkasanSection<RingkasanFinance> s) {
    if (s.forbidden) return const [];
    final f = s.data;
    if (f == null) {
      return [SectionCard(title: 'Saldo Kas', child: _sectionError(s.error))];
    }
    final recent = f.recent.take(_recentRows).toList();
    final funds = f.funds?.items ?? const <RingkasanFund>[];
    return [
      _balance(f),
      const SizedBox(height: Lx.s12),
      if (recent.isNotEmpty)
        SectionCard(
          title: 'Transaksi terbaru',
          padding: const EdgeInsets.fromLTRB(Lx.s16, Lx.s16, Lx.s16, Lx.s8),
          child: Column(children: [for (final t in recent) _trxRow(t)]),
        ),
      if (funds.isNotEmpty)
        _funds(f.funds!)
      else if (f.fundsError != null && f.fundsError != 'forbidden')
        SectionCard(
          title: 'Dana per kategori',
          child:
              Text('Dana per kategori belum bisa dimuat.', style: Lx.metadata),
        ),
    ];
  }

  /// The gradient card every money module opens with.
  Widget _balance(RingkasanFinance f) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Lx.s20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Lx.rSection),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Lx.bannerStart, Lx.primary],
          ),
          boxShadow: Lx.shadowSoft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Saldo Kas',
                      style: Lx.metadata.copyWith(color: Colors.white70)),
                ),
                if (f.asOf != null)
                  Text('Per ${dateShort(f.asOf!)}',
                      style: Lx.metadata.copyWith(color: Colors.white70)),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(rp(f.balance),
                  style: Lx.userName.copyWith(
                      color: Colors.white,
                      fontSize: 30,
                      fontFeatures: tabular)),
            ),
            const SizedBox(height: Lx.s16),
            // finance-hub counts these over the current calendar month,
            // whatever month is picked below.
            Text('Bulan ini',
                style: Lx.metadata.copyWith(color: Colors.white70)),
            const SizedBox(height: 6),
            Row(
              children: [
                _flow('Pemasukan', f.income, Icons.south_west_rounded,
                    const Color(0xFFBBF7D0)),
                const SizedBox(width: Lx.s12),
                _flow('Pengeluaran', f.expense, Icons.north_east_rounded,
                    const Color(0xFFFECACA)),
              ],
            ),
          ],
        ),
      );

  Widget _flow(String label, int v, IconData icon, Color accent) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(Lx.s12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(Lx.rButton),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: accent),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Lx.metadata.copyWith(color: Colors.white70)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(rp(v),
                    style: Lx.cardHeading
                        .copyWith(color: Colors.white, fontFeatures: tabular)),
              ),
            ],
          ),
        ),
      );

  Widget _trxRow(RingkasanTrx t) {
    final bool? income = t.isIncome ? true : (t.isExpense ? false : null);
    final title = t.description.isEmpty ? 'Transaksi' : t.description;
    return _row(
      leading: CategoryAvatar(title, income: income),
      title: title,
      subtitle: t.date == null ? null : dateShort(t.date!),
      trailing: _amount(signedRp(t.amount, income), color: moneyColor(income)),
    );
  }

  Widget _funds(RingkasanFunds funds) {
    final total = funds.totalBalance > 0
        ? funds.totalBalance
        : funds.items
            .fold<int>(0, (a, f) => a + (f.balance > 0 ? f.balance : 0));
    return SectionCard(
      title: 'Dana per kategori',
      subtitle: funds.asOf == null
          ? 'Saldo sampai hari ini'
          : 'Saldo sampai ${dateShort(funds.asOf!)}',
      padding: const EdgeInsets.fromLTRB(Lx.s16, Lx.s16, Lx.s16, Lx.s8),
      child: Column(
        children: [
          for (final f in funds.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Lx.s8),
              child: Row(
                children: [
                  CategoryAvatar(f.name.isEmpty ? f.key : f.name,
                      income: true, size: 36),
                  const SizedBox(width: Lx.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(f.name.isEmpty ? f.key : f.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Lx.cardHeading.copyWith(fontSize: 14)),
                            ),
                            const SizedBox(width: Lx.s8),
                            _amount(rp(f.balance)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        RoundBar(
                          value: total <= 0 || f.balance <= 0
                              ? 0
                              : f.balance / total,
                          color: categoryLook(f.name.isEmpty ? f.key : f.name,
                                  income: true)
                              .color,
                          height: 6,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Keanggotaan ──────────────────────────────────────────────────────────

  Widget _members(RingkasanSection<RingkasanMembers> s) {
    final m = s.data;
    return SectionCard(
      title: 'Keanggotaan',
      subtitle: m == null ? null : 'Per hari ini',
      child: m == null
          ? _sectionError(s.error)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headline('${m.total}', caption: 'anggota terdaftar'),
                const SizedBox(height: Lx.s12),
                Row(
                  children: [
                    _tile(Icons.how_to_reg_rounded, 'Aktif', '${m.active}',
                        Lx.success, const Color(0xFFDCFCE7)),
                    const SizedBox(width: Lx.s8),
                    _tile(Icons.person_add_alt_1_rounded, 'Baru bulan ini',
                        '${m.newThisMonth}', Lx.primary, Lx.primaryLight),
                    const SizedBox(width: Lx.s8),
                    _tile(Icons.family_restroom_rounded, 'Keluarga',
                        '${m.families}', Lx.secondary, Lx.secondaryLight),
                  ],
                ),
                if (m.male + m.female > 0) ...[
                  const SizedBox(height: Lx.s16),
                  _genderBar(m.male, m.female),
                ],
                if (m.ageGroups.isNotEmpty) ...[
                  const SizedBox(height: Lx.s16),
                  Text('Kelompok usia', style: Lx.cardHeading),
                  const SizedBox(height: 4),
                  for (final g in m.ageGroups) _ageRow(g, m.ageGroups),
                ],
              ],
            ),
    );
  }

  Widget _genderBar(int male, int female) {
    final total = male + female;
    Widget part(int v, Color c) => v <= 0
        ? const SizedBox.shrink()
        : Expanded(
            flex: (v * 1000 / total).round().clamp(1, 1000),
            child: Container(color: c),
          );
    Widget legend(String label, int v, Color c) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: c, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 6),
            Text('$label $v (${(v * 100 / total).round()}%)',
                style: Lx.metadata.copyWith(color: Lx.text)),
          ],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Jenis kelamin', style: Lx.cardHeading),
        const SizedBox(height: Lx.s8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(children: [
              part(male, _maleColor),
              part(female, _femaleColor),
            ]),
          ),
        ),
        const SizedBox(height: Lx.s8),
        // Side by side, or one under the other when they do not fit.
        Wrap(
          spacing: Lx.s16,
          runSpacing: 4,
          children: [
            legend('Laki-laki', male, _maleColor),
            legend('Perempuan', female, _femaleColor),
          ],
        ),
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
                color: Lx.secondary,
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

  // ── Per month ────────────────────────────────────────────────────────────

  /// Where the monthly part starts: what the stepper below drives.
  Widget _monthHeader() => Padding(
        padding: const EdgeInsets.only(top: Lx.s8, bottom: Lx.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: Lx.s4, bottom: Lx.s8),
              child: Text('Bulanan', style: Lx.sectionHeading),
            ),
            MonthPill(month: _month, onChanged: _setMonth),
          ],
        ),
      );

  List<Widget> _monthly(RingkasanData d) {
    if (_monthError != null) {
      return [RetryState(_monthError!, onRetry: _load)];
    }
    if (_loading && _dataMonth != _month) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    return [_shodaqoh(d.shodaqoh), _jimpitan(d.jimpitan)];
  }

  // ── Shodaqoh Bulanan ─────────────────────────────────────────────────────

  Widget _shodaqoh(RingkasanSection<RingkasanShodaqoh> s) {
    final d = s.data;
    final progress = d == null || d.totalMembers <= 0
        ? 0.0
        : (d.participants / d.totalMembers).clamp(0.0, 1.0).toDouble();
    return SectionCard(
      title: 'Shodaqoh Bulanan',
      subtitle: _monthLabel,
      child: d == null
          ? _sectionError(s.error)
          : Row(
              children: [
                _ring(progress, d.totalMembers > 0),
                const SizedBox(width: Lx.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                            d.totalMembers > 0
                                ? '${d.participants} dari ${d.totalMembers} anggota'
                                : '${d.participants} anggota',
                            maxLines: 1,
                            style: Lx.cardHeading.copyWith(fontSize: 16)),
                      ),
                      const SizedBox(height: 2),
                      Text('sudah bershodaqoh bulan ini', style: Lx.metadata),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  /// The share of members who gave, as a ring with the percent inside.
  Widget _ring(double progress, bool known) => SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: known ? progress : 0,
                strokeWidth: 7,
                backgroundColor: const Color(0xFFDCFCE7),
                color: Lx.success,
                strokeCap: StrokeCap.round,
              ),
            ),
            Text(known ? '${(progress * 100).round()}%' : '–',
                style: Lx.cardHeading
                    .copyWith(fontSize: 14, fontFeatures: tabular)),
          ],
        ),
      );

  // ── Jimpitan ─────────────────────────────────────────────────────────────

  Widget _jimpitan(RingkasanSection<RingkasanJimpitan> s) {
    final j = s.data;
    final items = j?.items ?? const <RingkasanJimpitanItem>[];
    final shown = _allJimpitan ? items : items.take(_jimpitanRows).toList();
    return SectionCard(
      title: 'Jimpitan',
      subtitle: _monthLabel,
      padding: const EdgeInsets.fromLTRB(Lx.s16, Lx.s16, Lx.s16, Lx.s8),
      child: j == null
          ? _sectionError(s.error)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headline(rp(j.total),
                    caption: j.contributors > 0
                        ? 'dari ${j.contributors} catatan'
                        : null),
                const SizedBox(height: Lx.s12),
                Row(
                  children: [
                    _tile(
                        Icons.volunteer_activism_rounded,
                        'Setoran',
                        rp(j.setoranTotal),
                        Lx.success,
                        const Color(0xFFDCFCE7)),
                    const SizedBox(width: Lx.s8),
                    _tile(Icons.receipt_long_rounded, 'Dicatat di kas',
                        rp(j.kasTotal), Lx.primary, Lx.primaryLight),
                  ],
                ),
                if (items.isEmpty && j.total == 0)
                  const EmptyState(
                    icon: Icons.inbox_outlined,
                    text: 'Belum ada jimpitan di bulan ini.',
                  )
                else ...[
                  const SizedBox(height: Lx.s8),
                  for (final i in shown) _jimpitanRow(i),
                ],
                if (items.length > _jimpitanRows)
                  Center(
                    child: TextButton(
                      onPressed: () =>
                          setState(() => _allJimpitan = !_allJimpitan),
                      child: Text(_allJimpitan
                          ? 'Ringkas'
                          : 'Lihat semua (${items.length})'),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _jimpitanRow(RingkasanJimpitanItem i) => _row(
        leading: i.isSetoran
            ? _iconBox(Icons.volunteer_activism_rounded, Lx.success,
                const Color(0xFFDCFCE7))
            : _iconBox(Icons.receipt_long_rounded, Lx.primary, Lx.primaryLight),
        title: i.label.isEmpty ? 'Jimpitan' : i.label,
        subtitle: [
          // "Setoran · 20 Nov" under a row titled "Setoran" says it twice.
          if (i.label.toLowerCase() != (i.isSetoran ? 'setoran' : 'kas'))
            i.isSetoran ? 'Setoran' : 'Kas',
          if (i.date != null) dateShort(i.date!),
        ].join(' · '),
        trailing: _amount(signedRp(i.amount, true), color: Lx.success),
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

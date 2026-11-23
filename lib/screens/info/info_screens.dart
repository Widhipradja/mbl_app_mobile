import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../config/baraka_tokens.dart';
import '../../providers/home_summary_provider.dart';
import '../launcher/launcher_models.dart'
    show
        CampaignInfo,
        Contribution,
        Donation,
        rupiahOfDecimal,
        sumDecimals;
import '../../services/api_service.dart';
import 'donation_form_screen.dart';

// Read-only detail screens behind the home "Ringkasan" cards. Data comes from
// the mobile gateway (`/api/m/v1/*`); payloads are read defensively.

// ── Shared helpers ──────────────────────────────────────────────────────────

const _monthNames = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', //
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

String _monthParam(DateTime m) =>
    '${m.year}-${m.month.toString().padLeft(2, '0')}';

String _monthLabel(DateTime m) => '${_monthNames[m.month - 1]} ${m.year}';

List<Map<String, dynamic>> _list(dynamic raw, [List<String> keys = const []]) {
  dynamic src = raw;
  if (src is Map<String, dynamic>) {
    for (final k in ['data', ...keys]) {
      if (src is Map<String, dynamic> && src[k] is List) {
        src = src[k];
        break;
      }
      if (src is Map<String, dynamic> && src[k] is Map<String, dynamic>) {
        src = src[k];
      }
    }
  }
  if (src is List) return src.whereType<Map<String, dynamic>>().toList();
  return const [];
}

Map<String, dynamic> _object(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    final inner = raw['data'];
    return inner is Map<String, dynamic> ? inner : raw;
  }
  return const {};
}

double _num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

String _text(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k]?.toString().trim() ?? '';
    if (v.isNotEmpty) return v;
  }
  return '';
}

String _rupiah(double v) {
  final s = v.abs().round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}Rp $b';
}

String _shortDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.day} ${_monthNames[d.month - 1].substring(0, 3)}';
}

String _failure(Object e) {
  if (e is DioException) {
    switch (e.response?.statusCode) {
      case 503:
        return 'Layanan ini belum dikonfigurasi di server.';
      case 504:
        return 'Server terlalu lama menjawab. Coba lagi.';
    }
  }
  return 'Data gagal dimuat. Tarik ke bawah untuk mencoba lagi.';
}

/// Page frame: title, optional month switcher, pull-to-refresh and the
/// loading / error / empty states.
class _InfoPage extends StatelessWidget {
  const _InfoPage({
    required this.title,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.children,
    this.emptyText,
    this.month,
    this.onMonthChanged,
  });

  final String title;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final List<Widget> children;
  final String? emptyText;
  final DateTime? month;
  final ValueChanged<DateTime>? onMonthChanged;

  @override
  Widget build(BuildContext context) {
    final m = month;
    return Scaffold(
      backgroundColor: Bk.ground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Bk.text,
        elevation: 0,
        centerTitle: false,
        title: Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          if (m != null)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Bulan sebelumnya',
                    onPressed: () =>
                        onMonthChanged?.call(DateTime(m.year, m.month - 1)),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      _monthLabel(m),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Bulan berikutnya',
                    onPressed: () =>
                        onMonthChanged?.call(DateTime(m.year, m.month + 1)),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              color: Bk.brand,
              onRefresh: onRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(
                        child: CircularProgressIndicator(color: Bk.brand),
                      ),
                    )
                  else if (error != null)
                    _notice(error!)
                  else if (children.isEmpty)
                    _notice(emptyText ?? 'Belum ada data.')
                  else
                    ...children,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notice(String text) => Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Bk.textMuted, fontSize: 14),
        ),
      );
}

Widget _tile({required List<Widget> children}) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: Bk.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );

const _titleStyle =
    TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Bk.text);
const _mutedStyle = TextStyle(fontSize: 12, color: Bk.textMuted, height: 1.4);

// ── Jimpitan ────────────────────────────────────────────────────────────────

class JimpitanScreen extends StatefulWidget {
  const JimpitanScreen({super.key});

  @override
  State<JimpitanScreen> createState() => _JimpitanScreenState();
}

class _JimpitanScreenState extends State<JimpitanScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _summary = const {};
  List<Map<String, dynamic>> _transactions = const [];
  bool _transactionsFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final month = _month;
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = ApiService();
    final param = _monthParam(month);

    // The two parts load independently: one failing keeps the other.
    Map<String, dynamic>? summary;
    Object? summaryError;
    List<Map<String, dynamic>>? transactions;
    await Future.wait([
      api.getMobileJimpitan(param).then<void>((r) {
        summary = _object(r.data);
      }).catchError((Object e) {
        summaryError = e;
      }),
      api.getMobileJimpitanTransactions(param).then<void>((r) {
        // Newest first; ISO dates sort correctly as text.
        transactions = _list(r.data, ['transactions'])
          ..sort((a, b) => _text(b, ['requested_date', 'date'])
              .compareTo(_text(a, ['requested_date', 'date'])));
      }).catchError((Object _) {}),
    ]);

    if (!mounted || month != _month) return;
    // Total missing or 0 although transactions were recorded: add them up.
    final sum = transactions == null
        ? 0.0
        : HomeSummaryProvider.jimpitanTransactionsTotal(transactions);
    if (sum > 0 && _num(summary?['total']) == 0) {
      summary = {...?summary, 'total': sum};
    }
    setState(() {
      _loading = false;
      _summary = summary ?? const {};
      _transactions = transactions ?? const [];
      _transactionsFailed = transactions == null;
      _error = (summary == null && transactions == null)
          ? _failure(summaryError ?? '')
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final contributors = _num(_summary['contributors']).round();
    final late = _num(_summary['late_count']).round();

    return _InfoPage(
      title: 'Jimpitan',
      loading: _loading,
      error: _error,
      onRefresh: _load,
      month: _month,
      onMonthChanged: (m) {
        setState(() => _month = m);
        _load();
      },
      children: [
        _tile(children: [
          const Text('Total bulan ini', style: _mutedStyle),
          const SizedBox(height: 4),
          Text(
            _summary.isEmpty ? '—' : _rupiah(_num(_summary['total'])),
            style: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.w700, color: Bk.text),
          ),
          if (contributors > 0 || late > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                [
                  if (contributors > 0) '$contributors penyetor',
                  if (late > 0) '$late terlambat',
                ].join(' · '),
                style: _mutedStyle,
              ),
            ),
        ]),
        const Padding(
          padding: EdgeInsets.fromLTRB(2, 10, 2, 8),
          child: Text('Transaksi tercatat', style: _titleStyle),
        ),
        if (_transactionsFailed)
          const Text('Daftar transaksi gagal dimuat.', style: _mutedStyle)
        else if (_transactions.isEmpty)
          const Text('Belum ada transaksi di bulan ini.', style: _mutedStyle)
        else
          Container(
            decoration: Bk.card(),
            child: Column(
              children: [
                for (var i = 0; i < _transactions.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: Bk.line),
                  _trxRow(_transactions[i]),
                ],
              ],
            ),
          ),
        if (_transactions.any((t) => t['is_setoran_recap'] == true))
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Baris "Rekap setoran" sudah termasuk di total di atas.',
              style: _mutedStyle,
            ),
          ),
      ],
    );
  }

  Widget _trxRow(Map<String, dynamic> t) {
    final desc = _text(t, ['description']);
    final date = _text(t, ['requested_date', 'date']);
    final recap = t['is_setoran_recap'] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  desc.isEmpty ? 'Jimpitan' : desc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  [
                    if (date.isNotEmpty) _shortDate(date),
                    if (recap) 'Rekap setoran',
                  ].join(' · '),
                  style: _mutedStyle,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _rupiah(_num(t['amount'])),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ── Penggalangan dana ───────────────────────────────────────────────────────

class FundraisingScreen extends StatefulWidget {
  const FundraisingScreen({super.key, this.fetch, this.donate});

  /// Opens the donation form and returns how it ended. Defaults to the form
  /// itself; tests pass their own.
  final Future<DonationResult?> Function(
    BuildContext context, {
    required String campaignId,
    required String campaignTitle,
    required bool again,
  })? donate;

  /// Returns the `/fundraising` body. Defaults to the API; tests pass their
  /// own.
  final Future<dynamic> Function()? fetch;

  @override
  State<FundraisingScreen> createState() => _FundraisingScreenState();
}

class _FundraisingScreenState extends State<FundraisingScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _campaigns = const [];

  /// `contribution_available` of the last answer. False: the member's
  /// contributions could not be read, so "no contribution" means unknown.
  bool? _contributionAvailable;

  /// `donations_available` of the last answer. False: the donations (pending
  /// and rejected) could not be read. Null: the server does not send them.
  bool? _donationsAvailable;

  /// Cards whose "Sumbangan Anda" details are open, by position.
  final _open = <int>{};

  /// What was sent to each campaign during this visit and still waits for
  /// approval, in rupiah. The server does not list pending donations, so this
  /// is not kept.
  final _awaiting = <String, BigInt>{};

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
    try {
      final fetch = widget.fetch;
      final body = fetch != null
          ? await fetch()
          : (await ApiService().getMobileFundraising()).data;
      if (!mounted) return;
      setState(() {
        _open.clear();
        _campaigns = HomeSummaryProvider.campaignsOf(body);
        _contributionAvailable = CampaignInfo.contributionAvailableOf(body);
        _donationsAvailable = CampaignInfo.donationsAvailableOf(body);
        // The server's list is the truth once it sends one; what was kept
        // here for this visit is only for a server that does not.
        if (_donationsAvailable == true) _awaiting.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _campaigns = const [];
        _error = _failure(e);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final given = [
      for (final c in _campaigns) Contribution.parse(c['contribution']),
    ];
    final mine = given.whereType<Contribution>().toList();

    return _InfoPage(
      title: 'Penggalangan Dana',
      loading: _loading,
      error: _error,
      onRefresh: _load,
      emptyText: 'Belum ada penggalangan dana aktif.',
      children: [
        if (mine.isNotEmpty)
          _thanks(
            joined: mine.length,
            total: _campaigns.length,
            sum: sumDecimals(mine.map((c) => c.totalGiven)),
          ),
        if (_campaigns.isNotEmpty && _donationsAvailable == false)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
                'Status donasi yang menunggu verifikasi belum tersedia.',
                style: _mutedStyle),
          ),
        // Not "Belum ikut": with no contribution data, that would be a guess.
        if (_campaigns.isNotEmpty && _contributionAvailable == false)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Riwayat sumbangan Anda belum tersedia.',
                style: _mutedStyle),
          ),
        for (var i = 0; i < _campaigns.length; i++)
          _campaignCard(i, _campaigns[i], given[i]),
      ],
    );
  }

  /// One line of thanks for a member who has given: how many campaigns and
  /// how much in total.
  Widget _thanks(
      {required int joined, required int total, required String sum}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Bk.brandDark,
        borderRadius: BorderRadius.circular(Bk.radiusCard),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_rounded,
                size: 20, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Terima kasih! ${rupiahOfDecimal(sum)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800),
                ),
                Text(
                  'Sumbangan Anda di $joined dari $total penggalangan dana',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 12,
                      height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Small round heart: the mark for a campaign the member has given to.
  Widget _donorMark() => Tooltip(
        message: 'Anda sudah berdonasi',
        child: Semantics(
          label: 'Sudah berdonasi',
          child: Container(
            width: 22,
            height: 22,
            decoration:
                const BoxDecoration(color: Bk.brand, shape: BoxShape.circle),
            child: const Icon(Icons.favorite_rounded,
                size: 12, color: Colors.white),
          ),
        ),
      );

  /// A donation was sent and waits for the treasurer: the amber twin of the
  /// green "given" pill, an hourglass and the amount, under it in the same
  /// list. With no contribution yet it is the only line.
  Widget _pendingRow(String amount) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Tooltip(
            message: 'Menunggu verifikasi bendahara',
            child: Semantics(
              label: 'Menunggu verifikasi: ${rupiahOfDecimal(amount)}',
              excludeSemantics: true,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Bk.pendingBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hourglass_top_rounded,
                        size: 13, color: Bk.pendingFg),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        rupiahOfDecimal(amount),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Bk.pendingFg),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  /// A donation the treasurer turned down: a red mark and the amount, and
  /// the reason under it, so the donor knows what to fix.
  Widget _rejectedRow(Donation d) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: 'Ditolak: ${rupiahOfDecimal(d.amount)}',
              excludeSemantics: true,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3F2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 13, color: Bk.danger),
                    const SizedBox(width: 4),
                    Text(
                      rupiahOfDecimal(d.amount),
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Bk.danger),
                    ),
                  ],
                ),
              ),
            ),
            if (d.reason.isNotEmpty || d.decidedDate.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 4),
                child: Text(
                  [
                    if (d.decidedDate.isNotEmpty) 'Ditolak ${d.decidedDate}',
                    if (d.reason.isNotEmpty) d.reason,
                  ].join(' · '),
                  style: const TextStyle(
                      fontSize: 12, color: Bk.danger, height: 1.4),
                ),
              ),
          ],
        ),
      );

  /// The donation lines under the member's total: what waits for the
  /// treasurer (from the server, or for this visit when it sends none), then
  /// each one turned down.
  List<Widget> _donationRows(Map<String, dynamic> c) {
    final fromServer = _donationsAvailable == true;
    final donations = fromServer ? Donation.listOf(c) : const <Donation>[];
    final waiting = fromServer
        ? sumDecimals(donations.where((d) => d.isPending).map((d) => d.amount))
        : (_awaiting[_text(c, ['id'])]?.toString() ?? '0');
    final hasWaiting = fromServer
        ? donations.any((d) => d.isPending)
        : _awaiting.containsKey(_text(c, ['id']));
    return [
      if (hasWaiting) _pendingRow(waiting),
      for (final d in donations.where((d) => d.isRejected)) _rejectedRow(d),
    ];
  }

  /// A campaign, kept short: title, two lines of description, progress. For
  /// one the member has given to, a heart mark and their total; the payments
  /// open on tap.
  Widget _campaignCard(int i, Map<String, dynamic> c, Contribution? mine) {
    final target = _num(c['target']);
    final collected = _num(c['collected']);
    var percent = _num(c['progress_percent']);
    if (percent == 0 && target > 0) percent = collected / target * 100;
    final desc = _text(c, ['description']);
    final open = _open.contains(i);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Bk.radiusCard),
          side: BorderSide(color: mine != null ? Bk.brand : Bk.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: mine == null
              ? null
              : () => setState(() => open ? _open.remove(i) : _open.add(i)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child:
                          Text(_text(c, ['title', 'name']), style: _titleStyle),
                    ),
                    if (mine != null) ...[
                      const SizedBox(width: 8),
                      _donorMark(),
                    ],
                  ],
                ),
                if (desc.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _mutedStyle),
                  ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: (percent / 100).clamp(0.0, 1.0).toDouble(),
                    minHeight: 8,
                    backgroundColor: Bk.brandSoft,
                    valueColor: const AlwaysStoppedAnimation(Bk.brand),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${rupiahOfDecimal(_text(c, ['collected']))} dari '
                        '${rupiahOfDecimal(_text(c, ['target']))}',
                        style: const TextStyle(fontSize: 13, color: Bk.text),
                      ),
                    ),
                    Text(
                      '${percent.round()}%',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Bk.brand),
                    ),
                  ],
                ),
                if (mine != null) const SizedBox(height: 10),
                if (mine != null)
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Bk.doneBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.favorite_rounded,
                                  size: 13, color: Bk.doneFg),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  rupiahOfDecimal(mine.totalGiven),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Bk.doneFg),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(open ? 'Tutup' : 'Rincian', style: _mutedStyle),
                      Icon(
                        open
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 20,
                        color: Bk.textMuted,
                      ),
                    ],
                  ),
                ..._donationRows(c),
                if (mine != null) ...[
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 180),
                    crossFadeState: open
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: const SizedBox(width: double.infinity),
                    secondChild: _contributionDetails(mine),
                  ),
                ],
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: _donateButton(c, again: mine != null),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Opens the donation form for a campaign; the list reloads once a
  /// donation has been sent, so the new contribution shows.
  Future<void> _donate(Map<String, dynamic> c, {required bool again}) async {
    final id = _text(c, ['id']);
    final title = _text(c, ['title', 'name']);
    final navigator = Navigator.of(context);
    final open = widget.donate;
    final Future<DonationResult?> form = open != null
        ? open(context, campaignId: id, campaignTitle: title, again: again)
        : navigator.push<DonationResult>(
            MaterialPageRoute(
              builder: (_) => DonationFormScreen(
                campaignId: id,
                campaignTitle: title,
                again: again,
              ),
            ),
          );
    final result = await form;
    if (result == null || !mounted) return;
    final pending = result.outcome == DonationOutcome.pending;
    // The list only changes once the treasurer approves it, so say so, and
    // show what was sent under the member's total for this visit.
    if (pending) {
      final sent = BigInt.tryParse(result.amount) ?? BigInt.zero;
      setState(() => _awaiting[id] = (_awaiting[id] ?? BigInt.zero) + sent);
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(pending
          ? 'Donasi terkirim. Menunggu verifikasi bendahara.'
          : 'Donasi ini sudah disetujui. Terima kasih!'),
    ));
    _load();
  }

  Widget _donateButton(Map<String, dynamic> c, {required bool again}) {
    return Material(
      color: Bk.brand,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: () => _donate(c, again: again),
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.volunteer_activism_rounded,
                  size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                again ? 'Berdonasi Lagi' : 'Ikut Berdonasi',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The member's payments to one campaign (newest first), with how many and
  /// the last date. Dates are shown as they come (`YYYY-MM-DD`).
  Widget _contributionDetails(Contribution c) {
    final sub = [
      if (c.paymentCount > 0) '${c.paymentCount} kali',
      if (c.lastPaidDate.isNotEmpty) 'terakhir ${c.lastPaidDate}',
    ].join(' · ');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Bk.brandSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sub.isEmpty ? 'Sumbangan Anda' : 'Sumbangan Anda · $sub',
              style: _mutedStyle),
          for (final p in c.payments)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(child: Text(p.date, style: _mutedStyle)),
                  Text(
                    rupiahOfDecimal(p.amount),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Bk.text),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

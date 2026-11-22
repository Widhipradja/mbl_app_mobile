import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/home_summary_provider.dart';

/// "Ringkasan" cards for the home page. Every card loads and fails on its own,
/// so one unavailable service never hides the others.
class HomeSummarySection extends StatefulWidget {
  const HomeSummarySection({super.key, required this.showFinance});

  /// Treasurer roles (Administrator, KI, KU) also see the cash balance.
  final bool showFinance;

  @override
  State<HomeSummarySection> createState() => _HomeSummarySectionState();
}

class _HomeSummarySectionState extends State<HomeSummarySection> {
  static const _green = Color(0xFF066046);
  static const _muted = Color(0xFF5B6B65);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = context.read<HomeSummaryProvider>();
      // Also refreshes when coming back from a module after a while.
      if (p.isStale()) p.load();
    });
  }

  // ── Parsing helpers (the gateway payloads are read defensively) ───────────

  Map<String, dynamic> _map(dynamic v) =>
      v is Map<String, dynamic> ? v : const <String, dynamic>{};

  double _num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  String _str(Map<String, dynamic> m, List<String> keys) {
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

  String _date(String iso) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', //
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final now = DateTime.now();
    final days = DateTime(d.year, d.month, d.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    if (days == 0) return 'Hari ini';
    if (days == 1) return 'Besok';
    return '${d.day} ${months[d.month - 1]}';
  }

  /// "19:30:00" → "19:30".
  String _time(String t) {
    final parts = t.split(':');
    return parts.length >= 2 ? '${parts[0]}:${parts[1]}' : t;
  }

  String _errorText(String code) {
    switch (code) {
      case 'not_configured':
        return 'Belum dikonfigurasi di server';
      case 'timeout':
        return 'Server terlalu lama menjawab';
      default:
        return 'Gagal dimuat';
    }
  }

  // ── Card pieces ──────────────────────────────────────────────────────────

  Widget _card({
    required IconData icon,
    required String title,
    required HomeSection section,
    required Widget Function(dynamic data) builder,
    String emptyText = 'Belum ada data',
    VoidCallback? onTap,
  }) {
    Widget body;
    if (section.loading) {
      body = const Text('Memuat…', style: TextStyle(color: _muted));
    } else if (section.error != null) {
      body = Text(_errorText(section.error!),
          style: const TextStyle(color: _muted, fontSize: 13));
    } else if (!section.hasData) {
      body =
          Text(emptyText, style: const TextStyle(color: _muted, fontSize: 13));
    } else {
      body = builder(section.data);
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F2ED),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: _green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _muted)),
                    const SizedBox(height: 4),
                    body,
                  ],
                ),
              ),
              if (onTap != null)
                const Padding(
                  padding: EdgeInsets.only(left: 4, top: 8),
                  child: Icon(Icons.chevron_right_rounded,
                      size: 22, color: _muted),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headline(String text) => Text(text,
      style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F1F1A)));

  Widget _sub(String text) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(text,
            style: const TextStyle(fontSize: 12, color: _muted),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
      );

  Widget _eventBody(dynamic data) {
    final e = _map(data);
    final title = _str(e, ['title', 'name']);
    if (title.isEmpty) {
      return const Text('Tidak ada kegiatan terdekat',
          style: TextStyle(color: _muted, fontSize: 13));
    }
    final date = _str(e, ['start_date', 'date']);
    final time = _str(e, ['start_time', 'time']);
    final place = _str(e, ['location']);
    final when = [
      if (date.isNotEmpty) _date(date),
      if (time.isNotEmpty) _time(time),
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _headline(title),
        if (when.isNotEmpty || place.isNotEmpty)
          _sub([when, place].where((s) => s.isNotEmpty).join(' · ')),
      ],
    );
  }

  Widget _jimpitanBody(dynamic data) {
    final j = _map(data);
    final contributors = _num(j['contributors']).round();
    final late = _num(j['late_count']).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _headline(_rupiah(_num(j['total']))),
        if (contributors > 0 || late > 0)
          _sub([
            if (contributors > 0) '$contributors penyetor',
            if (late > 0) '$late terlambat',
          ].join(' · ')),
      ],
    );
  }

  Widget _fundraisingBody(dynamic data) {
    final campaigns = HomeSummaryProvider.campaignsOf(data);
    if (campaigns.isEmpty) {
      return const Text('Belum ada penggalangan dana aktif',
          style: TextStyle(color: _muted, fontSize: 13));
    }
    final first = campaigns.first;
    final title = _str(first, ['title', 'name']);
    var percent = _num(first['progress_percent']);
    if (percent == 0) {
      final target = _num(first['target']);
      if (target > 0) percent = _num(first['collected']) / target * 100;
    }
    final progress = (percent / 100).clamp(0.0, 1.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _headline(title.isEmpty ? 'Penggalangan dana' : title),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: const Color(0xFFE6F2ED),
            valueColor: const AlwaysStoppedAnimation(_green),
          ),
        ),
        _sub('${percent.round()}% terkumpul'
            '${campaigns.length > 1 ? ' · +${campaigns.length - 1} lainnya' : ''}'),
      ],
    );
  }

  Widget _shodaqohBody(dynamic data) {
    final s = _map(data);
    final n = _num(s['participation_count']).round();
    final total = _num(s['total_members']).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _headline(total > 0 ? '$n dari $total anggota' : '$n anggota'),
        _sub('sudah bershodaqoh bulan ini'),
      ],
    );
  }

  Widget _financeBody(dynamic data) {
    final f = _map(data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _headline(_rupiah(_num(f['net']))),
        _sub('Masuk ${_rupiah(_num(f['income']))} · '
            'Keluar ${_rupiah(_num(f['expense']))}'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<HomeSummaryProvider>();
    final cards = <_CardSpec>[
      if (p.isModuleVisible('events'))
        _CardSpec(
            Icons.event_outlined, 'Kegiatan terdekat', p.nextEvent, _eventBody,
            emptyText: 'Tidak ada kegiatan terdekat',
            onTap: () => context.push('/info/kegiatan')),
      if (p.isModuleVisible('jimpitan'))
        _CardSpec(Icons.volunteer_activism_outlined, 'Jimpitan bulan ini',
            p.jimpitan, _jimpitanBody,
            onTap: () => context.push('/info/jimpitan')),
      if (p.isModuleVisible('fundraising'))
        _CardSpec(Icons.savings_outlined, 'Penggalangan dana', p.fundraising,
            _fundraisingBody,
            onTap: () => context.push('/info/fundraising')),
      if (p.isModuleVisible('shodaqoh'))
        _CardSpec(Icons.favorite_border_rounded, 'Shodaqoh bulan ini',
            p.shodaqoh, _shodaqohBody),
      if (widget.showFinance && p.isModuleVisible('finance'))
        _CardSpec(Icons.account_balance_wallet_outlined, 'Saldo kas', p.finance,
            _financeBody,
            onTap: () => context.go('/finance')),
    ];
    final failed = cards.where((c) => c.section.error != null).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  p.orgName.isEmpty ? 'Ringkasan' : 'Ringkasan ${p.orgName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold)),
            ),
            IconButton(
              tooltip: 'Muat ulang',
              onPressed: p.isLoading
                  ? null
                  : p.load,
              icon: p.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.refresh_rounded, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Sections that failed are folded into one line so they don't push
        // the module grid down.
        for (final c in cards.where((c) => c.section.error == null)) ...[
          _card(
            icon: c.icon,
            title: c.title,
            section: c.section,
            builder: c.builder,
            emptyText: c.emptyText,
            onTap: c.onTap,
          ),
          const SizedBox(height: 10),
        ],
        if (failed.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Belum tersedia: '
              '${failed.map((c) => '${c.title} (${_errorText(c.section.error!).toLowerCase()})').join(', ')}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
      ],
    );
  }
}

class _CardSpec {
  const _CardSpec(
    this.icon,
    this.title,
    this.section,
    this.builder, {
    this.emptyText = 'Belum ada data',
    this.onTap,
  });

  final IconData icon;
  final String title;
  final HomeSection section;
  final Widget Function(dynamic data) builder;
  final String emptyText;
  final VoidCallback? onTap;
}

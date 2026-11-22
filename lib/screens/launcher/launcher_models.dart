import 'package:flutter/material.dart';

import '../../providers/home_summary_provider.dart';

// ── Defensive parsing (gateway payloads vary in shape) ──────────────────────

Map<String, dynamic> asMap(dynamic v) =>
    v is Map<String, dynamic> ? v : const <String, dynamic>{};

double numOf(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

String textOf(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k]?.toString().trim() ?? '';
    if (v.isNotEmpty) return v;
  }
  return '';
}

String rupiah(double v) {
  final s = v.abs().round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}Rp $b';
}

const monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', //
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];
const daysShort = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

/// "19:30:00" → "19:30".
String timeShort(String t) {
  final parts = t.split(':');
  return parts.length >= 2 ? '${parts[0]}:${parts[1]}' : t;
}

bool hasAnyRole(List<String> userRoles, List<String> required) => userRoles.any(
      (role) => required.any((r) => role.toLowerCase() == r.toLowerCase()),
    );

// ── Event level ─────────────────────────────────────────────────────────────

/// Colour and icon of an event's level (kelompok, desa, daerah, pusat), so
/// the levels can be told apart at a glance.
class EventLevel {
  const EventLevel(this.label, this.icon, this.color, this.fg, this.tint);

  final String label;
  final IconData icon;

  /// Accent for the icon and dots; [fg] is its darker shade for text on
  /// [tint], the pale background.
  final Color color;
  final Color fg;
  final Color tint;

  static const kelompok = EventLevel('Kelompok', Icons.groups_outlined,
      Color(0xFF16A34A), Color(0xFF15803D), Color(0xFFDCFCE7));
  static const desa = EventLevel('Desa', Icons.holiday_village_outlined,
      Color(0xFF2563EB), Color(0xFF1D4ED8), Color(0xFFE5EEFF));
  static const daerah = EventLevel('Daerah', Icons.map_outlined,
      Color(0xFF7C3AED), Color(0xFF6D28D9), Color(0xFFEDE9FE));
  static const pusat = EventLevel('Pusat', Icons.account_balance_outlined,
      Color(0xFFEA580C), Color(0xFFC2410C), Color(0xFFFFEDD5));

  /// The four known levels, smallest first.
  static const all = [kelompok, desa, daerah, pusat];

  /// The style for a level as the server writes it; anything else is shown
  /// in grey under its own name.
  static EventLevel of(String raw) {
    final l = raw.trim().toLowerCase();
    for (final known in all) {
      if (l.contains(known.label.toLowerCase())) return known;
    }
    return EventLevel(
        raw.trim().isEmpty ? 'Kegiatan' : raw.trim(),
        Icons.event_outlined,
        const Color(0xFF64748B),
        const Color(0xFF475569),
        const Color(0xFFF1F5F9));
  }
}

// ── Next event ──────────────────────────────────────────────────────────────

class NextEventInfo {
  const NextEventInfo({
    required this.title,
    this.date,
    this.endDate,
    this.timeStart = '',
    this.timeEnd = '',
    this.location = '',
    this.level = '',
  });

  final String title;
  final DateTime? date;

  /// Last day of a multi-day event; null means it ends on [date].
  final DateTime? endDate;
  final String timeStart;
  final String timeEnd;
  final String location;

  /// Kelompok, desa, daerah or pusat, as the server writes it.
  final String level;

  /// Null when the payload carries no event.
  static NextEventInfo? parse(dynamic data) {
    final e = asMap(data);
    final title = textOf(e, ['title', 'name']);
    if (title.isEmpty) return null;
    final start = textOf(e, ['start_time', 'time']);
    final end = textOf(e, ['end_time']);
    return NextEventInfo(
      title: title,
      date: DateTime.tryParse(textOf(e, ['start_date', 'date'])),
      endDate: DateTime.tryParse(textOf(e, ['end_date'])),
      timeStart: start.isEmpty ? '' : timeShort(start),
      timeEnd: end.isEmpty ? '' : timeShort(end),
      location: textOf(e, ['location']),
      level: textOf(e, ['level']),
    );
  }

  /// Sort key: date, then start time ("HH:mm" sorts as text).
  String get _sortKey {
    final d = date;
    final day = d == null
        ? '9999-99-99'
        : '${d.year}-${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}';
    return '$day $timeStart';
  }

  /// Same event: same title on the same day.
  bool sameAs(NextEventInfo o) =>
      title == o.title &&
      _sortKey.substring(0, 10) == o._sortKey.substring(0, 10);

  static ({int h, int m})? _hm(String t) {
    final parts = t.split(':');
    final h = parts.length >= 2 ? int.tryParse(parts[0]) : null;
    final m = parts.length >= 2 ? int.tryParse(parts[1]) : null;
    return h == null || m == null ? null : (h: h, m: m);
  }

  /// When the event is over: its end time on its last day. Without an end
  /// time it lasts until the end of that day. An end time at or before the
  /// start time (22:00 – 01:00) means the next day.
  DateTime? get endsAt {
    final base = endDate ?? date;
    if (base == null) return null;
    final end = _hm(timeEnd);
    if (end == null) {
      return DateTime(base.year, base.month, base.day, 23, 59, 59);
    }
    var at = DateTime(base.year, base.month, base.day, end.h, end.m);
    final start = _hm(timeStart);
    if (start != null &&
        endDate == null &&
        end.h * 60 + end.m <= start.h * 60 + start.m) {
      at = at.add(const Duration(days: 1));
    }
    return at;
  }

  /// The current time is past the end time: the event is over and is no
  /// longer shown.
  bool get hasEnded {
    final at = endsAt;
    return at != null && DateTime.now().isAfter(at);
  }

  /// The event to show, the ones after it, and today's events. Everything that is over is
  /// dropped, including the "next event" the server named if its end time has
  /// passed, in which case the following one takes its place. Without a date
  /// an event is kept.
  static ({
    NextEventInfo? main,
    List<NextEventInfo> following,
    List<NextEventInfo> today,
  }) resolve(
    dynamic nextEventData,
    List<Map<String, dynamic>> rows, {
    int limit = 2,
  }) {
    final candidates = <NextEventInfo>[
      if (parse(nextEventData) case final e?) e,
      for (final r in rows)
        if (parse(r) case final e?) e,
    ].where((e) => !e.hasEnded).toList()
      ..sort((a, b) => a._sortKey.compareTo(b._sortKey));

    // The same event can come from both sources.
    final unique = <NextEventInfo>[];
    for (final e in candidates) {
      if (!unique.any(e.sameAs)) unique.add(e);
    }
    if (unique.isEmpty) {
      return (main: null, following: const [], today: const []);
    }
    // Today's events that are not over. With more than one, the card lists
    // them all and "following" starts after them.
    final today = unique.where((e) => e.daysAway == 0).toList();
    final skip = today.length > 1 ? today.length : 1;
    return (
      main: unique.first,
      following: unique.skip(skip).take(limit).toList(),
      today: today,
    );
  }

  String get timeRange => timeEnd.isEmpty ? timeStart : '$timeStart – $timeEnd';

  /// Whole days from today; null without a date.
  int? get daysAway {
    final d = date;
    if (d == null) return null;
    final now = DateTime.now();
    return DateTime(d.year, d.month, d.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
  }

  /// "Hari ini", "2 jam lagi", "Besok", "5 hari lagi"; empty when unknown or
  /// already past.
  String get countdown {
    final days = daysAway;
    if (days == null || days < 0) return '';
    if (days == 0) {
      final parts = timeStart.split(':');
      final h = parts.length >= 2 ? int.tryParse(parts[0]) : null;
      final m = parts.length >= 2 ? int.tryParse(parts[1]) : null;
      if (h != null && m != null) {
        final now = DateTime.now();
        final left =
            DateTime(now.year, now.month, now.day, h, m).difference(now);
        if (left.inMinutes >= 60) return '${left.inHours} jam lagi';
        if (left.inMinutes > 0) return '${left.inMinutes} menit lagi';
      }
      return 'Hari ini';
    }
    if (days == 1) return 'Besok';
    return '$days hari lagi';
  }
}

// ── Campaigns ───────────────────────────────────────────────────────────────

/// One payment of a [Contribution].
class ContributionPayment {
  const ContributionPayment({required this.amount, required this.date});

  /// Decimal string as sent (`"50000.00"`); format with [rupiahOfDecimal].
  final String amount;

  /// `YYYY-MM-DD`, shown as it comes.
  final String date;
}

/// The logged-in member's giving to one campaign.
class Contribution {
  const Contribution({
    required this.totalGiven,
    required this.paymentCount,
    required this.lastPaidDate,
    required this.payments,
  });

  final String totalGiven;
  final int paymentCount;
  final String lastPaidDate;

  /// Newest first.
  final List<ContributionPayment> payments;

  /// Null for `null` (not a member's contribution) or anything unreadable.
  static Contribution? parse(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final payments = [
      if (raw['payments'] is List)
        for (final p
            in (raw['payments'] as List).whereType<Map<String, dynamic>>())
          ContributionPayment(
            amount: textOf(p, ['amount']),
            date: textOf(p, ['paid_date', 'date']),
          ),
    ];
    return Contribution(
      totalGiven: textOf(raw, ['total_given']),
      paymentCount:
          int.tryParse(textOf(raw, ['payment_count'])) ?? payments.length,
      lastPaidDate: textOf(raw, ['last_paid_date']),
      payments: payments,
    );
  }
}

/// One donation of the logged-in member that is not part of the contribution
/// yet: waiting for the treasurer (`pending`) or turned down (`rejected`).
/// Approved donations leave this list and become payments of the
/// [Contribution].
class Donation {
  const Donation({
    required this.id,
    required this.amount,
    required this.paidDate,
    required this.status,
    this.reason = '',
    this.decidedDate = '',
  });

  final String id;

  /// Decimal string as sent (`"50000"`); format with [rupiahOfDecimal].
  final String amount;

  /// `YYYY-MM-DD`, the transfer date.
  final String paidDate;

  /// `pending` or `rejected` (lower case); other values are kept as they are.
  final String status;

  /// Why it was turned down; only for `rejected`.
  final String reason;

  /// `YYYY-MM-DD` of the decision, cut from the RFC 3339 `decided_at`.
  final String decidedDate;

  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';

  static Donation? parse(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final decided = textOf(raw, ['decided_at']);
    return Donation(
      id: textOf(raw, ['donation_id', 'id']),
      amount: textOf(raw, ['amount']),
      paidDate: textOf(raw, ['paid_date']),
      status: textOf(raw, ['status']).toLowerCase(),
      reason: textOf(raw, ['reason']),
      decidedDate: decided.length >= 10 ? decided.substring(0, 10) : decided,
    );
  }

  /// The donations of one campaign row (`donations`); empty without them.
  static List<Donation> listOf(Map<String, dynamic> campaign) => [
        if (campaign['donations'] is List)
          for (final d in campaign['donations'] as List)
            if (parse(d) case final donation?) donation,
      ];
}

/// Rupiah from a decimal string (`"150000.00"` → `Rp 150.000`) without going
/// through a floating-point number. A fraction other than zero is kept
/// (`Rp 50.000,50`). Anything that is not a decimal is read as a number.
String rupiahOfDecimal(String raw) {
  final m = RegExp(r'^(-?)(\d+)(?:\.(\d+))?$').firstMatch(raw.trim());
  if (m == null) return rupiah(numOf(raw));
  final digits = m.group(2)!;
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) b.write('.');
    b.write(digits[i]);
  }
  final fraction = (m.group(3) ?? '').replaceAll(RegExp(r'0+$'), '');
  return '${m.group(1)}Rp $b${fraction.isEmpty ? '' : ',$fraction'}';
}

/// Exact sum of decimal strings (no floating point), as a decimal string
/// with two fraction digits: `["50000.00", "100000.5"]` → `"150000.50"`.
/// Values that are not decimals are skipped.
String sumDecimals(Iterable<String> values) {
  var cents = BigInt.zero;
  for (final v in values) {
    final m = RegExp(r'^(-?)(\d+)(?:\.(\d+))?$').firstMatch(v.trim());
    if (m == null) continue;
    final fraction = '${m.group(3) ?? ''}00'.substring(0, 2);
    final n = BigInt.parse('${m.group(2)}$fraction');
    cents += m.group(1) == '-' ? -n : n;
  }
  final digits = cents.abs().toString().padLeft(3, '0');
  final cut = digits.length - 2;
  return '${cents.isNegative ? '-' : ''}${digits.substring(0, cut)}.'
      '${digits.substring(cut)}';
}

class CampaignInfo {
  const CampaignInfo({
    required this.title,
    required this.description,
    required this.percent,
    required this.collected,
    required this.target,
    this.endDate,
    this.contribution,
  });

  final String title;
  final String description;

  /// What the logged-in member has given to this campaign. Null: they have
  /// not (when the payload's `contribution_available` is true) or it is not
  /// known (when it is false); never shown as "Rp 0".
  final Contribution? contribution;

  /// The member has given to this campaign.
  bool get donated => contribution != null;
  final double percent;
  final double collected;
  final double target;
  final DateTime? endDate;

  double get progress => (percent / 100).clamp(0.0, 1.0).toDouble();

  /// `contribution_available` of a `/fundraising` payload. False means the
  /// member's contributions could not be read, so a null `contribution` says
  /// nothing; null means the payload does not say (an older server, or the
  /// home summary).
  static bool? contributionAvailableOf(dynamic data) =>
      flagOf(data, 'contribution_available');

  /// `donations_available` of a `/fundraising` payload. False: the member's
  /// donations could not be read, so an empty `donations` says nothing. Null:
  /// the payload does not say (a server that does not send donations yet).
  static bool? donationsAvailableOf(dynamic data) =>
      flagOf(data, 'donations_available');

  /// A boolean at the top of a payload, or of its `data`; null when absent.
  static bool? flagOf(dynamic data, String key) {
    var d = data;
    for (var i = 0; i < 2 && d is Map<String, dynamic>; i++) {
      final v = d[key];
      if (v is bool) return v;
      d = d['data'];
    }
    return null;
  }

  static List<CampaignInfo> listOf(dynamic data) => [
        for (final c in HomeSummaryProvider.campaignsOf(data)) _parse(c),
      ];

  static CampaignInfo _parse(Map<String, dynamic> c) {
    final target = numOf(c['target']);
    final collected = numOf(c['collected']);
    var percent = numOf(c['progress_percent']);
    if (percent == 0 && target > 0) percent = collected / target * 100;
    final title = textOf(c, ['title', 'name']);
    return CampaignInfo(
      title: title.isEmpty ? 'Penggalangan dana' : title,
      description: textOf(c, ['description']),
      percent: percent,
      collected: collected,
      target: target,
      endDate: DateTime.tryParse(textOf(c, ['end_date', 'deadline'])),
      contribution: Contribution.parse(c['contribution']),
    );
  }
}

// ── Information Hub content ─────────────────────────────────────────────────

/// The content types the Information Hub can show. Events and fundraising
/// are fed by the gateway today; campaigns and announcements are ready for
/// when it supplies them.
enum HubType { event, fundraising, campaign, announcement }

/// One card in the Information Hub, whatever its type.
class HubItem {
  const HubItem({
    required this.type,
    required this.title,
    required this.route,
    this.description = '',
    this.date,
    this.tag = '',
    this.meta = const [],
    this.progress,
    this.amounts = '',
    this.others = const [],
    this.contribution,
    this.lead = '',
    this.agenda = const [],
  });

  final HubType type;
  final String title;
  final String description;

  /// Detail screen opened by the card and its button.
  final String route;

  /// Shown as a date block (events) when present.
  final DateTime? date;

  /// Extra badge beside the category, e.g. an event countdown.
  final String tag;

  /// Icon + text lines: time, place, period, publication date.
  final List<(IconData, String)> meta;

  /// 0..1 for fundraising; null hides the bar.
  final double? progress;
  final String amounts;

  /// Smaller follow-up lines under the card (events after the main one).
  final List<NextEventInfo> others;

  /// Shown above the title with a clock: an event's time comes first, so
  /// the name below it has the full width and is never cut.
  final String lead;

  /// Several events of one day, listed as time + name in place of a single
  /// title.
  final List<NextEventInfo> agenda;

  /// What the member gave to this fundraising; null when nothing is known
  /// to have been given.
  final Contribution? contribution;

  bool get donated => contribution != null;

  factory HubItem.event(NextEventInfo e,
          {List<NextEventInfo> others = const []}) =>
      HubItem(
        type: HubType.event,
        others: others,
        title: e.title,
        route: '/info/kegiatan',
        date: e.date,
        tag: e.countdown,
        lead: e.timeStart.isEmpty ? '' : e.timeRange,
        meta: [
          if (e.location.isNotEmpty) (Icons.place_outlined, e.location),
        ],
      );

  /// Today's events when there is more than one: a list of time + name.
  factory HubItem.today(List<NextEventInfo> today,
          {List<NextEventInfo> others = const []}) =>
      HubItem(
        type: HubType.event,
        others: others,
        title: 'Kegiatan hari ini',
        route: '/info/kegiatan',
        date: today.first.date,
        tag: '${today.length} kegiatan hari ini',
        agenda: today,
      );

  factory HubItem.fundraising(CampaignInfo c) {
    final end = c.endDate;
    return HubItem(
      type: HubType.fundraising,
      title: c.title,
      description: c.description,
      route: '/info/fundraising',
      contribution: c.contribution,
      progress: c.progress,
      amounts: c.target > 0
          ? '${rupiah(c.collected)} / ${rupiah(c.target)}'
          : '${c.percent.round()}% terkumpul',
      meta: [
        if (end != null)
          (
            Icons.event_outlined,
            'Sampai ${end.day} ${monthsShort[end.month - 1]} ${end.year}'
          ),
      ],
    );
  }
}

// ── Modules ─────────────────────────────────────────────────────────────────

class LauncherModule {
  const LauncherModule({
    required this.label,
    required this.description,
    required this.icon,
    required this.route,
    required this.color,
    required this.tint,
    this.push = false,
    this.emoji,
  });

  final String label;
  final String description;
  final IconData icon;

  /// Drawn in place of [icon] where there is no icon for the subject (a
  /// goat for kurban).
  final String? emoji;
  final String route;

  /// Icon colour and its pale tile background.
  final Color color;
  final Color tint;

  /// Read-only info screens are pushed so "back" returns to the launcher;
  /// full modules replace it, as they navigate home on their own.
  final bool push;
}

/// The apps this user may open, by the modules the server allows for this
/// user and tenant (`GET /api/m/v1/bootstrap`). Events and fundraising are
/// information, not apps: they live in the Information Hub on the home tab.
List<LauncherModule> buildModules(HomeSummaryProvider p) {
  return [
    if (p.isModuleVisible('budget'))
      const LauncherModule(
        label: 'Dompet Saya',
        description: 'Catat uang masuk dan keluar pribadi, atur anggaran bulanan',
        icon: Icons.account_balance_wallet_outlined,
        route: '/budget',
        color: Color(0xFF2563EB),
        tint: Color(0xFFEFF6FF),
        push: true,
      ),
    // Everyone can read; writers (events/access) manage inside the module.
    if (p.isModuleVisible('events'))
      const LauncherModule(
        label: 'Kegiatan',
        description: 'Jadwal kegiatan, materi, dan pengelolaan oleh pengurus',
        icon: Icons.event_note_outlined,
        route: '/events',
        color: Color(0xFFDB2777),
        tint: Color(0xFFFDF2F8),
        push: true,
      ),
    // The organisation's cash (finance API), apart from the personal Budget.
    if (p.isModuleVisible('finance'))
      const LauncherModule(
        label: 'Keuangan',
        description: 'Saldo, transaksi, pembukuan, dan catat lewat suara',
        icon: Icons.account_balance_outlined,
        route: '/finance',
        color: Color(0xFF0D9488),
        tint: Color(0xFFF0FDFA),
        push: true,
      ),
    if (p.isModuleVisible('zakatfitrah'))
      const LauncherModule(
        label: 'Zakat Fitrah',
        description: 'Muzakki, mustahiq, dan laporan zakat',
        icon: Icons.volunteer_activism_outlined,
        route: '/zakat-fitrah',
        color: Color(0xFF7C3AED),
        tint: Color(0xFFF5F3FF),
      ),
    // Member-facing (shodaqoh): the member is taken from the login token. An
    // account not linked to a member sees that message inside the screen.
    if (p.isModuleVisible('shodaqoh')) ...[
      const LauncherModule(
        label: 'Tabungan Kurban',
        description: 'Tabungan kurban keluarga atau Anda, per bulan',
        icon: Icons.mosque_outlined,
        route: '/kurban',
        color: Color(0xFFEA580C),
        tint: Color(0xFFFFF7ED),
        push: true,
      ),
      const LauncherModule(
        label: 'Amal Jariyah',
        description: 'Buku amal: FR, shodaqoh dan infaq per bulan',
        icon: Icons.menu_book_outlined,
        route: '/amal-jariyah',
        color: Color(0xFF0891B2),
        tint: Color(0xFFECFEFF),
        push: true,
      ),
    ],
  ];
}

// ── Notifications (derived from the module summaries) ───────────────────────

class LauncherNotice {
  const LauncherNotice({
    required this.id,
    required this.icon,
    required this.title,
    required this.body,
    this.route,
  });

  /// Stable for the same underlying fact, so "seen" survives a refresh.
  final String id;
  final IconData icon;
  final String title;
  final String body;
  final String? route;
}

List<LauncherNotice> buildNotices(HomeSummaryProvider p) {
  final out = <LauncherNotice>[];

  if (p.isModuleVisible('events')) {
    final e = NextEventInfo.resolve(p.nextEvent.data, p.upcomingEvents).main;
    final days = e?.daysAway;
    if (e != null && days != null && days >= 0 && days <= 7) {
      out.add(LauncherNotice(
        id: 'event:${e.title}:${e.date}',
        icon: Icons.event_outlined,
        title: 'Kegiatan ${e.countdown.toLowerCase()}',
        body: [
          e.title,
          if (e.timeStart.isNotEmpty) e.timeRange,
          if (e.location.isNotEmpty) e.location,
        ].join(' · '),
        route: '/info/kegiatan',
      ));
    }
  }

  if (p.isModuleVisible('fundraising') && p.fundraising.hasData) {
    // A campaign the member already gave to is not news to them.
    for (final c
        in CampaignInfo.listOf(p.fundraising.data).where((c) => !c.donated)) {
      out.add(LauncherNotice(
        id: 'campaign:${c.title}',
        icon: Icons.campaign_outlined,
        title: 'Penggalangan dana aktif',
        body: '${c.title} · ${c.percent.round()}% terkumpul',
        route: '/info/fundraising',
      ));
    }
  }

  return out;
}

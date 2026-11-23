import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

/// One card on the home page: loading, an error reason, or its data.
class HomeSection {
  const HomeSection({this.data, this.error, this.loading = false});

  final dynamic data;

  /// Short reason such as `not_configured`, `timeout`, `unavailable`.
  final String? error;
  final bool loading;

  bool get hasData => data != null && error == null;

  static const HomeSection busy = HomeSection(loading: true);
}

/// Summary cards shown on the home page, read from the mobile gateway
/// (`GET /api/m/v1/home`) plus the finance summary for treasurer roles.
class HomeSummaryProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  HomeSection nextEvent = HomeSection.busy;

  /// Raw event rows of this month and next (`GET /api/m/v1/events`), so the
  /// home card can list the events after the next one. Empty when unavailable.
  List<Map<String, dynamic>> upcomingEvents = const [];
  HomeSection jimpitan = HomeSection.busy;
  HomeSection fundraising = HomeSection.busy;
  HomeSection shodaqoh = HomeSection.busy;
  HomeSection finance = HomeSection.busy;

  /// Modules this user may open, as the server worked them out from role and
  /// tenant settings (`GET /api/m/v1/bootstrap`): events, shodaqoh, jimpitan,
  /// fundraising, finance, budget, zakatfitrah, profile. Null until known, or when the
  /// call failed. Only for what is shown: the API refuses on its own (403).
  Map<String, bool>? modules;

  /// The roles the server holds now; they can change after login.
  List<String>? roles;

  /// Fallback while [modules] is unknown: modules switched off in
  /// `GET /api/m/v1/config` (`MODULE_<NAME>=false`).
  Set<String> hiddenModules = const {};
  String orgName = '';

  /// Without the bootstrap, the member-facing modules show and the ones that
  /// need a role (finance, budget, zakat fitrah) stay hidden.
  bool isModuleVisible(String name) {
    final m = modules;
    if (m != null) return m[name] == true;
    if (name == 'finance' || name == 'zakatfitrah' || name == 'budget') {
      return false;
    }
    return !hiddenModules.contains(name);
  }

  /// [loginRoles] are used until the bootstrap has said otherwise.
  bool hasRole(String role, List<String> loginRoles) =>
      (roles ?? loginRoles).any((r) => r.toLowerCase() == role.toLowerCase());

  bool isLoading = false;
  bool loaded = false;
  DateTime? loadedAt;

  // Bumped by reset() so a response for the previous user is thrown away.
  int _generation = 0;

  /// True when there is nothing yet, or what is shown is older than [maxAge].
  bool isStale([Duration maxAge = const Duration(minutes: 2)]) =>
      !loaded ||
      loadedAt == null ||
      DateTime.now().difference(loadedAt!) > maxAge;

  HomeSection _section(Map<String, dynamic> home, String key) {
    final raw = home[key];
    if (raw is! Map<String, dynamic>) {
      return const HomeSection(error: 'unavailable');
    }
    final err = raw['error'];
    if (err != null) return HomeSection(error: err.toString());
    // `{data: ...}` is the contract; a bare object is accepted as the data.
    if (raw.containsKey('data')) return HomeSection(data: raw['data']);
    return HomeSection(data: raw.isEmpty ? null : raw);
  }

  Future<void> load() async {
    if (isLoading) return;
    final generation = _generation;
    isLoading = true;
    notifyListeners();

    // Old values stay on screen while the new ones load.
    final results = await Future.wait<dynamic>([
      _loadHome(),
      _loadConfig(),
      _loadUpcomingEvents(),
      _loadBootstrap(),
    ]);
    if (generation != _generation) return;

    final boot = results[3] as ({
      Map<String, bool> modules,
      List<String> roles,
      String org
    })?;
    if (boot != null) {
      modules = boot.modules;
      roles = boot.roles;
      if (boot.org.isNotEmpty) orgName = boot.org;
    }
    // The cash summary is only fetched for those who may see it.
    final withFinance = isModuleVisible('finance');
    final financeSection = withFinance ? await _loadFinance() : null;
    if (generation != _generation) return;

    final config = results[1] as Map<String, String>?;
    if (config != null) {
      hiddenModules = {
        for (final e in config.entries)
          if (e.key.startsWith('MODULE_') && e.value.toLowerCase() == 'false')
            e.key.substring(7).toLowerCase(),
      };
      if (boot == null || boot.org.isEmpty) orgName = config['ORG_NAME'] ?? '';
    }

    final home = results[0] as List<HomeSection>;
    nextEvent = home[0];
    jimpitan = home[1];
    fundraising = home[2];
    shodaqoh = home[3];
    upcomingEvents = results[2] as List<Map<String, dynamic>>;
    if (financeSection != null) finance = financeSection;

    isLoading = false;
    loaded = true;
    loadedAt = DateTime.now();
    notifyListeners();
  }

  /// The campaign rows inside a fundraising payload, whatever it is wrapped
  /// in: a bare list, or an object holding the list under any key.
  static List<Map<String, dynamic>> campaignsOf(dynamic data) {
    List<Map<String, dynamic>> rows(dynamic v) =>
        (v as List).whereType<Map<String, dynamic>>().toList();
    if (data is List) return rows(data);
    if (data is Map<String, dynamic>) {
      for (final key in const ['campaigns', 'items', 'data', 'list', 'rows']) {
        final v = data[key];
        if (v is List) return rows(v);
        if (v is Map<String, dynamic>) {
          final inner = campaignsOf(v);
          if (inner.isNotEmpty) return inner;
        }
      }
      for (final v in data.values) {
        if (v is List && v.any((e) => e is Map<String, dynamic>)) {
          return rows(v);
        }
      }
    }
    return const [];
  }

  /// The home payload carries only a summary of the campaigns, if that: no
  /// list, and no `contribution` (the member's own giving). The hub shows the
  /// campaigns and which ones the member has given to, so read them from the
  /// endpoint the detail screen uses unless the home payload already has both.
  Future<HomeSection> _withCampaigns(HomeSection section) async {
    if (section.error != null) return section;
    final have = campaignsOf(section.data);
    if (have.isNotEmpty && have.every((c) => c.containsKey('contribution'))) {
      return section;
    }
    try {
      final resp = await _api.getMobileFundraising();
      final campaigns = campaignsOf(resp.data);
      if (campaigns.isEmpty) return section;
      return HomeSection(data: {
        if (section.data is Map<String, dynamic>)
          ...section.data as Map<String, dynamic>,
        'campaigns': campaigns,
      });
    } catch (e) {
      debugPrint('HomeSummaryProvider._withCampaigns error: $e');
      return section;
    }
  }

  /// The home card is expected to carry `{total, contributors}` for the
  /// current month. When it is missing or zero, ask the dedicated jimpitan
  /// endpoint (`?month=YYYY-MM`) before showing "Rp 0".
  Future<HomeSection> _withJimpitanTotal(HomeSection section) async {
    double total(dynamic d) =>
        d is Map ? double.tryParse(d['total']?.toString() ?? '') ?? 0 : 0;
    if (section.error == null && total(section.data) > 0) return section;
    try {
      final now = DateTime.now();
      final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final resp = await _api.getMobileJimpitan(month);
      debugPrint(
          'HomeSummaryProvider /jimpitan?month=$month raw: ${resp.data}');
      var d = resp.data;
      if (d is Map<String, dynamic> && d['data'] is Map<String, dynamic>) {
        d = d['data'];
      }
      if (d is Map<String, dynamic> && total(d) > 0) {
        return HomeSection(data: {
          if (section.data is Map<String, dynamic>)
            ...section.data as Map<String, dynamic>,
          ...d,
        });
      }
    } catch (e) {
      debugPrint('HomeSummaryProvider._withJimpitanTotal error: $e');
    }
    // Still nothing: add up the "Transaksi tercatat" of the month, the same
    // rows the Jimpitan screen lists (recap rows are part of the total).
    try {
      final now = DateTime.now();
      final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final resp = await _api.getMobileJimpitanTransactions(month);
      final sum = jimpitanTransactionsTotal(resp.data);
      debugPrint('HomeSummaryProvider jimpitan transactions sum: $sum');
      if (sum > 0) {
        return HomeSection(data: {
          if (section.data is Map<String, dynamic>)
            ...section.data as Map<String, dynamic>,
          'total': sum,
        });
      }
    } catch (e) {
      debugPrint('HomeSummaryProvider jimpitan transactions error: $e');
    }
    return section;
  }

  /// Sum of `amount` over the rows of a `/jimpitan/transactions` payload,
  /// whether it is a bare list or wrapped in `{transactions: [...]}` /
  /// `{data: ...}`.
  static double jimpitanTransactionsTotal(dynamic raw) {
    dynamic src = raw;
    for (var i = 0; i < 3 && src is Map<String, dynamic>; i++) {
      src = src['transactions'] ?? src['data'] ?? src['items'];
    }
    if (src is! List) return 0;
    var sum = 0.0;
    for (final t in src.whereType<Map<String, dynamic>>()) {
      sum += double.tryParse(t['amount']?.toString() ?? '') ?? 0;
    }
    return sum;
  }

  /// Rows of an event payload: a bare list, or one wrapped in
  /// `{events: [...]}` / `{data: ...}`.
  static List<Map<String, dynamic>> eventRowsOf(dynamic raw) {
    dynamic src = raw;
    for (var i = 0; i < 3 && src is Map<String, dynamic>; i++) {
      src = src['events'] ?? src['data'] ?? src['items'];
    }
    return src is List
        ? src.whereType<Map<String, dynamic>>().toList()
        : const [];
  }

  /// This month's and next month's events; never throws.
  Future<List<Map<String, dynamic>>> _loadUpcomingEvents() async {
    String param(DateTime m) =>
        '${m.year}-${m.month.toString().padLeft(2, '0')}';
    try {
      final now = DateTime.now();
      final responses = await Future.wait([
        _api.getMobileEvents(param(now)),
        _api.getMobileEvents(param(DateTime(now.year, now.month + 1))),
      ]);
      return [for (final r in responses) ...eventRowsOf(r.data)];
    } catch (e) {
      debugPrint('HomeSummaryProvider._loadUpcomingEvents error: $e');
      return const [];
    }
  }

  Future<List<HomeSection>> _loadHome() async {
    try {
      final resp = await _api.getMobileHome();
      final raw = resp.data;
      var body = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
      if (body['data'] is Map<String, dynamic> &&
          body['next_event'] == null &&
          body['jimpitan'] == null) {
        body = body['data'] as Map<String, dynamic>;
      }
      debugPrint('HomeSummaryProvider home.jimpitan raw: ${body['jimpitan']}');
      return [
        _section(body, 'next_event'),
        await _withJimpitanTotal(_section(body, 'jimpitan')),
        await _withCampaigns(_section(body, 'fundraising')),
        _section(body, 'shodaqoh'),
      ];
    } catch (e) {
      debugPrint('HomeSummaryProvider._loadHome error: $e');
      return List.filled(4, const HomeSection(error: 'unavailable'));
    }
  }

  /// `GET /api/m/v1/bootstrap`, or null when it can't be read.
  Future<({Map<String, bool> modules, List<String> roles, String org})?>
      _loadBootstrap() async {
    try {
      final d = (await _api.getMobileBootstrap()).data;
      if (d is! Map<String, dynamic> || d['modules'] is! Map) return null;
      final user = d['user'];
      return (
        modules: {
          for (final e in (d['modules'] as Map).entries)
            e.key.toString().toLowerCase(): e.value == true,
        },
        roles: [
          if (user is Map && user['roles'] is List)
            for (final r in user['roles'] as List) r.toString(),
        ],
        org: d['org_name']?.toString().trim() ?? '',
      );
    } catch (e) {
      debugPrint('HomeSummaryProvider._loadBootstrap error: $e');
      return null;
    }
  }

  /// Flags as an upper-case `KEY → value` map, or null when the config can't
  /// be read (then every module stays visible). Accepts a flat object, a list
  /// of `{code, value}` rows, or `{modules: {events: false}, org_name}`.
  Future<Map<String, String>?> _loadConfig() async {
    try {
      final resp = await _api.getMobileConfig();
      dynamic raw = resp.data;
      if (raw is Map<String, dynamic> && raw['data'] != null) raw = raw['data'];

      final out = <String, String>{};
      if (raw is List) {
        for (final row in raw.whereType<Map<String, dynamic>>()) {
          final code = row['code']?.toString() ?? '';
          if (code.isNotEmpty) {
            out[code.toUpperCase()] = row['value']?.toString() ?? '';
          }
        }
      } else if (raw is Map<String, dynamic>) {
        raw.forEach((k, v) {
          if (v is Map<String, dynamic> && k.toLowerCase() == 'modules') {
            v.forEach((name, on) =>
                out['MODULE_${name.toUpperCase()}'] = on.toString());
          } else if (v is! Map && v is! List) {
            out[k.toUpperCase()] = v?.toString() ?? '';
          }
        });
      }
      return out;
    } catch (e) {
      debugPrint('HomeSummaryProvider._loadConfig error: $e');
      return null;
    }
  }

  Future<HomeSection> _loadFinance() async {
    try {
      final resp = await _api.getTransactionSummary();
      final d = resp.data;
      if (d is! Map<String, dynamic>) {
        return const HomeSection(error: 'unavailable');
      }
      double n(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
      return HomeSection(data: {
        'income': n(d['tot_inc']),
        'expense': n(d['tot_exp']),
        'net': n(d['net']),
      });
    } catch (e) {
      debugPrint('HomeSummaryProvider._loadFinance error: $e');
      return const HomeSection(error: 'unavailable');
    }
  }

  void reset() {
    nextEvent = jimpitan = fundraising = shodaqoh = finance = HomeSection.busy;
    upcomingEvents = const [];
    isLoading = false;
    loaded = false;
    loadedAt = null;
    hiddenModules = const {};
    modules = null;
    roles = null;
    orgName = '';
    _generation++;
    notifyListeners();
  }
}

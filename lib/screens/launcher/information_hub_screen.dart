import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/launcher_tokens.dart';
import '../../providers/home_summary_provider.dart';
import '../../services/api_service.dart';
import 'hub_cards.dart';
import 'launcher_models.dart';

/// Full Information Hub listing behind "Semua": upcoming events and active
/// fundraising, filterable by category.
class InformationHubScreen extends StatefulWidget {
  const InformationHubScreen({super.key});

  @override
  State<InformationHubScreen> createState() => _InformationHubScreenState();
}

class _InformationHubScreenState extends State<InformationHubScreen> {
  bool _loading = true;
  List<HubItem> _items = const [];

  /// Categories that could not be loaded this time.
  Set<HubType> _failed = const {};

  /// Null shows every category.
  HubType? _filter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  static String _monthParam(DateTime m) =>
      '${m.year}-${m.month.toString().padLeft(2, '0')}';

  /// Events that are not over yet (by end time), this month and next, soonest
  /// first.
  Future<List<HubItem>> _loadEvents(ApiService api) async {
    final now = DateTime.now();
    final responses = await Future.wait([
      api.getMobileEvents(_monthParam(now)),
      api.getMobileEvents(_monthParam(DateTime(now.year, now.month + 1))),
    ]);
    final events = [
      for (final r in responses)
        for (final row in HomeSummaryProvider.eventRowsOf(r.data))
          if (NextEventInfo.parse(row) case final e?) e,
    ].where((e) => !e.hasEnded).toList()
      ..sort((a, b) {
        final byDate = (a.date ?? now).compareTo(b.date ?? now);
        return byDate != 0 ? byDate : a.timeStart.compareTo(b.timeStart);
      });
    return events.map(HubItem.event).toList();
  }

  Future<List<HubItem>> _loadFundraising(ApiService api) async {
    final resp = await api.getMobileFundraising();
    return CampaignInfo.listOf(resp.data).map(HubItem.fundraising).toList();
  }

  Future<void> _load() async {
    final summary = context.read<HomeSummaryProvider>();
    setState(() => _loading = true);
    final api = ApiService();
    final failed = <HubType>{};

    // Each category loads on its own: one failing keeps the other.
    Future<List<HubItem>> guarded(
        HubType type, Future<List<HubItem>> Function() load) async {
      try {
        return await load();
      } catch (e) {
        debugPrint('InformationHubScreen $type error: $e');
        failed.add(type);
        return const [];
      }
    }

    final results = await Future.wait([
      if (summary.isModuleVisible('events'))
        guarded(HubType.event, () => _loadEvents(api)),
      if (summary.isModuleVisible('fundraising'))
        guarded(HubType.fundraising, () => _loadFundraising(api)),
    ]);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _items = [for (final list in results) ...list];
      _failed = failed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = context.watch<HomeSummaryProvider>();
    final categories = [
      if (summary.isModuleVisible('events')) HubType.event,
      if (summary.isModuleVisible('fundraising')) HubType.fundraising,
    ];
    final shown = _filter == null
        ? _items
        : _items.where((i) => i.type == _filter).toList();
    final failedShown =
        _failed.where((t) => _filter == null || t == _filter).toList();

    return Theme(
      data: Lx.theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Information Hub')),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (categories.length > 1)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(Lx.s20, 0, Lx.s20, Lx.s8),
                child: Row(
                  children: [
                    _chip('Semua', null),
                    for (final t in categories) _chip(HubStyle.of(t).label, t),
                  ],
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(Lx.s20, Lx.s8, Lx.s20,
                      Lx.s24 + MediaQuery.paddingOf(context).bottom),
                  children: [
                    if (_loading && _items.isEmpty)
                      const HubStateCard.loading(),
                    for (final item in shown)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Lx.s12),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(Lx.rCard),
                            boxShadow: Lx.shadowSoft,
                          ),
                          child: HubCard(item),
                        ),
                      ),
                    if (failedShown.isNotEmpty)
                      HubStateCard(
                        icon: Icons.cloud_off_outlined,
                        text:
                            '${failedShown.map((t) => HubStyle.of(t).label).join(' dan ')} '
                            'belum bisa dimuat.',
                        onRetry: _load,
                      ),
                    if (!_loading && shown.isEmpty && failedShown.isEmpty)
                      const HubStateCard(
                        icon: Icons.inbox_outlined,
                        text: 'Belum ada informasi di kategori ini.',
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, HubType? type) {
    final selected = _filter == type;
    return Padding(
      padding: const EdgeInsets.only(right: Lx.s8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = type),
        showCheckmark: false,
        selectedColor: Lx.primary,
        backgroundColor: Lx.surface,
        side: BorderSide(color: selected ? Lx.primary : Lx.border),
        labelStyle: Lx.button
            .copyWith(color: selected ? Colors.white : Lx.textSecondary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

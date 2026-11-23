import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/launcher_tokens.dart';
import '../../providers/home_summary_provider.dart';
import 'hub_cards.dart';
import 'launcher_models.dart';
import 'section_header.dart';

/// Home-screen preview of the Information Hub: "Agenda selanjutnya" (the
/// next events) and "Penggalangan dana" (the active fundraising). "Semua"
/// opens the full listing.
class InformationHub extends StatelessWidget {
  const InformationHub({
    super.key,
    required this.summary,
    required this.onSeeAll,
    required this.onRetry,
  });

  final HomeSummaryProvider summary;
  final VoidCallback onSeeAll;
  final VoidCallback onRetry;

  /// Fundraising cards listed on the home screen; the rest are behind
  /// "lainnya".
  static const _maxFundraising = 4;

  static const _eventsRoute = '/events';
  static const _fundraisingRoute = '/info/fundraising';

  @override
  Widget build(BuildContext context) {
    final p = summary;
    final events = p.isModuleVisible('events');
    final funds = p.isModuleVisible('fundraising');
    if (!events && !funds) return const SizedBox.shrink();

    final sections = [if (events) p.nextEvent, if (funds) p.fundraising];
    final loading = sections.any((s) => s.loading);
    final failed = sections.where((s) => s.error != null).length;

    // Every upcoming event that is shown today: today's (all of them when
    // there are several) or the next one, then the ones that follow.
    final agenda = <NextEventInfo>[];
    if (events) {
      final r = NextEventInfo.resolve(p.nextEvent.data, p.upcomingEvents);
      if (r.today.length > 1) {
        agenda.addAll(r.today);
      } else if (r.main != null) {
        agenda.add(r.main!);
      }
      agenda.addAll(r.following);
    }

    final campaigns = funds && p.fundraising.hasData
        ? CampaignInfo.listOf(p.fundraising.data)
        : const <CampaignInfo>[];

    final children = <Widget>[
      if (agenda.isNotEmpty) ...[
        LauncherHeading(
          title: 'Agenda selanjutnya',
          actionLabel: 'Semua agenda',
          onAction: () => context.push(_eventsRoute),
        ),
        const SizedBox(height: Lx.s12),
        _AgendaCard(events: agenda, onOpen: () => context.push(_eventsRoute)),
      ],
      if (campaigns.isNotEmpty) ...[
        if (agenda.isNotEmpty) const SizedBox(height: Lx.s24),
        LauncherHeading(
          title: 'Penggalangan dana',
          actionLabel: 'Semua penggalangan dana',
          onAction: () => context.push(_fundraisingRoute),
        ),
        const SizedBox(height: Lx.s12),
        for (var i = 0; i < campaigns.length && i < _maxFundraising; i++) ...[
          if (i > 0) const SizedBox(height: Lx.s12),
          _FundraisingCard(
            campaign: campaigns[i],
            onOpen: () => context.push(_fundraisingRoute),
          ),
        ],
        if (campaigns.length > _maxFundraising)
          Padding(
            padding: const EdgeInsets.only(top: Lx.s8),
            child: InkWell(
              onTap: () => context.push(_fundraisingRoute),
              borderRadius: BorderRadius.circular(Lx.rSmall),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Center(
                  child: Text(
                    '+${campaigns.length - _maxFundraising} penggalangan '
                    'dana lainnya',
                    style: Lx.button.copyWith(color: Lx.primary),
                  ),
                ),
              ),
            ),
          ),
      ],
      if (loading && agenda.isEmpty && campaigns.isEmpty)
        const HubStateCard.loading(),
      if (failed > 0) ...[
        if (agenda.isNotEmpty || campaigns.isNotEmpty)
          const SizedBox(height: Lx.s12),
        HubStateCard(
          icon: Icons.cloud_off_outlined,
          text: failed == sections.length
              ? 'Kabar terbaru belum bisa dimuat.'
              : 'Sebagian kabar belum bisa dimuat.',
          onRetry: onRetry,
        ),
      ],
      if (!loading && failed == 0 && agenda.isEmpty && campaigns.isEmpty)
        const HubStateCard(
          icon: Icons.inbox_outlined,
          text: 'Belum ada kabar atau kegiatan terbaru.',
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

/// One white card holding a row per upcoming event: date block, title,
/// weekday · time (and the countdown), place, and a chevron.
class _AgendaCard extends StatelessWidget {
  const _AgendaCard({required this.events, required this.onOpen});

  final List<NextEventInfo> events;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Lx.s16),
      decoration: BoxDecoration(
        color: Lx.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Lx.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < events.length; i++)
            _row(events[i], last: i == events.length - 1),
        ],
      ),
    );
  }

  Widget _row(NextEventInfo e, {required bool last}) {
    final d = e.date;
    final when = [
      if (d != null) daysShort[d.weekday - 1],
      if (e.timeStart.isNotEmpty) e.timeRange,
    ].join(' · ');
    final countdown = e.countdown;
    final level = EventLevel.of(e.level);

    return Semantics(
      button: true,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: Color(0xFFEDF0F5))),
          ),
          child: Row(
            children: [
              if (d != null) ...[
                Container(
                  width: 48,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${d.day}',
                          style: Lx.userName.copyWith(
                              fontSize: 18, height: 1.2, letterSpacing: 0)),
                      Text(
                        monthsShort[d.month - 1].toUpperCase(),
                        style: Lx.metadata.copyWith(
                            fontSize: 10,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Lx.s12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.title, style: Lx.cardHeading.copyWith(height: 1.3)),
                    if (when.isNotEmpty || countdown.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(text: when),
                            if (when.isNotEmpty && countdown.isNotEmpty)
                              const TextSpan(text: ' · '),
                            if (countdown.isNotEmpty)
                              TextSpan(
                                text: countdown,
                                style: const TextStyle(
                                    color: Lx.primary,
                                    fontWeight: FontWeight.w700),
                              ),
                          ]),
                          style: Lx.body.copyWith(
                              fontWeight: FontWeight.w500, height: 1.3),
                        ),
                      ),
                    if (e.location.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                  color: level.color, shape: BoxShape.circle),
                            ),
                            Expanded(
                              child: Text(e.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Lx.metadata),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: Lx.s8),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: Lx.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// One campaign: our icon beside the title and description, the amount
/// collected and its percentage, a progress bar, what is left of the target,
/// and the donate button.
class _FundraisingCard extends StatelessWidget {
  const _FundraisingCard({required this.campaign, required this.onOpen});

  final CampaignInfo campaign;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = campaign;
    final style = HubStyle.of(HubType.fundraising);
    final end = c.endDate;
    final left = c.target - c.collected;

    return Container(
      padding: const EdgeInsets.all(Lx.s16),
      decoration: BoxDecoration(
        color: Lx.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Lx.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HubIconTile(style: style, size: 44, donated: c.donated),
              const SizedBox(width: Lx.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Lx.cardHeading.copyWith(fontSize: 16)),
                    if (c.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(c.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Lx.body),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(rupiah(c.collected),
                    style:
                        Lx.userName.copyWith(fontSize: 18, letterSpacing: 0)),
              ),
              Text('${c.percent.round()}%',
                  style: Lx.button.copyWith(
                      fontSize: 14,
                      color: Lx.primary,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: c.progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFE9EDF3),
              valueColor: const AlwaysStoppedAnimation(Lx.primary),
              semanticsLabel: c.title,
              semanticsValue: '${c.percent.round()}%',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            c.target > 0
                ? 'dari target ${rupiah(c.target)}'
                    '${left > 0 ? ' · kurang ${rupiah(left)}' : ''}'
                : 'terkumpul',
            style: Lx.metadata.copyWith(fontSize: 13),
          ),
          if (end != null)
            Padding(
              padding: const EdgeInsets.only(top: Lx.s4),
              child: Row(
                children: [
                  const Icon(Icons.event_outlined,
                      size: 15, color: Lx.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Sampai ${end.day} ${monthsShort[end.month - 1]} '
                    '${end.year}',
                    style: Lx.metadata,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: onOpen,
              style: FilledButton.styleFrom(
                backgroundColor: Lx.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle: Lx.button.copyWith(fontSize: 15),
              ),
              child: const Text('Donasi Sekarang'),
            ),
          ),
        ],
      ),
    );
  }
}

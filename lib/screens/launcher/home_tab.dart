import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/launcher_tokens.dart';
import '../../providers/home_summary_provider.dart';
import 'announcement_carousel.dart';
import 'app_launcher.dart';
import 'home_header.dart';
import 'information_hub.dart';
import 'launcher_models.dart';

/// Launcher home (docs/MOBILE_DASHBOARD_DESIGN.md §3): header, announcement
/// banner, App Launcher (apps to operate), Information Hub (things to read,
/// attend or support).
class LauncherHomeTab extends StatelessWidget {
  const LauncherHomeTab({
    super.key,
    required this.username,
    this.avatarUrl,
    required this.groupName,
    required this.modules,
    required this.unseenNotices,
    required this.onOpenModules,
    required this.onOpenNotifications,
    required this.onOpenProfile,
  });

  final String username;
  final String? avatarUrl;
  final String groupName;
  final List<LauncherModule> modules;
  final int unseenNotices;
  final VoidCallback onOpenModules;
  final VoidCallback onOpenNotifications;

  /// Profile doubles as settings: it holds the account and sign-out.
  final VoidCallback onOpenProfile;

  static const _topTint = Color(0xFFDCE8FF);

  @override
  Widget build(BuildContext context) {
    final p = context.watch<HomeSummaryProvider>();
    Future<void> reload() => p.load();

    return RefreshIndicator(
      onRefresh: reload,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_topTint, Lx.background],
                ),
              ),
              padding: EdgeInsets.fromLTRB(Lx.s20,
                  MediaQuery.paddingOf(context).top + Lx.s16, Lx.s20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HomeHeader(
                    username: username,
                    avatarUrl: avatarUrl,
                    unseenNotices: unseenNotices,
                    onOpenNotifications: onOpenNotifications,
                    onOpenSettings: onOpenProfile,
                  ),
                  const SizedBox(height: Lx.s20),
                  AnnouncementCarousel(slides: _slides(context, p)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Lx.s20, Lx.s24, Lx.s20, 0),
              child: AppLauncher(modules: modules, onSeeAll: onOpenModules),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Lx.s20, Lx.s24, Lx.s20, 0),
              child: InformationHub(
                summary: p,
                onSeeAll: () => context.push('/info/hub'),
                onRetry: reload,
              ),
            ),
            const SizedBox(height: Lx.s32),
          ],
        ),
      ),
    );
  }

  /// Banner slides, all from live data and meant for everyone: a welcome,
  /// the next event, then the active fundraising. Figures such as cash
  /// balance, jimpitan and shodaqoh are not shown here.
  List<AnnouncementSlide> _slides(BuildContext context, HomeSummaryProvider p) {
    final org = p.orgName.isNotEmpty ? p.orgName : groupName;
    final slides = <AnnouncementSlide>[
      AnnouncementSlide(
        category: org,
        title: 'Satu pintu untuk semua',
        description: 'Aplikasi, kegiatan, dan kabar organisasi di satu tempat.',
        icon: Icons.campaign_outlined,
        cta: 'Jelajahi',
        onTap: onOpenModules,
      ),
    ];

    if (p.isModuleVisible('events')) {
      final e = NextEventInfo.resolve(p.nextEvent.data, p.upcomingEvents).main;
      if (e != null) {
        final d = e.date;
        final when = [
          if (d != null)
            '${daysShort[d.weekday - 1]}, ${d.day} ${monthsShort[d.month - 1]}',
          if (e.timeStart.isNotEmpty) e.timeRange,
        ].join(' · ');
        final countdown = e.countdown;
        slides.add(AnnouncementSlide(
          category: countdown.isEmpty
              ? 'Kegiatan Berikutnya'
              : 'Kegiatan · $countdown',
          title: e.title,
          description: [when, e.location].where((t) => t.isNotEmpty).join('\n'),
          icon: Icons.event_outlined,
          cta: 'Lihat Detail',
          onTap: () => context.push('/info/kegiatan'),
        ));
      }
    }

    if (p.isModuleVisible('fundraising') && p.fundraising.hasData) {
      for (final c in CampaignInfo.listOf(p.fundraising.data).take(3)) {
        slides.add(AnnouncementSlide(
          category: c.donated
              ? 'Penggalangan Dana · Sudah berdonasi'
              : 'Penggalangan Dana',
          title: c.title,
          description: c.description.isNotEmpty
              ? c.description
              : '${c.percent.round()}% terkumpul',
          icon: Icons.volunteer_activism_outlined,
          cta: 'Lihat Detail',
          onTap: () => context.push('/info/fundraising'),
        ));
      }
    }

    return slides;
  }
}

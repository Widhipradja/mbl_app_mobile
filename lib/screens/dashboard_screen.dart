import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/launcher_tokens.dart';
import '../widgets/update_prompt.dart';
import '../providers/auth_provider.dart';
import '../providers/configuration_provider.dart';
import '../providers/home_summary_provider.dart';
import '../providers/zakat_provider.dart';
import '../services/storage_service.dart';
import 'launcher/bottom_navigation.dart';
import 'launcher/home_tab.dart';
import 'launcher/launcher_models.dart';
import 'launcher/more_tabs.dart';

/// App launcher and information hub: one entry point for the modules plus the
/// organisation's events, campaigns and updates.
///
/// Tabs: Beranda (greeting, banner, Quick Launch, next event, campaigns),
/// Modul (all modules, searchable), Notifikasi, Profil.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _home = 0, _modules = 1, _notifications = 2, _profile = 3;

  int _tab = _home;
  final _searchFocus = FocusNode();

  /// Notices already looked at in this session; the badge counts the rest.
  final _seenNotices = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthProvider>().refreshAvatar();
      promptForUpdate(context);
      final p = context.read<HomeSummaryProvider>();
      // Also refreshes when coming back from a module after a while.
      if (p.isStale()) p.load();
    });
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  void _select(int tab) {
    _searchFocus.unfocus();
    setState(() {
      // Leaving the notifications tab marks what was listed there as seen.
      if (_tab == _notifications && tab != _notifications) {
        _seenNotices.addAll(
          buildNotices(context.read<HomeSummaryProvider>()).map((n) => n.id),
        );
      }
      _tab = tab;
    });
  }

  Future<void> _logout() async {
    final authProvider = context.read<AuthProvider>();
    final zakatProvider = context.read<ZakatProvider>();
    final configProvider = context.read<ConfigurationProvider>();
    final homeProvider = context.read<HomeSummaryProvider>();
    await authProvider.logout();
    zakatProvider.reset();
    configProvider.reset();
    homeProvider.reset();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user ?? StorageService.getUser();
    final summary = context.watch<HomeSummaryProvider>();
    final modules = buildModules(summary);
    final notices = buildNotices(summary);
    // While the list is open its items count as read.
    final unseen = _tab == _notifications
        ? 0
        : notices.where((n) => !_seenNotices.contains(n.id)).length;

    final username =
        (user?.name ?? '').trim().isEmpty ? 'User' : user!.name.trim();

    return Theme(
      data: Lx.theme,
      child: PopScope(
        // Back from a secondary tab returns to Beranda before leaving the app.
        canPop: _tab == _home,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _select(_home);
        },
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark,
          child: Scaffold(
            backgroundColor: Lx.background,
            body: IndexedStack(
              index: _tab,
              children: [
                LauncherHomeTab(
                  username: username,
                  avatarUrl: user?.avatar,
                  groupName: user?.groupName ?? 'Baraka',
                  modules: modules,
                  unseenNotices: unseen,
                  onOpenModules: () => _select(_modules),
                  onOpenNotifications: () => _select(_notifications),
                  onOpenProfile: () => _select(_profile),
                ),
                LauncherModulesTab(modules: modules, searchFocus: _searchFocus),
                LauncherNotificationsTab(
                  notices: notices,
                  onRefresh: summary.load,
                ),
                LauncherProfileTab(user: user, onLogout: _logout),
              ],
            ),
            bottomNavigationBar: LauncherBottomNavigation(
              index: _tab,
              onSelect: _select,
              items: [
                const LauncherNavItem(
                  label: 'Beranda',
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                ),
                const LauncherNavItem(
                  label: 'Modul',
                  icon: Icons.grid_view_outlined,
                  activeIcon: Icons.grid_view_rounded,
                ),
                LauncherNavItem(
                  label: 'Notifikasi',
                  icon: Icons.notifications_none_outlined,
                  activeIcon: Icons.notifications_rounded,
                  badge: unseen,
                ),
                const LauncherNavItem(
                  label: 'Profil',
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

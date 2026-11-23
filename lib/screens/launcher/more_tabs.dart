import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../config/launcher_tokens.dart';
import '../../widgets/app_ui.dart' show EmptyState;
import '../../providers/home_summary_provider.dart';
import '../../models/user.dart';
import '../profile/change_password_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../profile/about_screen.dart';
import 'user_avatar.dart';
import 'hub_cards.dart';
import 'launcher_models.dart';

/// Shared title block for the secondary tabs.
class _TabHeader extends StatelessWidget {
  const _TabHeader(this.title, {this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.paddingOf(context).top + 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Lx.text,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(subtitle!,
                  style:
                      const TextStyle(color: Lx.textSecondary, fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

Widget _emptyState(IconData icon, String text) => Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
      child: EmptyState(icon: icon, text: text),
    );

/// One tappable row: tinted icon, title, one line of detail.
class _RowCard extends StatelessWidget {
  const _RowCard({
    required this.icon,
    required this.color,
    required this.tint,
    required this.title,
    required this.body,
    this.onTap,
    this.emoji,
  });

  final IconData icon;

  /// Drawn in place of [icon] when set.
  final String? emoji;
  final Color color;
  final Color tint;
  final String title;
  final String body;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Lx.rCard),
          side: const BorderSide(color: Lx.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: emoji != null
                      ? Text(emoji!,
                          style: const TextStyle(fontSize: 22, height: 1.15))
                      : Icon(icon, size: 24, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Lx.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Lx.textSecondary, fontSize: 13, height: 1.3),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  const Icon(Icons.chevron_right_rounded,
                      size: 22, color: Lx.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Modules ─────────────────────────────────────────────────────────────────

/// Every module the user may open, with search.
class LauncherModulesTab extends StatefulWidget {
  const LauncherModulesTab({
    super.key,
    required this.modules,
    required this.searchFocus,
  });

  final List<LauncherModule> modules;
  final FocusNode searchFocus;

  @override
  State<LauncherModulesTab> createState() => _LauncherModulesTabState();
}

class _LauncherModulesTabState extends State<LauncherModulesTab> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final shown = q.isEmpty
        ? widget.modules
        : widget.modules
            .where((m) =>
                m.label.toLowerCase().contains(q) ||
                m.description.toLowerCase().contains(q))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _TabHeader('Modul'),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: TextField(
            controller: _search,
            focusNode: widget.searchFocus,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Cari modul…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: q.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Hapus pencarian',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(_search.clear),
                    ),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              for (final m in shown)
                _RowCard(
                  icon: m.icon,
                  emoji: m.emoji,
                  color: m.color,
                  tint: m.tint,
                  title: m.label,
                  body: m.description,
                  onTap: () =>
                      m.push ? context.push(m.route) : context.go(m.route),
                ),
              if (widget.modules.isEmpty)
                _emptyState(
                  Icons.grid_view_rounded,
                  'Belum ada modul untuk role Anda. Hubungi admin untuk '
                  'mendapatkan akses.',
                )
              else if (shown.isEmpty)
                _emptyState(
                  Icons.search_off_rounded,
                  'Tidak ada modul yang cocok dengan “${_search.text.trim()}”.',
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Notifications ───────────────────────────────────────────────────────────

class LauncherNotificationsTab extends StatelessWidget {
  const LauncherNotificationsTab({
    super.key,
    required this.notices,
    required this.onRefresh,
  });

  final List<LauncherNotice> notices;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _TabHeader('Notifikasi', subtitle: 'Kabar terbaru dari modul'),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                for (final n in notices)
                  _RowCard(
                    icon: n.icon,
                    color: Lx.primary,
                    tint: Lx.primaryLight,
                    title: n.title,
                    body: n.body,
                    onTap:
                        n.route == null ? null : () => context.push(n.route!),
                  ),
                if (notices.isEmpty)
                  _emptyState(Icons.notifications_none_rounded,
                      'Belum ada kabar baru.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Profile ─────────────────────────────────────────────────────────────────

class LauncherProfileTab extends StatelessWidget {
  const LauncherProfileTab({
    super.key,
    required this.user,
    required this.onLogout,
  });

  final User? user;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final name = (user?.name ?? '').trim().isEmpty ? 'User' : user!.name.trim();
    final email = user?.email ?? '';
    final group = user?.groupName ?? '';
    final roles = user?.roleNames ?? const <String>[];

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const _TabHeader('Profil'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: Lx.card(),
            child: Column(
              children: [
                UserAvatar(size: 72, imageUrl: user?.avatar),
                const SizedBox(height: 12),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Lx.text,
                      fontSize: 19,
                      fontWeight: FontWeight.w800),
                ),
                if (email.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(email,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Lx.textSecondary, fontSize: 13)),
                  ),
                if (group.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(group,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Lx.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(height: 14),
                if (roles.isEmpty)
                  const Text('Belum ada role',
                      style: TextStyle(color: Lx.textSecondary, fontSize: 13))
                else
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final r in roles)
                        HubBadge(r, bg: Lx.primaryLight, fg: Lx.primaryDark)
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (context.watch<HomeSummaryProvider>().isModuleVisible('profile'))
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Container(
              decoration: Lx.card(),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit_outlined, color: Lx.primary),
                    title: const Text('Ubah Profil'),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: Lx.textSecondary),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const EditProfileScreen())),
                  ),
                  const Divider(height: 1, color: Lx.border),
                  ListTile(
                    leading: const Icon(Icons.lock_outline_rounded,
                        color: Lx.primary),
                    title: const Text('Ubah Password'),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: Lx.textSecondary),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ChangePasswordScreen())),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Container(
            decoration: Lx.card(),
            child: ListTile(
              leading: const Icon(Icons.info_outline_rounded, color: Lx.primary),
              title: const Text('Tentang Aplikasi'),
              subtitle: const Text('Versi dan pembaruan'),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: Lx.textSecondary),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AboutScreen())),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: const Text('Keluar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Lx.danger,
              side: const BorderSide(color: Lx.border),
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Lx.rButton),
              ),
              textStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

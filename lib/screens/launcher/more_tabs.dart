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
import '../profile/family_section.dart';
import '../profile/profile_widgets.dart' show longDate, parseBirthDate;
import '../../providers/auth_provider.dart';
import '../../update/apk_updater.dart' show UpdateInfo;
import '../../update/updater.dart';
import 'user_avatar.dart';
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

class LauncherProfileTab extends StatefulWidget {
  const LauncherProfileTab({
    super.key,
    required this.user,
    required this.onLogout,
  });

  final User? user;
  final VoidCallback onLogout;

  @override
  State<LauncherProfileTab> createState() => _LauncherProfileTabState();
}

class _LauncherProfileTabState extends State<LauncherProfileTab> {
  /// Installed version and whether a newer build is published; read once
  /// per visit of the tab, quietly.
  late final Future<UpdateInfo?> _update = appUpdater().then((u) => u.check());

  /// The tab lives in an IndexedStack, so pull-to-refresh is the way to see
  /// family changes made by the admin.
  final _family = GlobalKey<FamilySectionState>();

  void _open(Widget screen) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => screen));

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text(
            'Anda perlu masuk lagi untuk membuka data Anda di perangkat ini.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Lx.danger),
              child: const Text('Keluar')),
        ],
      ),
    );
    if (ok == true) widget.onLogout();
  }

  // ── Identity ─────────────────────────────────────────────────────────────

  Widget _hero(User? user, bool editable) {
    final name =
        (user?.name ?? '').trim().isEmpty ? 'Pengguna' : user!.name.trim();
    final roles = user?.roleNames ?? const <String>[];
    Widget chip(String text, {IconData? icon}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: Colors.white),
                const SizedBox(width: 4),
              ],
              Text(text,
                  style: Lx.metadata.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
        );

    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration:
              const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: UserAvatar(size: 76, imageUrl: user?.avatar),
        ),
        if (editable)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Lx.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child:
                  const Icon(Icons.edit_rounded, size: 13, color: Colors.white),
            ),
          ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(Lx.s20, Lx.s24, Lx.s20, Lx.s20),
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
        children: [
          Semantics(
            button: editable,
            label: editable ? 'Ubah profil dan foto' : null,
            child: GestureDetector(
              onTap: editable ? () => _open(const EditProfileScreen()) : null,
              child: avatar,
            ),
          ),
          const SizedBox(height: Lx.s12),
          Text(name,
              textAlign: TextAlign.center,
              style: Lx.userName.copyWith(color: Colors.white, fontSize: 21)),
          // Email and group are in "Info akun"; the hero keeps name and roles.
          if (roles.isNotEmpty) ...[
            const SizedBox(height: Lx.s12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in roles)
                  chip(r, icon: Icons.verified_user_outlined),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    final empty = value.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Lx.textMuted),
          const SizedBox(width: Lx.s12),
          Text(label, style: Lx.body),
          const SizedBox(width: Lx.s12),
          Expanded(
            child: Text(
              empty ? 'Belum diisi' : value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Lx.body.copyWith(
                  color: empty ? Lx.textMuted : Lx.text,
                  fontWeight: empty ? FontWeight.w400 : FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({String? title, required List<Widget> children}) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Container(
          padding: const EdgeInsets.fromLTRB(Lx.s16, Lx.s12, Lx.s16, Lx.s4),
          decoration: Lx.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Text(title.toUpperCase(),
                      style: Lx.metadata.copyWith(
                          color: Lx.textSecondary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
                ),
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: Lx.border),
                children[i],
              ],
            ],
          ),
        ),
      );

  /// One menu entry: tinted icon, title, one line of what it does.
  Widget _menu(IconData icon, Color color, Color tint, String title,
          String subtitle, VoidCallback onTap,
          {Widget? badge}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Lx.rButton),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Lx.s12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: tint, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: Lx.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Lx.cardHeading.copyWith(fontSize: 14)),
                    Text(subtitle, style: Lx.metadata),
                  ],
                ),
              ),
              if (badge != null) ...[badge, const SizedBox(width: 4)],
              const Icon(Icons.chevron_right_rounded, color: Lx.textSecondary),
            ],
          ),
        ),
      );

  Widget _aboutEntry() => FutureBuilder<UpdateInfo?>(
        future: _update,
        builder: (_, snap) {
          final newer = snap.data;
          return _menu(
            Icons.info_outline_rounded,
            const Color(0xFF0D9488),
            const Color(0xFFCCFBF1),
            'Tentang Aplikasi',
            newer == null
                ? 'Versi dan pembaruan'
                : 'Versi ${newer.versionName} tersedia',
            () => _open(const AboutScreen()),
            badge: newer == null
                ? null
                : Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Lx.danger,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('Baru',
                        style: Lx.metadata.copyWith(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final editable =
        context.watch<HomeSummaryProvider>().isModuleVisible('profile');

    final birthDate = parseBirthDate(user?.birthDate);
    final birth = birthDate == null ? '' : longDate(birthDate);

    return RefreshIndicator(
      onRefresh: () => Future.wait([
        context.read<AuthProvider>().refreshProfile(),
        _family.currentState?.reload() ?? Future<void>.value(),
      ]),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          const _TabHeader('Profil'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _hero(user, editable),
          ),
          _card(title: 'Info akun', children: [
            _infoRow(Icons.badge_outlined, 'User ID', user?.userId ?? ''),
            _infoRow(Icons.mail_outline_rounded, 'Email', user?.email ?? ''),
            _infoRow(Icons.phone_outlined, 'No. HP', user?.phone ?? ''),
            if (editable) _infoRow(Icons.cake_outlined, 'Tanggal lahir', birth),
            _infoRow(Icons.groups_outlined, 'Kelompok', user?.groupName ?? ''),
          ]),
          if (editable) FamilySection(key: _family),
          if (editable)
            _card(title: 'Akun', children: [
              _menu(
                  Icons.person_outline_rounded,
                  Lx.primary,
                  Lx.primaryLight,
                  'Ubah Profil',
                  'Data diri, kontak, dan foto',
                  () => _open(const EditProfileScreen())),
              _menu(
                  Icons.lock_outline_rounded,
                  const Color(0xFF7C3AED),
                  Lx.secondaryLight,
                  'Ubah Password',
                  'Ganti kata sandi untuk masuk',
                  () => _open(const ChangePasswordScreen())),
            ]),
          _card(title: 'Aplikasi', children: [_aboutEntry()]),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: OutlinedButton.icon(
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: const Text('Keluar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Lx.danger,
                side: BorderSide(color: Lx.danger.withOpacity(0.35)),
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
      ),
    );
  }
}

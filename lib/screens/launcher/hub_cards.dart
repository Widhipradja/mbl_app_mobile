import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/launcher_tokens.dart';
import 'launcher_models.dart';

/// Per-type look of an Information Hub card: badge, icon tile and button.
class HubStyle {
  const HubStyle({
    required this.label,
    required this.cta,
    required this.icon,
    required this.color,
    required this.badgeBg,
    required this.badgeFg,
  });

  final String label;
  final String cta;
  final IconData icon;

  /// Category colour: icon and progress fill.
  final Color color;
  final Color badgeBg;

  /// Darker shade of [color] so the badge text stays readable.
  final Color badgeFg;

  static HubStyle of(HubType type) {
    switch (type) {
      case HubType.event:
        return const HubStyle(
          label: 'Kegiatan',
          cta: 'Lihat Detail',
          icon: Icons.event_outlined,
          color: Lx.warning,
          badgeBg: Color(0xFFFFEDD5),
          badgeFg: Color(0xFFC2410C),
        );
      case HubType.fundraising:
        return const HubStyle(
          label: 'Penggalangan Dana',
          cta: 'Donasi',
          icon: Icons.volunteer_activism_outlined,
          color: Lx.fundraising,
          badgeBg: Color(0xFFFCE7F3),
          badgeFg: Color(0xFFBE185D),
        );
      case HubType.campaign:
        return const HubStyle(
          label: 'Kampanye',
          cta: 'Ikut Serta',
          icon: Icons.emoji_events_outlined,
          color: Lx.success,
          badgeBg: Color(0xFFDCFCE7),
          badgeFg: Color(0xFF15803D),
        );
      case HubType.announcement:
        return const HubStyle(
          label: 'Pengumuman',
          cta: 'Selengkapnya',
          icon: Icons.campaign_outlined,
          color: Lx.info,
          badgeBg: Lx.primaryLight,
          badgeFg: Color(0xFF1D4ED8),
        );
    }
  }
}

class HubBadge extends StatelessWidget {
  const HubBadge(this.label, {super.key, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: Lx.metadata
              .copyWith(color: fg, fontWeight: FontWeight.w600, fontSize: 11),
        ),
      );
}

/// White card for one [HubItem]. The whole card opens the item's detail
/// screen; the button sits on the right when the card is wide enough and
/// below the text otherwise.
class HubCard extends StatelessWidget {
  const HubCard(this.item, {super.key});

  final HubItem item;

  @override
  Widget build(BuildContext context) {
    final style = HubStyle.of(item.type);
    void open() => context.push(item.route);

    // An icon in the card's corner in place of a text button: the whole card
    // opens the detail screen anyway.
    final cta = _Cta(label: style.cta, onTap: open);

    return Material(
      color: Lx.surface,
      borderRadius: BorderRadius.circular(Lx.rCard),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: open,
        child: Padding(
          padding: const EdgeInsets.all(Lx.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _leading(style),
                  const SizedBox(width: Lx.s12),
                  Expanded(child: _content(style, cta)),
                ],
              ),
              // Full width, so a description can be read in full.
              if (item.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: Lx.s8),
                  child: Text(item.description, style: Lx.body),
                ),
              if (item.progress != null) _progress(style),
              if (item.others.isNotEmpty) _others(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _leading(HubStyle style) {
    final d = item.date;
    if (d != null) {
      // Same block as the Kegiatan module: weekday, day, month, in the
      // colour of the event's level.
      final level = item.level.isEmpty ? null : EventLevel.of(item.level);
      final fg = level?.fg ?? Lx.primaryDark;
      final small =
          Lx.metadata.copyWith(color: fg, fontWeight: FontWeight.w700, fontSize: 11);
      return Container(
        width: 50,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: level?.tint ?? Lx.primaryLight,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(daysShort[d.weekday - 1], style: small),
            Text('${d.day}',
                style: Lx.userName.copyWith(color: fg, height: 1.1)),
            Text(monthsShort[d.month - 1],
                style: small.copyWith(fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }
    return HubIconTile(style: style, size: 50, donated: item.donated);
  }

  Widget _content(HubStyle style, Widget cta) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  HubBadge(style.label, bg: style.badgeBg, fg: style.badgeFg),
                  if (item.tag.isNotEmpty)
                    HubBadge(item.tag, bg: Lx.primaryLight, fg: Lx.primaryDark),
                ],
              ),
            ),
            const SizedBox(width: Lx.s8),
            cta,
          ],
        ),
        const SizedBox(height: 6),
        if (item.agenda.isNotEmpty)
          for (final e in item.agenda) _agendaRow(e)
        else ...[
          // An event: time first, then its whole name.
          if (item.lead.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  const Icon(Icons.schedule_outlined,
                      size: 15, color: Lx.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.lead,
                      style: Lx.metadata.copyWith(
                          color: Lx.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          Text(
            item.title,
            maxLines: item.type == HubType.event ? null : 2,
            overflow: item.type == HubType.event ? null : TextOverflow.ellipsis,
            style: Lx.cardHeading,
          ),
        ],
        if (item.amounts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(item.amounts, style: Lx.metadata),
          ),
        for (final (icon, text) in item.meta)
          Padding(
            padding: const EdgeInsets.only(top: Lx.s4),
            child: Row(
              children: [
                Icon(icon, size: 16, color: Lx.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Lx.body.copyWith(height: 1.3),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _progress(HubStyle style) {
    final progress = item.progress!;
    return Padding(
      padding: const EdgeInsets.only(top: Lx.s8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 6,
          backgroundColor: style.badgeBg,
          valueColor: AlwaysStoppedAnimation(style.color),
          semanticsLabel: 'Dana terkumpul',
          semanticsValue: '${(progress * 100).round()}%',
        ),
      ),
    );
  }

  /// The events after the main one: small, one line each.
  Widget _others(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Lx.s8),
      child: Container(
        padding: const EdgeInsets.only(top: Lx.s4),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Lx.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: Text('Selanjutnya',
                  style: Lx.metadata.copyWith(fontWeight: FontWeight.w600)),
            ),
            for (final e in item.others) _otherRow(context, e),
          ],
        ),
      ),
    );
  }

  /// One of today's events: time, then the whole name (and place).
  Widget _agendaRow(NextEventInfo e) {
    final level = EventLevel.of(e.level);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6, right: 8),
            decoration:
                BoxDecoration(color: level.color, shape: BoxShape.circle),
          ),
          Text(
            e.timeStart.isEmpty ? '—' : e.timeStart,
            style: Lx.moduleLabel.copyWith(color: Lx.primary, height: 1.35),
          ),
          const SizedBox(width: Lx.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title, style: Lx.moduleLabel.copyWith(height: 1.35)),
                if (e.location.isNotEmpty) Text(e.location, style: Lx.metadata),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A later event: day and time first, then its whole name.
  Widget _otherRow(BuildContext context, NextEventInfo e) {
    final d = e.date;
    final when = [
      if (d != null)
        '${daysShort[d.weekday - 1]}, ${d.day} ${monthsShort[d.month - 1]}',
      if (e.timeStart.isNotEmpty) e.timeStart,
    ].join(' · ');
    return InkWell(
      onTap: () => context.push(item.route),
      borderRadius: BorderRadius.circular(Lx.rSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(top: 5, right: 8),
              decoration: BoxDecoration(
                  color: EventLevel.of(e.level).color, shape: BoxShape.circle),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (when.isNotEmpty) Text(when, style: Lx.metadata),
                  Text(
                    e.title,
                    style: Lx.metadata
                        .copyWith(color: Lx.text, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The square icon of a card. For a fundraising the member has given to it
/// carries a small green check: the mark for "sudah berdonasi", in place of
/// words.
class HubIconTile extends StatelessWidget {
  const HubIconTile({
    super.key,
    required this.style,
    required this.size,
    required this.donated,
  });

  final HubStyle style;
  final double size;
  final bool donated;

  static const _green = Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: style.badgeBg,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(style.icon, size: size * 0.52, color: style.color),
    );
    if (!donated) return tile;
    return Semantics(
      label: 'Sudah berdonasi',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          tile,
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: _green,
                shape: BoxShape.circle,
                border: Border.all(color: Lx.surface, width: 2),
              ),
              child: const Icon(Icons.check_rounded,
                  size: 11, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Round arrow in a card's corner: opens the detail or the full list. Its
/// [label] is what a screen reader and the tooltip say.
class _Cta extends StatelessWidget {
  const _Cta({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: Lx.primaryLight,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: const SizedBox(
              width: 32,
              height: 32,
              child: Icon(Icons.arrow_forward_rounded,
                  size: 18, color: Lx.primary),
            ),
          ),
        ),
      ),
    );
  }
}

/// A white card carrying a status line: loading, empty, or an error with an
/// optional retry.
class HubStateCard extends StatelessWidget {
  const HubStateCard({
    super.key,
    required this.icon,
    required this.text,
    this.onRetry,
    this.loading = false,
  });

  const HubStateCard.loading({super.key})
      : icon = Icons.hourglass_empty_rounded,
        text = 'Memuat…',
        onRetry = null,
        loading = true;

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final failed = onRetry != null;
    return Container(
      padding: const EdgeInsets.all(Lx.s12),
      decoration: Lx.card(),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: failed ? const Color(0xFFFEF2F2) : Lx.primaryLight,
              shape: BoxShape.circle,
            ),
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon,
                    size: 20, color: failed ? Lx.danger : Lx.primary),
          ),
          const SizedBox(width: Lx.s12),
          Expanded(child: Text(text, style: Lx.body)),
          if (failed)
            FilledButton.tonal(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact),
              child: const Text('Coba lagi'),
            ),
        ],
      ),
    );
  }
}

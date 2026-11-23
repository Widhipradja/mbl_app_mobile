import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import '../../services/api_service.dart';
import 'profile_widgets.dart' show parseBirthDate, profileFailure;

/// One row of `GET /api/m/v1/profile/family`.
class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.relationship,
    required this.birthDate,
    required this.isHead,
    required this.isMe,
  });

  final String id;
  final String firstName;
  final String lastName;

  /// Free text from the admin ("suami", "anak", ...); "" when not filled.
  final String relationship;
  final DateTime? birthDate;
  final bool isHead;
  final bool isMe;

  factory FamilyMember.fromJson(Map<dynamic, dynamic> j) {
    String s(String k) => j[k]?.toString().trim() ?? '';
    return FamilyMember(
      id: s('id'),
      firstName: s('first_name'),
      lastName: s('last_name'),
      relationship: s('relationship'),
      birthDate: parseBirthDate(s('birth_date')),
      isHead: j['is_head_of_family'] == true,
      isMe: j['is_me'] == true,
    );
  }

  String get name => [firstName, lastName].where((e) => e.isNotEmpty).join(' ');

  String get initials {
    final parts = [firstName, lastName].where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  /// "34 tahun", "5 bulan", or null without a birth date.
  String? ageLabel(DateTime today) {
    final b = birthDate;
    if (b == null || b.isAfter(today)) return null;
    var months = (today.year - b.year) * 12 + today.month - b.month;
    if (today.day < b.day) months--;
    if (months >= 12) return '${months ~/ 12} tahun';
    return months <= 0 ? 'Di bawah 1 bulan' : '$months bulan';
  }
}

/// "Keluarga" card of the profile tab. Loads on its own, apart from the
/// profile, so a failure only affects this card. Read-only: the data is kept
/// by the admin, so no row opens an editor.
class FamilySection extends StatefulWidget {
  const FamilySection({super.key});

  @override
  State<FamilySection> createState() => FamilySectionState();
}

class FamilySectionState extends State<FamilySection> {
  bool _loading = true;
  String? _error;
  List<FamilyMember> _members = const [];

  @override
  void initState() {
    super.initState();
    reload();
  }

  /// Fetches the list again; the current one stays on screen meanwhile.
  Future<void> reload() async {
    setState(() {
      _loading = _members.isEmpty;
      _error = null;
    });
    try {
      final resp = await ApiService().getProfileFamily();
      final data = resp.data;
      final list = data is Map ? data['members'] : null;
      if (list is! List) throw const FormatException('family');
      // Already sorted by the server: kept as it is.
      final members = [
        for (final m in list)
          if (m is Map) FamilyMember.fromJson(m),
      ];
      if (mounted) setState(() => _members = members);
    } catch (e) {
      debugPrint('FamilySection load error: $e');
      // 401 logs out through the app's global handler.
      if (mounted) {
        setState(() => _error =
            profileFailure(e, fallback: 'Data keluarga gagal dimuat.'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // An empty list is a normal answer (account not linked to exactly one
    // member): the card is hidden, never an error.
    if (!_loading && _error == null && _members.isEmpty) {
      return const SizedBox.shrink();
    }
    final onlyMe = _members.length == 1 && _members.first.isMe;
    final today = DateTime.now();
    final rows = <Widget>[
      if (_loading)
        for (var i = 0; i < 2; i++) const _SkeletonRow()
      else if (_error != null && _members.isEmpty)
        _errorBox()
      else ...[
        for (final m in _members) _MemberRow(m, today),
        if (onlyMe) _note('Belum ada anggota keluarga lain'),
      ],
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(Lx.s16, Lx.s12, Lx.s16, Lx.s12),
        decoration: Lx.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Row(
                children: [
                  Text('KELUARGA',
                      style: Lx.metadata.copyWith(
                          color: Lx.textSecondary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
                  const Spacer(),
                  if (!_loading && _members.length > 1)
                    Text('${_members.length} anggota', style: Lx.metadata),
                ],
              ),
            ),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: Lx.border),
              rows[i],
            ],
            if (!_loading && _members.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Lx.s8),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 14, color: Lx.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          'Data keluarga dikelola admin. Hubungi admin bila '
                          'ada yang perlu diubah.',
                          style: Lx.metadata.copyWith(color: Lx.textMuted)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _note(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Lx.s12),
        child: Text(text,
            textAlign: TextAlign.center,
            style: Lx.metadata.copyWith(color: Lx.textMuted)),
      );

  Widget _errorBox() => Padding(
        padding: const EdgeInsets.only(top: Lx.s8),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 28, color: Lx.textMuted),
            const SizedBox(height: Lx.s8),
            Text(_error!, textAlign: TextAlign.center, style: Lx.metadata),
            TextButton.icon(
              onPressed: reload,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      );
}

class _MemberRow extends StatelessWidget {
  const _MemberRow(this.m, this.today);

  final FamilyMember m;
  final DateTime today;

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static Widget _badge(String text, Color color, Color tint,
          {IconData? icon}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
            color: tint, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 3),
            ],
            Text(text,
                style: Lx.metadata.copyWith(
                    fontSize: 10.5, color: color, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final age = m.ageLabel(today);
    final relation = _capitalize(m.relationship);
    final details = [
      if (relation.isNotEmpty) relation,
      if (age != null) age,
    ].join(' · ');

    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Lx.s12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: m.isMe ? Lx.primary : Lx.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Text(m.initials,
                  style: Lx.button.copyWith(
                      fontSize: 14, color: m.isMe ? Colors.white : Lx.primary)),
            ),
            const SizedBox(width: Lx.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(m.name.isEmpty ? '—' : m.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Lx.cardHeading.copyWith(fontSize: 14)),
                      ),
                      if (m.isMe) ...[
                        const SizedBox(width: 6),
                        _badge('Saya', Colors.white, Lx.primary),
                      ],
                    ],
                  ),
                  if (details.isNotEmpty || m.isHead) ...[
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (m.isHead)
                          _badge('Kepala keluarga', const Color(0xFFB45309),
                              const Color(0xFFFEF3C7),
                              icon: Icons.star_rounded),
                        if (details.isNotEmpty)
                          Text(details, style: Lx.metadata),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder row while the list loads.
class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
              color: Lx.border, borderRadius: BorderRadius.circular(6)),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Lx.s12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration:
                const BoxDecoration(color: Lx.border, shape: BoxShape.circle),
          ),
          const SizedBox(width: Lx.s12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [bar(140, 12), const SizedBox(height: 8), bar(90, 10)],
          ),
        ],
      ),
    );
  }
}

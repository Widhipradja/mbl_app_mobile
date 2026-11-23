import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';

const monthNames = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', //
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

/// The gateway answers 403 `{"code":"upstream_unauthorized"}` when the
/// shodaqoh service does not accept this account. The session is fine (a 401
/// is what ends it), so this must not be shown as "no access to this data".
bool isUpstreamUnauthorized(Object e) {
  if (e is! DioException || e.response?.statusCode != 403) return false;
  final d = e.response?.data;
  return d is Map && d['code'] == 'upstream_unauthorized';
}

const upstreamUnauthorizedText =
    'Akun Anda belum diizinkan di layanan shodaqoh. Hubungi admin.';

/// A user-facing reason for a failed load. The server's own message is in
/// English and fixed, so it is never shown; the status code decides.
String ledgerFailure(Object e) {
  if (e is DioException) {
    switch (e.response?.statusCode) {
      case 401:
        return 'Sesi Anda berakhir. Silakan masuk lagi.';
      case 403:
        return isUpstreamUnauthorized(e)
            ? upstreamUnauthorizedText
            : 'Anda tidak punya akses ke data ini.';
      case 404:
        return 'Akun Anda belum terhubung ke data jamaah.';
      case 409:
        return 'Akun Anda terhubung ke lebih dari satu data jamaah. '
            'Hubungi admin.';
      case 502:
      case 503:
      case 504:
        return 'Layanan sedang tidak tersedia. Coba lagi sebentar lagi.';
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Tidak bisa terhubung ke server. Periksa koneksi Anda.';
    }
  }
  return 'Data gagal dimuat.';
}

/// Page frame shared by the ledger modules: title, a period switcher
/// (previous / label / next), pull-to-refresh, and the loading, error and
/// empty states.
class LedgerPage extends StatelessWidget {
  const LedgerPage({
    super.key,
    required this.title,
    required this.onRefresh,
    required this.loading,
    required this.error,
    required this.children,
    required this.emptyText,
    this.header,
    this.periodLabel,
    this.previousTooltip = '',
    this.nextTooltip = '',
    this.onPrevious,
    this.onNext,
  });

  final String title;

  /// Shown above the period switcher, e.g. a monthly / yearly toggle.
  final Widget? header;

  /// The period switcher (previous / label / next) is hidden without a label.
  /// A null callback disables its button: the end of the available range.
  final String? periodLabel;
  final String previousTooltip;
  final String nextTooltip;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final Future<void> Function() onRefresh;
  final bool loading;
  final String? error;

  /// Empty means "no data": [emptyText] is shown.
  final List<Widget> children;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Lx.theme,
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Column(
          children: [
            if (header != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(Lx.s16, 0, Lx.s16, Lx.s8),
                child: header,
              ),
            if (periodLabel != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(Lx.s16, 0, Lx.s16, Lx.s8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Lx.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Lx.border),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: previousTooltip,
                        visualDensity: VisualDensity.compact,
                        onPressed: onPrevious,
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Expanded(
                        child: Text(
                          periodLabel!,
                          textAlign: TextAlign.center,
                          style: Lx.cardHeading,
                        ),
                      ),
                      IconButton(
                        tooltip: nextTooltip,
                        visualDensity: VisualDensity.compact,
                        onPressed: onNext,
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(Lx.s16, Lx.s8, Lx.s16,
                      Lx.s24 + MediaQuery.paddingOf(context).bottom),
                  children: [
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (error != null)
                      _notice(Icons.cloud_off_outlined, error!,
                          onRetry: onRefresh)
                    else if (children.isEmpty)
                      _notice(Icons.inbox_outlined, emptyText)
                    else
                      ...children,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notice(IconData icon, String text,
      {Future<void> Function()? onRetry}) {
    return Padding(
      padding: const EdgeInsets.only(top: 56),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
                color: Lx.primaryLight, shape: BoxShape.circle),
            child: Icon(icon, size: 30, color: Lx.primary),
          ),
          const SizedBox(height: Lx.s16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Lx.s24),
            child: Text(text,
                textAlign: TextAlign.center,
                style: Lx.body.copyWith(height: 1.45)),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: Lx.s8),
            FilledButton.tonal(
                onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ],
      ),
    );
  }
}

/// Summary card: a label, one big total, a caption and optional breakdown
/// boxes, with an optional icon on the right.
class LedgerTotalCard extends StatelessWidget {
  const LedgerTotalCard({
    super.key,
    required this.label,
    required this.total,
    this.caption = '',
    this.breakdown = const [],
    this.emoji,
    this.icon,
    this.colors = const [Lx.bannerStart, Lx.primary],
  });

  final String label;
  final String total;
  final String caption;

  /// (label, formatted amount) cells shown under the total.
  final List<(String, String)> breakdown;

  /// Kept for older callers; [icon] is preferred so every module uses the
  /// same outlined style.
  final String? emoji;
  final IconData? icon;

  /// Gradient of the card.
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    const soft = Color(0xE6FFFFFF);
    return Container(
      margin: const EdgeInsets.only(bottom: Lx.s12),
      padding: const EdgeInsets.all(Lx.s20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Lx.rSection),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: Lx.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Lx.metadata.copyWith(color: soft)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(total,
                          maxLines: 1,
                          style: Lx.userName.copyWith(
                              color: Colors.white,
                              fontSize: 30,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ])),
                    ),
                    if (caption.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(caption,
                            style: Lx.metadata.copyWith(color: soft)),
                      ),
                  ],
                ),
              ),
              if (icon != null)
                Container(
                  width: 48,
                  height: 48,
                  margin: const EdgeInsets.only(left: Lx.s12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(Lx.rButton + 2),
                  ),
                  child: Icon(icon, color: Colors.white),
                )
              else if (emoji != null)
                Padding(
                  padding: const EdgeInsets.only(left: Lx.s12),
                  child: ExcludeSemantics(
                    child: Text(emoji!,
                        style: const TextStyle(fontSize: 40, height: 1.1)),
                  ),
                ),
            ],
          ),
          if (breakdown.isNotEmpty) ...[
            const SizedBox(height: Lx.s16),
            Row(
              children: [
                for (var i = 0; i < breakdown.length; i++) ...[
                  if (i > 0) const SizedBox(width: Lx.s8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Lx.s8, vertical: Lx.s8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(Lx.rButton),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(breakdown[i].$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Lx.metadata.copyWith(color: soft)),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(breakdown[i].$2,
                                maxLines: 1,
                                style: Lx.button.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';

const monthNames = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', //
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

/// A user-facing reason for a failed load. The server's own message is in
/// English and fixed, so it is never shown; the status code decides.
String ledgerFailure(Object e) {
  if (e is DioException) {
    switch (e.response?.statusCode) {
      case 401:
        return 'Sesi Anda berakhir. Silakan masuk lagi.';
      case 403:
        return 'Anda tidak punya akses ke data ini.';
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
                padding: const EdgeInsets.fromLTRB(Lx.s8, 0, Lx.s8, Lx.s8),
                child: Container(
                  decoration: Lx.card(),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: previousTooltip,
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
      padding: const EdgeInsets.only(top: 64),
      child: Column(
        children: [
          Icon(icon, size: 44, color: Lx.border),
          const SizedBox(height: Lx.s12),
          Text(text,
              textAlign: TextAlign.center,
              style: Lx.body.copyWith(height: 1.4)),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}

/// Blue summary card: a label, one big total and optional breakdown cells.
class LedgerTotalCard extends StatelessWidget {
  const LedgerTotalCard({
    super.key,
    required this.label,
    required this.total,
    this.caption = '',
    this.breakdown = const [],
    this.emoji,
  });

  final String label;
  final String total;
  final String caption;

  /// (label, formatted amount) cells shown under the total.
  final List<(String, String)> breakdown;

  /// Large picture on the right of the card (a goat for kurban).
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Lx.s12),
      padding: const EdgeInsets.all(Lx.s16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Lx.rSection),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Lx.bannerStart, Lx.skyBlue],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: Lx.metadata
                        .copyWith(color: Colors.white.withOpacity(0.9))),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(total,
                      maxLines: 1,
                      style: Lx.sectionHeading
                          .copyWith(color: Colors.white, fontSize: 26)),
                ),
                if (caption.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(caption,
                        style: Lx.metadata
                            .copyWith(color: Colors.white.withOpacity(0.9))),
                  ),
                if (breakdown.isNotEmpty) ...[
                  const SizedBox(height: Lx.s12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < breakdown.length; i++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                                right: i == breakdown.length - 1 ? 0 : Lx.s8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(breakdown[i].$1,
                                    style: Lx.metadata.copyWith(
                                        color: Colors.white.withOpacity(0.85))),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(breakdown[i].$2,
                                      maxLines: 1,
                                      style: Lx.button
                                          .copyWith(color: Colors.white)),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (emoji != null)
            Padding(
              padding: const EdgeInsets.only(left: Lx.s12),
              child: ExcludeSemantics(
                child: Text(emoji!,
                    style: const TextStyle(fontSize: 44, height: 1.1)),
              ),
            ),
        ],
      ),
    );
  }
}

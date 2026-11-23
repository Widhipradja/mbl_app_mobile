import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/launcher_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../providers/home_summary_provider.dart';
import '../../widgets/app_ui.dart';
import 'finance_data.dart';

/// Submissions waiting for approval. KU can approve or reject; whoever
/// submitted one can cancel it.
class FinancePendingScreen extends StatefulWidget {
  const FinancePendingScreen({super.key});

  @override
  State<FinancePendingScreen> createState() => _FinancePendingScreenState();
}

class _FinancePendingScreenState extends State<FinancePendingScreen> {
  List<FinanceSubmission>? _items;
  String? _error;
  String? _busy;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await financeRepo.pending();
      if (mounted) setState(() => _items = list);
    } catch (e) {
      debugPrint('FinancePending load error: $e');
      if (mounted) setState(() => _error = financeError(e));
    }
  }

  Future<String?> _askReason() {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak pengajuan'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Alasan (wajib)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(context, c.text.trim()),
              child: const Text('Tolak')),
        ],
      ),
    );
  }

  Future<void> _decide(FinanceSubmission s, String action) async {
    String? reason;
    if (action == 'reject') {
      reason = await _askReason();
      if (reason == null || reason.isEmpty) return;
    }
    setState(() => _busy = s.id);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await financeRepo.decide(s.id, action, reason: reason);
      messenger.showSnackBar(SnackBar(
          content: Text(action == 'approve'
              ? 'Disetujui.'
              : action == 'reject'
                  ? 'Ditolak.'
                  : 'Dibatalkan.')));
      await _load();
    } catch (e) {
      debugPrint('FinancePending $action error: $e');
      messenger.showSnackBar(SnackBar(content: Text(financeError(e))));
      // 409: someone else decided it; the list is stale.
      await _load();
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Widget _card(FinanceSubmission s, {required bool ku, required String me}) {
    final busy = _busy == s.id;
    final mine = me.isNotEmpty && s.submittedBy == me;
    return Container(
      padding: const EdgeInsets.all(Lx.s16),
      margin: const EdgeInsets.only(bottom: Lx.s12),
      decoration: Lx.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryAvatar(s.accountName, income: s.isIncome),
              const SizedBox(width: Lx.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.accountName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Lx.cardHeading.copyWith(fontSize: 14)),
                    Text(s.isIncome ? 'Pemasukan' : 'Pengeluaran',
                        style: Lx.metadata),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(signedRp(s.amount, s.isIncome),
                      style: Lx.cardHeading.copyWith(
                          color: moneyColor(s.isIncome),
                          fontFeatures: tabular)),
                  const SizedBox(height: 2),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEDD5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('Menunggu',
                        style: Lx.metadata.copyWith(
                            fontSize: 10,
                            color: const Color(0xFFC2410C),
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
          if (s.description.isNotEmpty && s.description != s.accountName) ...[
            const SizedBox(height: Lx.s12),
            Text(s.description, style: Lx.body.copyWith(color: Lx.text)),
          ],
          if (s.transcript.isNotEmpty) ...[
            const SizedBox(height: Lx.s8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Lx.s8),
              decoration: BoxDecoration(
                color: Lx.background,
                borderRadius: BorderRadius.circular(Lx.rSmall),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.mic_rounded, size: 14, color: Lx.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Text('"${s.transcript}"', style: Lx.metadata)),
                ],
              ),
            ),
          ],
          const SizedBox(height: Lx.s8),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded,
                  size: 14, color: Lx.textMuted),
              const SizedBox(width: 4),
              Text(mine ? 'Anda' : s.submittedBy, style: Lx.metadata),
              const SizedBox(width: Lx.s12),
              const Icon(Icons.calendar_today_outlined,
                  size: 13, color: Lx.textMuted),
              const SizedBox(width: 4),
              Text(dateShort(s.date), style: Lx.metadata),
            ],
          ),
          if (ku || mine) ...[
            const SizedBox(height: Lx.s12),
            if (busy)
              const Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)))
            else
              Row(
                children: [
                  if (ku) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _decide(s, 'reject'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Lx.danger),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Tolak'),
                      ),
                    ),
                    const SizedBox(width: Lx.s8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _decide(s, 'approve'),
                        style: FilledButton.styleFrom(
                            backgroundColor: Lx.success),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Setujui'),
                      ),
                    ),
                  ],
                  if (mine) ...[
                    if (ku) const SizedBox(width: Lx.s8),
                    if (!ku) const Spacer(),
                    TextButton(
                      onPressed: () => _decide(s, 'cancel'),
                      child: const Text('Batalkan'),
                    ),
                  ],
                ],
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final ku = context
        .watch<HomeSummaryProvider>()
        .hasRole('KU', user?.roleNames ?? const []);
    final me = user?.userId ?? '';
    final items = _items;
    final total = (items ?? const <FinanceSubmission>[])
        .fold<int>(0, (a, s) => a + (s.isIncome ? s.amount : -s.amount));
    return Theme(
      data: Lx.theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Menunggu Persetujuan')),
        body: _error != null
            ? Center(child: RetryState(_error!, onRetry: _load))
            : items == null
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                          Lx.s16, 0, Lx.s16, Lx.s24),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: Lx.s12),
                          child: Text(
                              ku
                                  ? 'Sebagai bendahara, Anda bisa menyetujui '
                                      'atau menolak. Yang disetujui langsung '
                                      'masuk saldo kas.'
                                  : 'Pengajuan Anda masuk saldo setelah '
                                      'disetujui bendahara. Anda bisa '
                                      'membatalkan selama masih menunggu.',
                              style: Lx.body),
                        ),
                        if (items.isEmpty)
                          const SectionCard(
                            child: EmptyState(
                              icon: Icons.task_alt_rounded,
                              text: 'Tidak ada yang menunggu. Semua sudah '
                                  'diputuskan.',
                            ),
                          )
                        else ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: Lx.s8),
                            child: Text(
                                '${items.length} pengajuan · '
                                'pengaruh ke saldo ${total < 0 ? '−' : '+'}${rp(total.abs())}',
                                style: Lx.metadata.copyWith(
                                    color: Lx.text,
                                    fontWeight: FontWeight.w600)),
                          ),
                          for (final s in items) _card(s, ku: ku, me: me),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }
}

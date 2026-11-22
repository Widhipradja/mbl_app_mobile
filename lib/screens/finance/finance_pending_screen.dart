import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/launcher_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../providers/home_summary_provider.dart';
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
    final color = s.isIncome ? Lx.success : Lx.danger;
    final busy = _busy == s.id;
    final mine = me.isNotEmpty && s.submittedBy == me;
    return Container(
      padding: const EdgeInsets.all(Lx.s12),
      margin: const EdgeInsets.only(bottom: Lx.s12),
      decoration: Lx.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(s.accountName,
                      style: Lx.cardHeading.copyWith(color: Lx.secondary))),
              Text('${s.isIncome ? '+' : '−'}${rp(s.amount)}',
                  style: Lx.cardHeading.copyWith(color: color)),
            ],
          ),
          const SizedBox(height: 4),
          Text(s.description, style: Lx.body),
          if (s.transcript.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.mic_rounded, size: 14, color: Lx.textMuted),
                const SizedBox(width: 4),
                Expanded(child: Text('"${s.transcript}"', style: Lx.metadata)),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Text('${s.submittedBy} · ${dateShort(s.date)}', style: Lx.metadata),
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
                      child: FilledButton(
                        onPressed: () => _decide(s, 'approve'),
                        child: const Text('Setujui'),
                      ),
                    ),
                    const SizedBox(width: Lx.s8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _decide(s, 'reject'),
                        child: const Text('Tolak'),
                      ),
                    ),
                  ],
                  if (mine) ...[
                    if (ku) const SizedBox(width: Lx.s8),
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
    return Theme(
      data: Lx.theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Menunggu Persetujuan')),
        body: _error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, style: Lx.body),
                    TextButton(
                        onPressed: _load, child: const Text('Coba lagi')),
                  ],
                ),
              )
            : items == null
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(Lx.s16),
                      children: [
                        if (items.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 64),
                            child: Center(
                                child: Text('Tidak ada yang menunggu.',
                                    style: Lx.body)),
                          ),
                        for (final s in items) _card(s, ku: ku, me: me),
                      ],
                    ),
                  ),
      ),
    );
  }
}

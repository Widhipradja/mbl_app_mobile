import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import '../../widgets/app_ui.dart';
import '../finance/finance_data.dart' show rp, dateShort;
import 'budget_data.dart';

// ── Transactions ────────────────────────────────────────────────────────────

/// A transaction as one row: category icon, what it was, the category (and
/// date), and the signed amount. [isIncome] is null when the type is unknown.
class BudgetTxnRow extends StatelessWidget {
  const BudgetTxnRow({
    super.key,
    required this.txn,
    required this.isIncome,
    this.showDate = false,
    this.onTap,
  });

  final BudgetTxn txn;
  final bool? isIncome;
  final bool showDate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cat = txn.categoryName.isEmpty ? 'Tanpa kategori' : txn.categoryName;
    final title = txn.description.isEmpty ? cat : txn.description;
    final sub = [
      if (txn.description.isNotEmpty) cat,
      if (showDate) dateShort(txn.date),
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Lx.rButton),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            CategoryAvatar(txn.categoryName, income: isIncome),
            const SizedBox(width: Lx.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Lx.cardHeading.copyWith(fontSize: 14)),
                  if (sub.isNotEmpty || txn.isVoice)
                    Row(
                      children: [
                        if (txn.isVoice) ...[
                          const Icon(Icons.mic_rounded,
                              size: 12, color: Lx.textMuted),
                          const SizedBox(width: 3),
                        ],
                        Flexible(
                          child: Text(
                              sub.isEmpty ? 'Dicatat dengan suara' : sub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Lx.metadata),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(width: Lx.s8),
            Text(signedRp(txn.amount, isIncome),
                style: Lx.cardHeading.copyWith(
                    fontSize: 14,
                    color: moneyColor(isIncome),
                    fontFeatures: tabular)),
          ],
        ),
      ),
    );
  }
}

// ── Budget progress ─────────────────────────────────────────────────────────

/// Colour of a budget's use: fine, nearly used up (80%), or over.
Color budgetColor(double percent, bool over) => over
    ? Lx.danger
    : percent >= 80
        ? Lx.warning
        : Lx.success;

/// One expense category with its budget: the name and the amount set for
/// it. The thin bar underneath shows how much of it is used (it turns orange
/// near the limit and red over it), with what is left beside it ("Sisa
/// Rp 525.000 · 35%", "Habis", "Lewat Rp 120.000 · 8%").
class BudgetProgressRow extends StatelessWidget {
  const BudgetProgressRow({super.key, required this.line, this.onTap});

  final BudgetCategoryLine line;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = budgetColor(line.percent, line.over);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Lx.rButton),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Lx.s8),
        child: Row(
          children: [
            CategoryAvatar(line.name, income: false, size: 36),
            const SizedBox(width: Lx.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(line.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Lx.cardHeading.copyWith(fontSize: 14)),
                      ),
                      const SizedBox(width: Lx.s8),
                      Text(rp(line.limit),
                          style: Lx.cardHeading
                              .copyWith(fontSize: 14, fontFeatures: tabular)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: RoundBar(
                            value: line.percent / 100, color: color, height: 6),
                      ),
                      const SizedBox(width: Lx.s8),
                      // Shrinks rather than overflow on a narrow screen.
                      Flexible(
                        flex: 3,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(budgetLeftLabel(line),
                              maxLines: 1,
                              style: Lx.metadata.copyWith(
                                  color: line.over || line.percent >= 80
                                      ? color
                                      : Lx.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: tabular)),
                        ),
                      ),
                    ],
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

/// What is left of the budget, from the server's `remaining` and `percent`
/// (used): "Sisa Rp 525.000 · 35%", "Habis" when nothing is left, "Lewat
/// Rp 120.000 · 8%" over it. The share is rounded down while some is left, so
/// "0%" never shows for a budget not yet used up.
String budgetLeftLabel(BudgetCategoryLine line) {
  final used = line.percent;
  if (line.over || used > 100) {
    final over = (used - 100).ceil();
    return 'Lewat ${rp(line.remaining.abs())} · ${over < 1 ? 1 : over}%';
  }
  if (used >= 100 || line.remaining <= 0) return 'Habis';
  final left = (100 - used).floor();
  return 'Sisa ${rp(line.remaining)} · ${left < 1 ? '<1' : left}%';
}

// ── Transaction detail ──────────────────────────────────────────────────────

/// Detail of one transaction: amount, category, date, the note a voice entry
/// was made from, and the ways to change or remove it. Returns `edit`,
/// `delete` or null.
Future<String?> showBudgetTxnDetail(
    BuildContext context, BudgetTxn t, bool? isIncome) {
  final cat = t.categoryName.isEmpty ? 'Tanpa kategori' : t.categoryName;
  Widget line(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: Lx.textMuted),
            const SizedBox(width: Lx.s12),
            SizedBox(width: 84, child: Text(label, style: Lx.body)),
            Expanded(
                child: Text(value,
                    style: Lx.body.copyWith(color: Lx.text, height: 1.4))),
          ],
        ),
      );

  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Lx.s20, 0, Lx.s20, Lx.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CategoryAvatar(t.categoryName, income: isIncome, size: 52),
            const SizedBox(height: Lx.s8),
            Text(
                isIncome == null
                    ? 'Transaksi'
                    : isIncome
                        ? 'Pemasukan'
                        : 'Pengeluaran',
                style: Lx.metadata),
            Text(signedRp(t.amount, isIncome),
                style: Lx.userName.copyWith(
                    fontSize: 26,
                    color: moneyColor(isIncome),
                    fontFeatures: tabular)),
            const SizedBox(height: Lx.s16),
            const Divider(height: 1, color: Lx.border),
            const SizedBox(height: Lx.s8),
            line(Icons.category_outlined, 'Kategori', cat),
            line(Icons.calendar_today_outlined, 'Tanggal', dateShort(t.date)),
            if (t.description.isNotEmpty)
              line(Icons.notes_rounded, 'Keterangan', t.description),
            if (t.isVoice)
              line(
                  Icons.mic_rounded,
                  'Suara',
                  t.transcript.isEmpty
                      ? 'Dicatat dengan suara'
                      : '"${t.transcript}"'),
            const SizedBox(height: Lx.s16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context, 'delete'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Lx.danger,
                        minimumSize: const Size.fromHeight(48)),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Hapus'),
                  ),
                ),
                const SizedBox(width: Lx.s12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, 'edit'),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Ubah'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

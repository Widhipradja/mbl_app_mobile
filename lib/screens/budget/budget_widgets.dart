import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import '../finance/finance_data.dart' show thousands, rp, dateShort;
import 'budget_data.dart';

/// A transaction as one compact row. [isIncome] is null when the category is
/// gone (the row is then neutral).
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
    final income = isIncome;
    final color = income == null
        ? Lx.textSecondary
        : income
            ? Lx.success
            : Lx.danger;
    final sign = income == null ? '' : (income ? '+' : '−');
    final cat = txn.categoryName.isEmpty ? 'Tanpa kategori' : txn.categoryName;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Lx.s12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(Lx.rButton),
              ),
              child: Icon(
                income == null
                    ? Icons.remove_rounded
                    : income
                        ? Icons.south_west_rounded
                        : Icons.north_east_rounded,
                size: 18,
                color: color,
              ),
            ),
            const SizedBox(width: Lx.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          txn.description.isEmpty ? cat : txn.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Lx.cardHeading,
                        ),
                      ),
                      if (txn.isVoice) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.mic_rounded,
                            size: 14, color: Lx.textMuted),
                      ],
                    ],
                  ),
                  Text(showDate ? '$cat · ${dateShort(txn.date)}' : cat,
                      style: Lx.metadata),
                ],
              ),
            ),
            const SizedBox(width: Lx.s8),
            Text('$sign${thousands(txn.amount)}',
                style: Lx.cardHeading.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

/// Budget progress of one expense category: spent against the limit. Over
/// budget turns red and says by how much; the bar stays full, never clamped
/// silently.
class BudgetProgressRow extends StatelessWidget {
  const BudgetProgressRow({super.key, required this.line});

  final BudgetCategoryLine line;

  @override
  Widget build(BuildContext context) {
    final over = line.over;
    final warn = !over && line.percent >= 80;
    final color = over
        ? Lx.danger
        : warn
            ? Lx.warning
            : Lx.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: Lx.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(line.name, style: Lx.cardHeading)),
              Text('${rp(line.spent)} / ${rp(line.limit)}', style: Lx.metadata),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (line.percent / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Lx.border,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            over
                ? 'Melebihi ${rp(-line.remaining)} (${line.percent.round()}%)'
                : 'Sisa ${rp(line.remaining)} (${line.percent.round()}%)',
            style: Lx.metadata.copyWith(color: over ? Lx.danger : null),
          ),
        ],
      ),
    );
  }
}

/// Detail of one transaction: the note a voice entry was made from, and the
/// ways to change or remove it. Returns `edit`, `delete` or null.
Future<String?> showBudgetTxnDetail(
    BuildContext context, BudgetTxn t, bool? isIncome) {
  final color = isIncome == null
      ? Lx.textSecondary
      : isIncome
          ? Lx.success
          : Lx.danger;
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Lx.s16, 0, Lx.s16, Lx.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.categoryName.isEmpty ? 'Tanpa kategori' : t.categoryName,
                style: Lx.metadata),
            Text(rp(t.amount), style: Lx.greeting.copyWith(color: color)),
            const SizedBox(height: Lx.s8),
            if (t.description.isNotEmpty) Text(t.description, style: Lx.body),
            Text(dateShort(t.date), style: Lx.metadata),
            if (t.isVoice) ...[
              const SizedBox(height: Lx.s12),
              Row(
                children: [
                  const Icon(Icons.mic_rounded, size: 14, color: Lx.textMuted),
                  const SizedBox(width: 4),
                  Text('Dicatat dengan suara', style: Lx.metadata),
                ],
              ),
              if (t.transcript.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('"${t.transcript}"', style: Lx.body),
                ),
            ],
            const SizedBox(height: Lx.s16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, 'edit'),
                    child: const Text('Ubah'),
                  ),
                ),
                const SizedBox(width: Lx.s12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, 'delete'),
                    style: OutlinedButton.styleFrom(foregroundColor: Lx.danger),
                    child: const Text('Hapus'),
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

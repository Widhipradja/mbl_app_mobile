import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import '../budget/budget_widgets.dart';
import 'finance_data.dart';

/// A transaction as one row, in the same look as Dompet Saya: category
/// icon, what it was, the category (and date), and the signed amount.
class TxnRow extends StatelessWidget {
  const TxnRow({super.key, required this.txn, this.showDate = false});

  final FinanceTxn txn;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final sub = [
      if (txn.title != txn.category) txn.category,
      if (showDate) dateShort(txn.date),
    ].where((e) => e.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CategoryAvatar(txn.category, income: txn.isIncome),
          const SizedBox(width: Lx.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(txn.title,
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
                        child: Text(sub.isEmpty ? 'Dicatat dengan suara' : sub,
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
          Text(signedRp(txn.amount, txn.isIncome),
              style: Lx.cardHeading.copyWith(
                  fontSize: 14,
                  color: moneyColor(txn.isIncome),
                  fontFeatures: tabular)),
        ],
      ),
    );
  }
}

/// Month stepper: previous, label, next.
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({
    super.key,
    required this.month,
    required this.onChanged,
    this.last,
  });

  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  /// Furthest month that may be opened (defaults to the current month).
  final DateTime? last;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final end = last ?? DateTime(now.year, now.month);
    return Row(
      children: [
        IconButton(
          tooltip: 'Bulan sebelumnya',
          onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(monthLabel(month),
              textAlign: TextAlign.center, style: Lx.sectionHeading),
        ),
        IconButton(
          tooltip: 'Bulan berikutnya',
          onPressed: month.isBefore(end)
              ? () => onChanged(DateTime(month.year, month.month + 1))
              : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

/// Small caps heading used above groups of rows.
class GroupLabel extends StatelessWidget {
  const GroupLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: Lx.s16, bottom: Lx.s4),
        child: Text(
          text.toUpperCase(),
          style: Lx.metadata.copyWith(
              color: Lx.secondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8),
        ),
      );
}

const hairline = Divider(height: 1, thickness: 1, color: Lx.border);


/// The "Catat" choice shared by Dompet Saya and Keuangan: what happened, or
/// say it. Returns `expense`, `income` or `voice`; null when dismissed.
Future<String?> showAddEntrySheet(BuildContext context) {
  Widget choice(BuildContext ctx, String value, IconData icon, Color color,
          String title, String hint) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: Lx.cardHeading),
        subtitle: Text(hint, style: Lx.metadata),
        onTap: () => Navigator.of(ctx).pop(value),
      );

  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Lx.s16, 0, Lx.s16, Lx.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            choice(ctx, 'expense', Icons.north_east_rounded, Lx.danger,
                'Pengeluaran', 'Belanja, makan, bensin, tagihan'),
            choice(ctx, 'income', Icons.south_west_rounded, Lx.success,
                'Pemasukan', 'Gaji, titipan, uang masuk lainnya'),
            choice(ctx, 'voice', Icons.mic_rounded, Lx.primary, 'Ucapkan',
                'Contoh: "beli bensin 30 ribu"'),
          ],
        ),
      ),
    ),
  );
}

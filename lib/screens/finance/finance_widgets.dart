import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import 'finance_data.dart';

/// A transaction as one compact row (no card): title and category on the
/// left, signed amount on the right.
class TxnRow extends StatelessWidget {
  const TxnRow({super.key, required this.txn, this.showDate = false});

  final FinanceTxn txn;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final color = txn.isIncome ? Lx.success : Lx.danger;
    return Padding(
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
              txn.isIncome
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
                      child: Text(txn.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Lx.cardHeading),
                    ),
                    if (txn.isVoice) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.mic_rounded,
                          size: 14, color: Lx.textMuted),
                    ],
                  ],
                ),
                Text(
                  showDate
                      ? '${txn.category} · ${dateShort(txn.date)}'
                      : txn.category,
                  style: Lx.metadata,
                ),
              ],
            ),
          ),
          const SizedBox(width: Lx.s8),
          Text(
            '${txn.isIncome ? '+' : '−'}${thousands(txn.amount)}',
            style: Lx.cardHeading.copyWith(color: color),
          ),
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

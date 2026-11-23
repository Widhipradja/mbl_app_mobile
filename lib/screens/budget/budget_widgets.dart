import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import '../finance/finance_data.dart' show thousands, rp, dateShort, monthLabel;
import 'budget_data.dart';

// ── Money ───────────────────────────────────────────────────────────────────

/// Digits that line up in columns.
const tabular = [FontFeature.tabularFigures()];

/// Income is green with "+"; spending stays in the text colour with "−", so
/// a list of expenses reads calmly instead of as a wall of red. Unknown
/// (no category) is grey without a sign.
Color moneyColor(bool? income) => income == null
    ? Lx.textSecondary
    : income
        ? Lx.success
        : Lx.text;

String signedRp(int v, bool? income) =>
    '${income == null ? '' : income ? '+' : '−'}Rp ${thousands(v)}';

// ── Category look ───────────────────────────────────────────────────────────

class CategoryLook {
  const CategoryLook(this.icon, this.color, this.tint);
  final IconData icon;
  final Color color, tint;
}

const _palette = [
  (Color(0xFF2563EB), Color(0xFFE5EEFF)),
  (Color(0xFFEA580C), Color(0xFFFFEDD5)),
  (Color(0xFF7C3AED), Color(0xFFEDE9FE)),
  (Color(0xFF0D9488), Color(0xFFCCFBF1)),
  (Color(0xFFDB2777), Color(0xFFFCE7F3)),
  (Color(0xFFCA8A04), Color(0xFFFEF9C3)),
  (Color(0xFF0891B2), Color(0xFFCFFAFE)),
  (Color(0xFF65A30D), Color(0xFFECFCCB)),
  (Color(0xFFDC2626), Color(0xFFFEE2E2)),
  (Color(0xFF4F46E5), Color(0xFFE0E7FF)),
];

/// Icon by what the name says (Indonesian and common English words).
const _iconWords = <(List<String>, IconData)>[
  (['makan', 'sarapan', 'siang', 'malam', 'kuliner', 'resto', 'food', 'jajan', 'snack'], Icons.restaurant_rounded),
  (['kopi', 'minum', 'coffee', 'teh'], Icons.local_cafe_rounded),
  (['bensin', 'bbm', 'parkir', 'tol', 'transport', 'ojek', 'grab', 'gojek', 'kendaraan', 'motor', 'mobil'], Icons.directions_car_rounded),
  (['belanja', 'groceries', 'pasar', 'sembako', 'dapur', 'shopping'], Icons.shopping_basket_rounded),
  (['pakaian', 'baju', 'fashion'], Icons.checkroom_rounded),
  (['listrik', 'pln', 'token'], Icons.bolt_rounded),
  (['air', 'pdam'], Icons.water_drop_rounded),
  (['pulsa', 'internet', 'wifi', 'data', 'telepon', 'hp'], Icons.wifi_rounded),
  (['tagihan', 'cicilan', 'kredit', 'angsuran', 'bill'], Icons.receipt_long_rounded),
  (['sewa', 'kos', 'kontrakan', 'rumah', 'rent'], Icons.home_rounded),
  (['sehat', 'obat', 'dokter', 'klinik', 'rumah sakit', 'bpjs'], Icons.medical_services_rounded),
  (['sekolah', 'pendidikan', 'kursus', 'buku', 'spp', 'kuliah'], Icons.school_rounded),
  (['anak', 'bayi', 'susu'], Icons.child_care_rounded),
  (['sedekah', 'infaq', 'infak', 'zakat', 'shodaqoh', 'donasi', 'amal', 'jariyah', 'kurban'], Icons.volunteer_activism_rounded),
  (['hiburan', 'nonton', 'film', 'game', 'liburan', 'wisata'], Icons.celebration_rounded),
  (['hadiah', 'kado', 'gift'], Icons.card_giftcard_rounded),
  (['gaji', 'salary', 'honor', 'upah'], Icons.work_rounded),
  (['bonus', 'thr', 'insentif'], Icons.stars_rounded),
  (['usaha', 'dagang', 'jualan', 'bisnis', 'toko'], Icons.storefront_rounded),
  (['investasi', 'tabungan', 'saham', 'emas', 'deposito', 'nabung'], Icons.savings_rounded),
  (['transfer', 'kiriman', 'titipan'], Icons.swap_horiz_rounded),
];

/// A stable icon and colour for a category, from its name: the same name
/// looks the same in every list, chart and form.
CategoryLook categoryLook(String name, {bool? income}) {
  final n = name.trim().toLowerCase();
  if (n.isEmpty) {
    return const CategoryLook(
        Icons.help_outline_rounded, Lx.textSecondary, Color(0xFFF1F5F9));
  }
  var icon = income == true
      ? Icons.account_balance_wallet_rounded
      : Icons.label_rounded;
  for (final (words, i) in _iconWords) {
    if (words.any(n.contains)) {
      icon = i;
      break;
    }
  }
  final hash = n.codeUnits.fold<int>(7, (h, c) => (h * 31 + c) & 0x7fffffff);
  final (color, tint) = _palette[hash % _palette.length];
  return CategoryLook(icon, color, tint);
}

/// The category's icon on its pale colour.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar(this.name,
      {super.key, this.income, this.size = 40, this.muted = false});

  final String name;
  final bool? income;
  final double size;

  /// Greyed (an inactive category).
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final look = categoryLook(name, income: income);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: muted ? const Color(0xFFF1F5F9) : look.tint,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(look.icon,
          size: size * 0.5, color: muted ? Lx.textMuted : look.color),
    );
  }
}

// ── Layout pieces ───────────────────────────────────────────────────────────

/// A white card for one section, with an optional title and action.
class BudgetCard extends StatelessWidget {
  const BudgetCard({
    super.key,
    this.title,
    this.subtitle,
    this.action,
    this.onAction,
    required this.child,
    this.padding = const EdgeInsets.all(Lx.s16),
  });

  final String? title, subtitle, action;
  final VoidCallback? onAction;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: Lx.s12),
      padding: padding,
      decoration: Lx.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title!, style: Lx.cardHeading),
                      if (subtitle != null)
                        Text(subtitle!, style: Lx.metadata),
                    ],
                  ),
                ),
                if (action != null)
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact),
                    child: Text(action!),
                  ),
              ],
            ),
            const SizedBox(height: Lx.s8),
          ],
          child,
        ],
      ),
    );
  }
}

/// Nothing to show yet, with the one thing to do about it.
class BudgetEmpty extends StatelessWidget {
  const BudgetEmpty({
    super.key,
    required this.icon,
    required this.text,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Lx.s16),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                  color: Lx.primaryLight, shape: BoxShape.circle),
              child: Icon(icon, color: Lx.primary, size: 26),
            ),
            const SizedBox(height: Lx.s12),
            Text(text, textAlign: TextAlign.center, style: Lx.body),
            if (action != null) ...[
              const SizedBox(height: Lx.s8),
              FilledButton.tonal(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      );
}

/// The failure of a screen's load, with a retry.
class BudgetRetry extends StatelessWidget {
  const BudgetRetry(this.message, {super.key, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: Lx.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 36, color: Lx.textMuted),
            const SizedBox(height: Lx.s12),
            Text(message, textAlign: TextAlign.center, style: Lx.body),
            TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      );
}

/// Pengeluaran | Pemasukan as two large tabs, each in its own colour.
class BudgetTypeToggle extends StatelessWidget {
  const BudgetTypeToggle({
    super.key,
    required this.income,
    required this.onChanged,
    this.expenseLabel = 'Pengeluaran',
    this.incomeLabel = 'Pemasukan',
  });

  final bool income;

  /// Null disables it.
  final ValueChanged<bool>? onChanged;
  final String expenseLabel, incomeLabel;

  @override
  Widget build(BuildContext context) {
    Widget tab(bool value, String label, IconData icon, Color color) {
      final on = income == value;
      return Expanded(
        child: GestureDetector(
          onTap: onChanged == null ? null : () => onChanged!(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 44,
            decoration: BoxDecoration(
              color: on ? Lx.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(Lx.rButton - 2),
              boxShadow: on ? Lx.shadowSoft : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: on ? color : Lx.textMuted),
                const SizedBox(width: 6),
                Text(label,
                    style: Lx.button.copyWith(
                        color: on ? color : Lx.textSecondary,
                        fontWeight: on ? FontWeight.w700 : FontWeight.w600)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0FB),
        borderRadius: BorderRadius.circular(Lx.rButton),
      ),
      child: Row(
        children: [
          tab(false, expenseLabel, Icons.north_east_rounded, Lx.danger),
          tab(true, incomeLabel, Icons.south_west_rounded, Lx.success),
        ],
      ),
    );
  }
}

/// A compact month stepper in a pill: ‹ November 2026 ›.
class BudgetMonthPill extends StatelessWidget {
  const BudgetMonthPill({
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
    final canNext = month.isBefore(end);
    return Container(
      decoration: BoxDecoration(
        color: Lx.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Lx.border),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Bulan sebelumnya',
            visualDensity: VisualDensity.compact,
            onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text(
              monthLabel(month),
              textAlign: TextAlign.center,
              style: Lx.cardHeading,
            ),
          ),
          IconButton(
            tooltip: 'Bulan berikutnya',
            visualDensity: VisualDensity.compact,
            onPressed: canNext
                ? () => onChanged(DateTime(month.year, month.month + 1))
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

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

/// The date above a day's transactions, with that day's balance.
class BudgetDayHeader extends StatelessWidget {
  const BudgetDayHeader(
      {super.key, required this.label, required this.net});

  final String label;
  final int net;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: Lx.s16, bottom: Lx.s4),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: Lx.metadata.copyWith(
                      color: Lx.text, fontWeight: FontWeight.w700)),
            ),
            if (net != 0)
              Text(
                '${net > 0 ? '+' : '−'}Rp ${thousands(net.abs())}',
                style: Lx.metadata.copyWith(
                    color: net > 0 ? Lx.success : Lx.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontFeatures: tabular),
              ),
          ],
        ),
      );
}

// ── Budget progress ─────────────────────────────────────────────────────────

/// Colour of a budget's use: fine, nearly used up (80%), or over.
Color budgetColor(double percent, bool over) => over
    ? Lx.danger
    : percent >= 80
        ? Lx.warning
        : Lx.success;

/// A thin rounded bar.
class BudgetBar extends StatelessWidget {
  const BudgetBar(
      {super.key, required this.value, required this.color, this.height = 8});
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          minHeight: height,
          backgroundColor: const Color(0xFFEDF1F8),
          color: color,
        ),
      );
}

/// One expense category against its limit. Over budget turns red and says
/// by how much.
class BudgetProgressRow extends StatelessWidget {
  const BudgetProgressRow({super.key, required this.line, this.onTap});

  final BudgetCategoryLine line;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final over = line.over;
    final color = budgetColor(line.percent, over);
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
                      Text('${line.percent.round()}%',
                          style: Lx.metadata.copyWith(
                              color: color, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  BudgetBar(value: line.percent / 100, color: color),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${rp(line.spent)} dari ${rp(line.limit)}',
                          style: Lx.metadata.copyWith(fontFeatures: tabular),
                        ),
                      ),
                      Text(
                        over
                            ? 'Lebih ${rp(-line.remaining)}'
                            : 'Sisa ${rp(line.remaining)}',
                        style: Lx.metadata.copyWith(
                            color: over ? Lx.danger : Lx.textSecondary,
                            fontWeight: over ? FontWeight.w700 : null,
                            fontFeatures: tabular),
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
              line(Icons.mic_rounded, 'Suara',
                  t.transcript.isEmpty ? 'Dicatat dengan suara' : '"${t.transcript}"'),
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

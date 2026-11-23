import '../models/muzakki.dart';
import '../models/zakat_external_data.dart';
import '../models/zakat_external_master.dart';

enum ExternalRowKind { internal, external, unassigned }

/// One line of "Rincian per Grup": everything attributed to one Master
/// Eksternal (registered muzakki + non-registered souls), or one of the two
/// catch-all lines.
class ExternalBreakdownRow {
  ExternalBreakdownRow(this.label, this.kind);

  final String label;
  final ExternalRowKind kind;

  /// Registered muzakki attributed here.
  int muzakki = 0;

  /// Non-registered souls attributed here.
  int extraSouls = 0;
  int riceSouls = 0;
  int moneySouls = 0;
  double riceSo = 0;
  double moneyAmount = 0;

  /// Orang: registered muzakki plus non-registered souls.
  int get people => muzakki + extraSouls;

  /// Jiwa that have paid (rice + money).
  int get paidSouls => riceSouls + moneySouls;
}

const externalInternalLabel = 'Internal (tanpa eksternal)';
const externalUnassignedLabel = 'Non-terdaftar (tanpa kelompok)';

/// Source for Beranda "Rincian per Grup".
///
/// Rows, in order: internal without external, one per Master Eksternal
/// (active ones always, even when empty; inactive ones only if used), then
/// non-registered souls without an external.
List<ExternalBreakdownRow> buildExternalBreakdown({
  required List<Muzakki> muzakkiList,
  required Iterable<FamilyExternalData> externalFamilies,
  required List<ExternalMaster> masters,
  required double moneyRatePerSoul,
  String internalLabel = externalInternalLabel,
}) {
  // Keyed apart from the labels so an external named like the internal group
  // can never merge with it.
  const internalKey = '\u0000internal';
  const unassignedKey = '\u0000unassigned';
  final rows = <String, ExternalBreakdownRow>{};
  ExternalBreakdownRow row(String label, ExternalRowKind kind) {
    final key = switch (kind) {
      ExternalRowKind.internal => internalKey,
      ExternalRowKind.unassigned => unassignedKey,
      ExternalRowKind.external => label,
    };
    return rows.putIfAbsent(key, () => ExternalBreakdownRow(label, kind));
  }

  final masterNameById = {for (final e in masters) e.id: e.name};

  for (final m in muzakkiList) {
    final name = m.externalName.trim();
    final r = name.isNotEmpty
        ? row(name, ExternalRowKind.external)
        : (m.isInternal
            ? row(internalLabel, ExternalRowKind.internal)
            : row(externalUnassignedLabel, ExternalRowKind.unassigned));
    r.muzakki += 1;
    final people = m.numberOfPeople > 0 ? m.numberOfPeople : 1;
    if (m.paymentType == PaymentType.beras) {
      r.riceSouls += people;
      r.riceSo += m.amountSo > 0 ? m.amountSo : people.toDouble();
    } else if (m.paymentType == PaymentType.uang) {
      r.moneySouls += people;
      r.moneyAmount += m.amountRp > 0 ? m.amountRp : people * moneyRatePerSoul;
    }
  }

  for (final family in externalFamilies) {
    for (final soul in family.externalSouls) {
      final name = masterNameById[soul.externalId] ?? '';
      final r = name.isNotEmpty
          ? row(name, ExternalRowKind.external)
          : row(externalUnassignedLabel, ExternalRowKind.unassigned);
      r.extraSouls += soul.souls;
      final type = soul.paymentType.toLowerCase();
      if (type == 'rice' || type == 'beras') {
        r.riceSouls += soul.souls;
        r.riceSo += soul.souls;
      } else if (type == 'money' || type == 'uang') {
        r.moneySouls += soul.souls;
        final amount = double.tryParse(soul.amount) ?? 0;
        r.moneyAmount += amount > 0 ? amount : soul.souls * moneyRatePerSoul;
      }
    }
  }

  // Every active master is listed so the report matches the Config list.
  for (final e
      in masters.where((e) => e.isActive && e.name.trim().isNotEmpty)) {
    row(e.name, ExternalRowKind.external);
  }

  final named = rows.values
      .where((r) => r.kind == ExternalRowKind.external)
      .toList()
    ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

  return [
    if (rows[internalKey] != null) rows[internalKey]!,
    ...named,
    if (rows[unassignedKey] != null) rows[unassignedKey]!,
  ];
}

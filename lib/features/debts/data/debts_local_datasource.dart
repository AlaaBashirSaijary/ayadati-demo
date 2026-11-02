import '../../../core/database/clinic_data_database.dart';
import '../../../core/money/currency.dart';
import '../domain/patient_debt.dart';

/// Reads what patients still owe and records payments against it. A payment
/// is spread over the patient's unpaid visits in that currency, oldest
/// first; every step is also written to `visit_payments` so there's a dated
/// history, while `visits.amount_paid` stays the running total.
class DebtsLocalDataSource {
  const DebtsLocalDataSource(this._db);

  final ClinicDataDatabase _db;

  Future<List<PatientDebt>> list() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT v.id AS visit_id, v.patient_id, p.full_name, p.phone,
             v.visit_date, v.fee_amount, v.amount_paid, v.currency
      FROM visits v
      JOIN patients p ON p.id = v.patient_id
      WHERE v.fee_amount IS NOT NULL
        AND v.fee_amount > COALESCE(v.amount_paid, v.fee_amount)
      ORDER BY v.visit_date ASC, v.id ASC
    ''');

    final byPatient = <int, List<Map<String, Object?>>>{};
    for (final r in rows) {
      byPatient.putIfAbsent(r['patient_id']! as int, () => []).add(r);
    }
    final debts = [
      for (final entry in byPatient.entries)
        PatientDebt(
          patientId: entry.key,
          name: entry.value.first['full_name']! as String,
          phone: entry.value.first['phone'] as String?,
          visits: [
            for (final r in entry.value)
              DebtVisit(
                visitId: r['visit_id']! as int,
                visitDate: DateTime.parse(r['visit_date']! as String),
                fee: (r['fee_amount']! as num).toDouble(),
                paid: (r['amount_paid'] as num?)?.toDouble() ?? 0,
                currency: Currency.fromCode(r['currency'] as String?),
              ),
          ],
        ),
    ]..sort((a, b) => a.oldest.compareTo(b.oldest));
    return debts;
  }

  /// Records [amount] of [currency] paid by [patientId]. Returns the amount
  /// actually applied (capped at what's owed in that currency).
  Future<double> recordPayment({
    required int patientId,
    required Currency currency,
    required double amount,
    String? note,
  }) async {
    final debts = await list();
    final debt = debts.where((d) => d.patientId == patientId).firstOrNull;
    if (debt == null) return 0;
    final visits = debt.visits.where((v) => v.currency == currency).toList();
    final owed = visits.fold<double>(0, (s, v) => s + v.remaining);
    final capped = amount > owed ? owed : amount;
    final parts = allocatePayment(visits, capped);

    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      for (final part in parts) {
        final visit = visits.firstWhere((v) => v.visitId == part.visitId);
        await txn.insert('visit_payments', {
          'visit_id': part.visitId,
          'amount': part.amount,
          'paid_at': now,
          'note': note,
        });
        await txn.update(
          'visits',
          {'amount_paid': visit.paid + part.amount, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [part.visitId],
        );
      }
    });
    return capped;
  }
}

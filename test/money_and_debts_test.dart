import 'package:clinic_manager_flutter/core/database/clinic_data_database.dart';
import 'package:clinic_manager_flutter/core/money/currency.dart';
import 'package:clinic_manager_flutter/features/debts/data/debts_local_datasource.dart';
import 'package:clinic_manager_flutter/features/debts/domain/patient_debt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  test('currency formatting groups thousands and keeps the symbol', () {
    expect(Currency.syp.format(25000), '25,000 ل.س');
    expect(Currency.usd.format(40), r'$40');
    expect(Currency.usd.format(12.5), r'$12.50');
    expect(Currency.syp.format(1500000), '1,500,000 ل.س');
  });

  test('totals keep currencies apart and only convert with a rate', () {
    final t = MoneyTotals()
      ..add(Currency.syp, 50000)
      ..add(Currency.usd, 10)
      ..add(Currency.syp, 25000);
    expect(t.of(Currency.syp), 75000);
    expect(t.describe(), '75,000 ل.س  +  \$10');
    expect(t.inSyp(null), isNull);
    expect(t.inSyp(15000), 75000 + 150000);
    expect(MoneyTotals().isEmpty, true);
  });

  test('a payment settles the oldest balance first', () {
    DebtVisit v(int id, double fee, double paid) => DebtVisit(
      visitId: id,
      visitDate: DateTime(2026, 1, id),
      fee: fee,
      paid: paid,
      currency: Currency.syp,
    );
    final parts = allocatePayment([
      v(1, 100, 40),
      v(2, 100, 0),
      v(3, 50, 0),
    ], 130);
    expect(parts.map((p) => (p.visitId, p.amount)).toList(), [
      (1, 60.0),
      (2, 70.0),
    ]);
    expect(allocatePayment([v(1, 100, 100)], 50), isEmpty);
  });

  test(
    'recording a payment updates the visit and keeps a dated history',
    () async {
      final file =
          'clinic_t_debts_${DateTime.now().microsecondsSinceEpoch}.sqlite';
      SharedPreferences.setMockInitialValues({});
      await ClinicDataDatabase.instance.closeActive();
      await ClinicDataDatabase.instance.switchTo(file);
      final db = await ClinicDataDatabase.instance.database;
      final pid = await db.insert('patients', {
        'full_name': 'مريض تجريبي',
        'phone': '0911111111',
      });
      Future<int> visit(String date, double fee, double paid, String cur) =>
          db.insert('visits', {
            'patient_id': pid,
            'visit_date': date,
            'fee_amount': fee,
            'amount_paid': paid,
            'currency': cur,
          });
      final v1 = await visit('2026-01-01', 100000, 20000, 'SYP');
      final v2 = await visit('2026-02-01', 40, 0, 'USD');

      final ds = DebtsLocalDataSource(ClinicDataDatabase.instance);
      var debts = await ds.list();
      expect(debts.single.owed.of(Currency.syp), 80000);
      expect(debts.single.owed.of(Currency.usd), 40);

      final applied = await ds.recordPayment(
        patientId: pid,
        currency: Currency.syp,
        amount: 500000,
      );
      expect(applied, 80000); // capped at what was owed
      debts = await ds.list();
      expect(debts.single.owed.of(Currency.syp), 0);
      expect(
        debts.single.owed.of(Currency.usd),
        40,
      ); // the dollar balance is untouched

      final paid = await db.query('visits', where: 'id = ?', whereArgs: [v1]);
      expect(paid.first['amount_paid'], 100000);
      final history = await db.query('visit_payments');
      expect(history.length, 1);
      expect(history.first['visit_id'], v1);
      expect(v2, isNotNull);
      await ClinicDataDatabase.instance.closeActive();
    },
  );
}

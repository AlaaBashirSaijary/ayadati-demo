import 'package:clinic_manager_flutter/core/database/clinic_data_database.dart';
import 'package:clinic_manager_flutter/features/recall/data/recall_local_datasource.dart';
import 'package:clinic_manager_flutter/features/recall/domain/recall.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  test('template placeholders and the two-week cooldown', () {
    expect(
      fillRecallTemplate(
        'أهلًا {name} في {clinic}',
        name: 'سارة',
        clinic: 'عيادتي',
      ),
      'أهلًا سارة في عيادتي',
    );
    final now = DateTime(2026, 10, 20);
    expect(isCoolingDown(null, now), false);
    expect(isCoolingDown(DateTime(2026, 10, 10), now), true);
    expect(isCoolingDown(DateTime(2026, 9, 1), now), false);
  });

  test(
    'lapsed list skips patients with a booking ahead and inactive ones',
    () async {
      SharedPreferences.setMockInitialValues({});
      await ClinicDataDatabase.instance.closeActive();
      await ClinicDataDatabase.instance.switchTo(
        'clinic_t_recall_${DateTime.now().microsecondsSinceEpoch}.sqlite',
      );
      final db = await ClinicDataDatabase.instance.database;
      String ago(int days) => DateTime.now()
          .subtract(Duration(days: days))
          .toIso8601String()
          .split('T')
          .first;
      Future<int> patient(String name, {int active = 1}) => db.insert(
        'patients',
        {'full_name': name, 'phone': '0911111111', 'is_active': active},
      );
      Future<void> visit(int pid, int daysAgo, {int flag = 0}) => db
          .insert('visits', {
            'patient_id': pid,
            'visit_date': ago(daysAgo),
            'needs_follow_up': flag,
          })
          .then((_) {});

      final old = await patient('قديم');
      await visit(old, 300);
      final booked = await patient('محجوز');
      await visit(booked, 300);
      await db.insert('appointments', {
        'patient_id': booked,
        'scheduled_at': DateTime.now()
            .add(const Duration(days: 3))
            .toIso8601String(),
        'status': 'scheduled',
      });
      final inactive = await patient('غير نشط', active: 0);
      await visit(inactive, 300);
      final recent = await patient('حديث');
      await visit(recent, 10);
      final flagged = await patient('متابعة');
      await visit(flagged, 20, flag: 1);

      final ds = RecallLocalDataSource(ClinicDataDatabase.instance);
      final lapsed = (await ds.candidates(
        RecallKind.lapsed6,
      )).map((c) => c.name).toList();
      expect(lapsed, ['قديم']);
      final due = (await ds.candidates(
        RecallKind.overdueFollowUp,
      )).map((c) => c.name).toList();
      expect(due, ['متابعة']);
      await ClinicDataDatabase.instance.closeActive();
    },
  );
}

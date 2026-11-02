import 'package:clinic_manager_flutter/core/database/clinic_data_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  Future<List<String>> labelsFor(String file, {String? specialty}) async {
    SharedPreferences.setMockInitialValues({
      ClinicDataDatabase.specialtyPrefKey(file): ?specialty,
    });
    await ClinicDataDatabase.instance.closeActive();
    await ClinicDataDatabase.instance.switchTo(file);
    final db = await ClinicDataDatabase.instance.database;
    final rows = await db.query(
      'exam_field_templates',
      orderBy: 'sort_order ASC',
    );
    return rows.map((r) => r['label']! as String).toList();
  }

  test(
    'a new clinic starts with the form of the specialty chosen for it',
    () async {
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final dental = await labelsFor(
        'clinic_t_dental_$stamp.sqlite',
        specialty: 'dental',
      );
      expect(dental, contains('السن المصاب'));
      expect(dental, isNot(contains('Auto')));

      final plain = await labelsFor('clinic_t_plain_$stamp.sqlite');
      expect(plain, contains('Auto')); // legacy default when nothing was chosen
      await ClinicDataDatabase.instance.closeActive();
    },
  );
}

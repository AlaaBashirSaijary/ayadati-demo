import '../../../../core/database/clinic_data_database.dart';
import '../models/doctor_model.dart';

class DoctorLocalDataSource {
  const DoctorLocalDataSource(this._db);

  final ClinicDataDatabase _db;

  Future<List<DoctorModel>> list({bool activeOnly = false}) async {
    final db = await _db.database;
    final rows = await db.query(
      'doctors',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(DoctorModel.fromMap).toList();
  }

  Future<DoctorModel> create(DoctorModel doctor) async {
    final db = await _db.database;
    final id = await db.insert('doctors', {
      ...doctor.toMap(),
      'created_at': DateTime.now().toIso8601String(),
    });
    return (await find(id))!;
  }

  Future<DoctorModel> update(DoctorModel doctor) async {
    final db = await _db.database;
    await db.update(
      'doctors',
      doctor.toMap(),
      where: 'id = ?',
      whereArgs: [doctor.id],
    );
    return (await find(doctor.id!))!;
  }

  Future<DoctorModel?> find(int id) async {
    final db = await _db.database;
    final rows = await db.query('doctors', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return DoctorModel.fromMap(rows.first);
  }
}

import '../../../../core/database/clinic_data_database.dart';
import '../../domain/entities/patient.dart';
import '../models/patient_model.dart';

/// Raw SQLite access — the Flutter analogue of Patient's Eloquent scopes
/// (scopeSearch, scopeStatus) and Patient::nextNumberForClinic(). Always
/// runs against whichever clinic's database file is currently active (see
/// ClinicDataDatabase) — there's no clinic_id column to filter by anymore
/// since each clinic's patients live in their own file.
class PatientLocalDataSource {
  const PatientLocalDataSource(this._db);

  final ClinicDataDatabase _db;

  Future<({List<PatientModel> items, int total})> list({
    String query = '',
    PatientStatusFilter status = PatientStatusFilter.all,
    int page = 1,
    int perPage = 15,
  }) async {
    final db = await _db.database;
    final where = StringBuffer('1 = 1');
    final args = <Object?>[];

    final trimmed = query.trim();
    if (trimmed.isNotEmpty) {
      // Same shape as Patient::scopeSearch(): prefix or contains match on
      // full_name, prefix match on patient_number, contains match on phone.
      where.write(
        ' AND (full_name LIKE ? OR full_name LIKE ? OR patient_number LIKE ? OR phone LIKE ?)',
      );
      args.addAll(['$trimmed%', '%$trimmed%', '$trimmed%', '%$trimmed%']);
    }

    switch (status) {
      case PatientStatusFilter.active:
        where.write(' AND is_active = 1');
      case PatientStatusFilter.inactive:
        where.write(' AND is_active = 0');
      case PatientStatusFilter.all:
        break;
    }

    final totalRow = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM patients WHERE $where',
      args,
    );
    final total = (totalRow.first['c']! as int);

    final rows = await db.rawQuery(
      'SELECT * FROM patients WHERE $where '
      'ORDER BY created_at DESC, id DESC LIMIT ? OFFSET ?',
      [...args, perPage, (page - 1) * perPage],
    );

    return (items: rows.map(PatientModel.fromMap).toList(), total: total);
  }

  Future<PatientModel?> find(int id) async {
    final db = await _db.database;
    final rows = await db.query('patients', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return PatientModel.fromMap(rows.first);
  }

  Future<PatientModel> create(PatientModel patient) async {
    final db = await _db.database;
    final id = await db.insert('patients', patient.toMap());
    return (await find(id))!;
  }

  Future<PatientModel> update(PatientModel patient) async {
    final db = await _db.database;
    await db.update(
      'patients',
      patient.toMap(),
      where: 'id = ?',
      whereArgs: [patient.id],
    );
    return (await find(patient.id!))!;
  }

  Future<PatientModel> toggleStatus(int id) async {
    final current = await find(id);
    final db = await _db.database;
    await db.update(
      'patients',
      {
        'is_active': current!.isActive ? 0 : 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return (await find(id))!;
  }

  /// Mirrors Patient::nextNumberForClinic(): highest numeric patient_number
  /// in the active clinic's file, plus one.
  Future<String> nextPatientNumber() async {
    final db = await _db.database;
    final rows = await db.query(
      'patients',
      columns: ['patient_number'],
      where: 'patient_number IS NOT NULL',
    );

    var max = 0;
    final digits = RegExp(r'(\d+)');
    for (final row in rows) {
      final match = digits.firstMatch(row['patient_number'] as String? ?? '');
      if (match == null) continue;
      final value = int.tryParse(match.group(1)!) ?? 0;
      if (value > max) max = value;
    }

    return (max + 1).toString();
  }

  /// Total/active/inactive counts for the dashboard's stat cards — a single
  /// grouped query instead of three separate COUNT(*) round trips.
  Future<({int total, int active, int inactive})> counts() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT is_active, COUNT(*) AS c FROM patients GROUP BY is_active',
    );

    var active = 0;
    var inactive = 0;
    for (final row in rows) {
      final count = row['c']! as int;
      if ((row['is_active']! as int) == 1) {
        active = count;
      } else {
        inactive = count;
      }
    }

    return (total: active + inactive, active: active, inactive: inactive);
  }

  /// New patient records created within [start, end) — backs the monthly
  /// report's "مرضى جدد" figure.
  Future<int> countCreatedBetween(DateTime start, DateTime end) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM patients WHERE created_at >= ? AND created_at < ?',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return rows.first['c']! as int;
  }
}

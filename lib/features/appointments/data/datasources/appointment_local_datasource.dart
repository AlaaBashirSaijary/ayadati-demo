import '../../../../core/database/clinic_data_database.dart';
import '../models/appointment_model.dart';

const _joinedSelect = '''
  SELECT appointments.*, patients.full_name AS patient_name, patients.phone AS patient_phone,
         doctors.name AS doctor_name
  FROM appointments
  JOIN patients ON patients.id = appointments.patient_id
  LEFT JOIN doctors ON doctors.id = appointments.doctor_id
''';

class AppointmentLocalDataSource {
  const AppointmentLocalDataSource(this._db);

  final ClinicDataDatabase _db;

  /// Appointments whose scheduled time falls within [start, end) —
  /// half-open so a caller can pass midnight-to-midnight for "one day".
  Future<List<AppointmentModel>> listBetween(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '$_joinedSelect WHERE appointments.scheduled_at >= ? AND appointments.scheduled_at < ? '
      'ORDER BY appointments.scheduled_at ASC',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return rows.map(AppointmentModel.fromMap).toList();
  }

  /// The next [limit] not-yet-past scheduled appointments, soonest first —
  /// backs a "upcoming" dashboard-style view regardless of which day.
  Future<List<AppointmentModel>> listUpcoming({int limit = 20}) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      "$_joinedSelect WHERE appointments.status = 'scheduled' AND appointments.scheduled_at >= ? "
      'ORDER BY appointments.scheduled_at ASC LIMIT ?',
      [DateTime.now().toIso8601String(), limit],
    );
    return rows.map(AppointmentModel.fromMap).toList();
  }

  Future<AppointmentModel> create(AppointmentModel appointment) async {
    final db = await _db.database;
    final id = await db.insert('appointments', appointment.toMap());
    return (await find(id))!;
  }

  Future<AppointmentModel> update(AppointmentModel appointment) async {
    final db = await _db.database;
    await db.update(
      'appointments',
      appointment.toMap(),
      where: 'id = ?',
      whereArgs: [appointment.id],
    );
    return (await find(appointment.id!))!;
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('appointments', where: 'id = ?', whereArgs: [id]);
  }

  Future<AppointmentModel?> find(int id) async {
    final db = await _db.database;
    final rows = await db.rawQuery('$_joinedSelect WHERE appointments.id = ?', [
      id,
    ]);
    if (rows.isEmpty) return null;
    return AppointmentModel.fromMap(rows.first);
  }

  /// The other non-cancelled appointment already booked at the exact same
  /// [scheduledAt], if any — [excludeId] skips the appointment being edited
  /// so re-saving one at its own unchanged time doesn't flag itself.
  Future<AppointmentModel?> findConflict(
    DateTime scheduledAt, {
    int? excludeId,
  }) async {
    final db = await _db.database;
    final where = StringBuffer(
      "appointments.status != 'cancelled' AND appointments.scheduled_at = ?",
    );
    final args = <Object?>[scheduledAt.toIso8601String()];
    if (excludeId != null) {
      where.write(' AND appointments.id != ?');
      args.add(excludeId);
    }
    final rows = await db.rawQuery('$_joinedSelect WHERE $where LIMIT 1', args);
    if (rows.isEmpty) return null;
    return AppointmentModel.fromMap(rows.first);
  }

  /// The most recent consultation booked for this patient, regardless of
  /// status — used to suggest "متابعة" (free follow-up) instead of
  /// "كشفية" (paid) when it falls inside the clinic's follow-up window.
  Future<DateTime?> lastConsultationDate(int patientId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      "SELECT MAX(scheduled_at) AS last FROM appointments "
      "WHERE patient_id = ? AND type = 'consultation'",
      [patientId],
    );
    final last = rows.first['last'] as String?;
    return last == null ? null : DateTime.parse(last);
  }

  Future<int> getFollowUpDays() async {
    final db = await _db.database;
    final rows = await db.query(
      'clinic_settings',
      columns: ['follow_up_days'],
      where: 'id = 1',
    );
    if (rows.isEmpty) return 30;
    return rows.first['follow_up_days']! as int;
  }

  Future<void> setFollowUpDays(int days) async {
    final db = await _db.database;
    await db.update('clinic_settings', {
      'follow_up_days': days,
    }, where: 'id = 1');
  }

  Future<int> getHalfPriceDays() async {
    final db = await _db.database;
    final rows = await db.query(
      'clinic_settings',
      columns: ['half_price_days'],
      where: 'id = 1',
    );
    if (rows.isEmpty) return 60;
    return rows.first['half_price_days']! as int;
  }

  Future<void> setHalfPriceDays(int days) async {
    final db = await _db.database;
    await db.update('clinic_settings', {
      'half_price_days': days,
    }, where: 'id = 1');
  }

  /// Appointment counts by type within [start, end), excluding cancelled
  /// bookings — backs the monthly report's "كشفيات مدفوعة" / "متابعات
  /// مجانية" figures.
  Future<Map<String, int>> countByTypeBetween(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      "SELECT type, COUNT(*) AS c FROM appointments "
      "WHERE status != 'cancelled' AND scheduled_at >= ? AND scheduled_at < ? "
      "GROUP BY type",
      [start.toIso8601String(), end.toIso8601String()],
    );
    return {for (final row in rows) row['type']! as String: row['c']! as int};
  }
}

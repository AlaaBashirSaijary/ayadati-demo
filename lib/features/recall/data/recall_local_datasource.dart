import '../../../core/database/clinic_data_database.dart';
import '../domain/recall.dart';

/// Finds the patients worth contacting: ones the doctor flagged for follow-up
/// (and haven't been seen since), and ones with no visit for a while and
/// nothing booked ahead. Only active patients are ever listed.
class RecallLocalDataSource {
  const RecallLocalDataSource(this._db);

  final ClinicDataDatabase _db;

  static String _day(DateTime d) => d.toIso8601String().split('T').first;

  Future<List<RecallCandidate>> candidates(RecallKind kind) async {
    final db = await _db.database;
    final today = DateTime.now();

    if (kind == RecallKind.overdueFollowUp) {
      final rows = await db.rawQuery(
        '''
        SELECT p.id, p.full_name, p.phone, v.visit_date, v.follow_up_by
        FROM visits v
        JOIN patients p ON p.id = v.patient_id
        WHERE p.is_active = 1
          AND v.needs_follow_up = 1
          AND (v.follow_up_by IS NULL OR v.follow_up_by <= ?)
          AND v.id = (SELECT id FROM visits
                      WHERE patient_id = p.id
                      ORDER BY visit_date DESC, id DESC LIMIT 1)
        ORDER BY v.visit_date ASC
      ''',
        [_day(today.add(const Duration(days: 7)))],
      );
      return [for (final r in rows) _from(r)];
    }

    final cutoff = DateTime(today.year, today.month - kind.months!, today.day);
    final rows = await db.rawQuery(
      '''
      SELECT p.id, p.full_name, p.phone, MAX(v.visit_date) AS visit_date,
             NULL AS follow_up_by
      FROM patients p
      JOIN visits v ON v.patient_id = p.id
      WHERE p.is_active = 1
      GROUP BY p.id
      HAVING MAX(v.visit_date) <= ?
         AND p.id NOT IN (
           SELECT patient_id FROM appointments
           WHERE status = 'scheduled' AND scheduled_at >= ?
         )
      ORDER BY MAX(v.visit_date) DESC
    ''',
      [_day(cutoff), _day(today)],
    );
    return [for (final r in rows) _from(r)];
  }

  RecallCandidate _from(Map<String, Object?> r) => RecallCandidate(
    patientId: r['id']! as int,
    name: r['full_name']! as String,
    phone: r['phone'] as String?,
    lastVisit: DateTime.parse(r['visit_date']! as String),
    followUpBy: r['follow_up_by'] == null
        ? null
        : DateTime.parse(r['follow_up_by']! as String),
  );
}

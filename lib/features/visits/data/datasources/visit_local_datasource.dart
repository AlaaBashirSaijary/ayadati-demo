import 'dart:typed_data';

import '../../../../core/database/clinic_data_database.dart';
import '../../../../core/money/currency.dart';
import '../../domain/entities/financial_report.dart';
import '../../domain/entities/follow_up_due.dart';
import '../../domain/entities/patient_photo.dart';
import '../../domain/entities/visit_photo.dart';
import '../models/visit_field_value_model.dart';
import '../models/visit_model.dart';

class VisitLocalDataSource {
  const VisitLocalDataSource(this._db);

  final ClinicDataDatabase _db;

  Future<List<VisitModel>> listForPatient(int patientId) async {
    final db = await _db.database;
    final rows = await db.query(
      'visits',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'visit_date DESC, id DESC',
    );
    return rows.map(VisitModel.fromMap).toList();
  }

  Future<VisitModel> create(VisitModel visit) async {
    final db = await _db.database;
    final id = await db.insert('visits', visit.toMap());
    return (await find(id))!;
  }

  Future<VisitModel> update(VisitModel visit) async {
    final db = await _db.database;
    await db.update(
      'visits',
      visit.toMap(),
      where: 'id = ?',
      whereArgs: [visit.id],
    );
    return (await find(visit.id!))!;
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('visits', where: 'id = ?', whereArgs: [id]);
  }

  /// Distinct patients with a recorded exam today — "already seen", as
  /// opposed to `appointments`, which tracks future-dated bookings.
  /// visit_date is stored as an ISO date string, so a plain prefix match
  /// against today's date works without needing SQLite date functions.
  Future<int> countDistinctPatientsToday() async {
    final db = await _db.database;
    final today = DateTime.now().toIso8601String().split('T').first;
    final rows = await db.rawQuery(
      'SELECT COUNT(DISTINCT patient_id) AS c FROM visits WHERE visit_date LIKE ?',
      ['$today%'],
    );
    return rows.first['c']! as int;
  }

  Future<VisitModel?> find(int id) async {
    final db = await _db.database;
    final rows = await db.query('visits', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return VisitModel.fromMap(rows.first);
  }

  /// Active patients whose *most recent* visit is flagged
  /// [VisitModel.needsFollowUp] — a patient drops off this list the moment
  /// a newer visit exists for them, flagged or not, so nothing has to be
  /// marked "resolved" by hand. The correlated subquery is what finds
  /// "most recent" per patient, using the same ordering convention as
  /// [listForPatient] (visit_date DESC, id DESC).
  Future<List<FollowUpDue>> listDueForFollowUp() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT v.id AS visit_id, v.patient_id, v.visit_date, v.follow_up_by,
             p.full_name AS patient_name, p.phone AS patient_phone
      FROM visits v
      JOIN patients p ON p.id = v.patient_id
      WHERE v.needs_follow_up = 1
        AND p.is_active = 1
        AND v.id = (
          SELECT v2.id FROM visits v2
          WHERE v2.patient_id = v.patient_id
          ORDER BY v2.visit_date DESC, v2.id DESC
          LIMIT 1
        )
      ORDER BY (v.follow_up_by IS NULL) ASC, v.follow_up_by ASC
    ''');

    return [
      for (final row in rows)
        FollowUpDue(
          visitId: row['visit_id']! as int,
          patientId: row['patient_id']! as int,
          patientName: row['patient_name']! as String,
          patientPhone: row['patient_phone'] as String?,
          visitDate: DateTime.parse(row['visit_date']! as String),
          followUpBy: row['follow_up_by'] == null
              ? null
              : DateTime.parse(row['follow_up_by']! as String),
        ),
    ];
  }

  /// Every visit with a recorded fee whose date falls in [start, end) —
  /// backs the real financial report (actual amounts, not appointment-type
  /// counts). [end] is exclusive, matching the convention used elsewhere
  /// (e.g. GetNewPatientsCount's DateRangeParams).
  Future<FinancialReport> financialReport(DateTime start, DateTime end) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT v.id AS visit_id, v.patient_id, p.full_name AS patient_name,
             v.visit_date, v.fee_amount, v.amount_paid, v.currency
      FROM visits v
      JOIN patients p ON p.id = v.patient_id
      WHERE v.fee_amount IS NOT NULL
        AND v.visit_date >= ? AND v.visit_date < ?
      ORDER BY v.visit_date DESC, v.id DESC
    ''',
      [
        start.toIso8601String().split('T').first,
        end.toIso8601String().split('T').first,
      ],
    );

    return FinancialReport(
      rows: [
        for (final row in rows)
          FinancialVisitRow(
            visitId: row['visit_id']! as int,
            patientId: row['patient_id']! as int,
            patientName: row['patient_name']! as String,
            visitDate: DateTime.parse(row['visit_date']! as String),
            feeAmount: (row['fee_amount']! as num).toDouble(),
            amountPaid:
                (row['amount_paid'] as num?)?.toDouble() ??
                (row['fee_amount']! as num).toDouble(),
            currency: Currency.fromCode(row['currency'] as String?),
          ),
      ],
    );
  }

  // ============================== الصور المرفقة ==============================

  Future<List<VisitPhoto>> listPhotos(int visitId) async {
    final db = await _db.database;
    final rows = await db.query(
      'visit_photos',
      where: 'visit_id = ?',
      whereArgs: [visitId],
      orderBy: 'id DESC',
    );
    return [
      for (final row in rows)
        VisitPhoto(
          id: row['id']! as int,
          visitId: row['visit_id']! as int,
          imageData: row['image_data']! as Uint8List,
          createdAt: row['created_at'] == null
              ? null
              : DateTime.parse(row['created_at']! as String),
        ),
    ];
  }

  Future<void> addPhoto(int visitId, Uint8List imageData) async {
    final db = await _db.database;
    await db.insert('visit_photos', {
      'visit_id': visitId,
      'image_data': imageData,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deletePhoto(int id) async {
    final db = await _db.database;
    await db.delete('visit_photos', where: 'id = ?', whereArgs: [id]);
  }

  /// Every photo across every visit of [patientId], newest visit first —
  /// backs the before/after comparison grid, which needs the whole photo
  /// history flattened in one place rather than grouped per visit.
  Future<List<PatientPhoto>> listPhotosForPatient(int patientId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT vp.id AS id, vp.visit_id, vp.image_data, v.visit_date
      FROM visit_photos vp
      JOIN visits v ON v.id = vp.visit_id
      WHERE v.patient_id = ?
      ORDER BY v.visit_date DESC, vp.id DESC
    ''',
      [patientId],
    );

    return [
      for (final row in rows)
        PatientPhoto(
          id: row['id']! as int,
          visitId: row['visit_id']! as int,
          visitDate: DateTime.parse(row['visit_date']! as String),
          imageData: row['image_data']! as Uint8List,
        ),
    ];
  }

  // ============================== قيم حقول الفحص ==============================

  Future<List<VisitFieldValueModel>> listFieldValues(int visitId) async {
    final db = await _db.database;
    final rows = await db.query(
      'visit_field_values',
      where: 'visit_id = ?',
      whereArgs: [visitId],
    );
    return rows.map(VisitFieldValueModel.fromMap).toList();
  }

  /// Same as [listFieldValues], but for every id in [visitIds] in one query
  /// — used where a caller needs a whole patient's exam history (e.g. the
  /// PDF export) instead of looping one query per visit.
  Future<Map<int, List<VisitFieldValueModel>>> listFieldValuesForVisits(
    List<int> visitIds,
  ) async {
    if (visitIds.isEmpty) return {};
    final db = await _db.database;
    final placeholders = List.filled(visitIds.length, '?').join(', ');
    final rows = await db.query(
      'visit_field_values',
      where: 'visit_id IN ($placeholders)',
      whereArgs: visitIds,
    );
    final byVisit = <int, List<VisitFieldValueModel>>{
      for (final id in visitIds) id: [],
    };
    for (final row in rows) {
      final model = VisitFieldValueModel.fromMap(row);
      byVisit[model.visitId]!.add(model);
    }
    return byVisit;
  }

  /// Replaces every stored value for [visitId] with [values] — a visit's
  /// exam form is saved as a whole, not diffed field-by-field.
  Future<void> saveFieldValues(
    int visitId,
    List<VisitFieldValueModel> values,
  ) async {
    final db = await _db.database;
    final batch = db.batch();
    batch.delete(
      'visit_field_values',
      where: 'visit_id = ?',
      whereArgs: [visitId],
    );
    for (final value in values) {
      if (value.value == null || value.value!.trim().isEmpty) continue;
      batch.insert('visit_field_values', value.toMap());
    }
    await batch.commit(noResult: true);
  }
}

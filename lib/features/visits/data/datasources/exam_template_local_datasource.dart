import 'package:sqflite/sqflite.dart';

import '../../../../core/database/clinic_data_database.dart';
import '../models/exam_field_template_model.dart';

/// The clinic's own exam form definition — what a doctor edits from
/// Admin > قوالب الفحص to make the app fit their specialty instead of the
/// fixed eye-exam chart it started as.
class ExamTemplateLocalDataSource {
  const ExamTemplateLocalDataSource(this._db);

  final ClinicDataDatabase _db;

  Future<List<ExamFieldTemplateModel>> list() async {
    final db = await _db.database;
    final rows = await db.query(
      'exam_field_templates',
      orderBy: 'sort_order ASC, id ASC',
    );
    return rows.map(ExamFieldTemplateModel.fromMap).toList();
  }

  Future<ExamFieldTemplateModel> create(
    String label,
    bool hasSides,
    bool isLongText,
  ) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT MAX(sort_order) AS m FROM exam_field_templates',
    );
    final nextOrder = ((rows.first['m'] as int?) ?? -1) + 1;

    final id = await db.insert('exam_field_templates', {
      'label': label,
      'has_sides': hasSides ? 1 : 0,
      'is_long_text': isLongText ? 1 : 0,
      'sort_order': nextOrder,
    });
    return (await _find(db, id))!;
  }

  Future<ExamFieldTemplateModel> update(ExamFieldTemplateModel template) async {
    final db = await _db.database;
    await db.update(
      'exam_field_templates',
      template.toMap(),
      where: 'id = ?',
      whereArgs: [template.id],
    );
    return (await _find(db, template.id!))!;
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('exam_field_templates', where: 'id = ?', whereArgs: [id]);
  }

  /// Persists a new top-to-bottom order for the whole form at once.
  Future<void> reorder(List<int> orderedIds) async {
    final db = await _db.database;
    final batch = db.batch();
    for (var i = 0; i < orderedIds.length; i++) {
      batch.update(
        'exam_field_templates',
        {'sort_order': i},
        where: 'id = ?',
        whereArgs: [orderedIds[i]],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<ExamFieldTemplateModel?> _find(Database db, int id) async {
    final rows = await db.query(
      'exam_field_templates',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return ExamFieldTemplateModel.fromMap(rows.first);
  }
}

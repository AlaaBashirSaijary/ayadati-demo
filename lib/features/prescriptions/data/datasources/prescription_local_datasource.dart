import '../../../../core/database/clinic_data_database.dart';
import '../models/prescription_model.dart';

class PrescriptionLocalDataSource {
  const PrescriptionLocalDataSource(this._db);

  final ClinicDataDatabase _db;

  Future<List<PrescriptionModel>> listForPatient(int patientId) async {
    final db = await _db.database;
    final rows = await db.query(
      'prescriptions',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(PrescriptionModel.fromMap).toList();
  }

  Future<PrescriptionModel> create(PrescriptionModel prescription) async {
    final db = await _db.database;
    final id = await db.insert('prescriptions', prescription.toMap());
    final rows = await db.query(
      'prescriptions',
      where: 'id = ?',
      whereArgs: [id],
    );
    return PrescriptionModel.fromMap(rows.first);
  }
}

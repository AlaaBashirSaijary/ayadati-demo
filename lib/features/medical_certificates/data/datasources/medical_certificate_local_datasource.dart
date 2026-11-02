import '../../../../core/database/clinic_data_database.dart';
import '../models/medical_certificate_model.dart';

class MedicalCertificateLocalDataSource {
  const MedicalCertificateLocalDataSource(this._db);

  final ClinicDataDatabase _db;

  Future<List<MedicalCertificateModel>> listForPatient(int patientId) async {
    final db = await _db.database;
    final rows = await db.query(
      'medical_certificates',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(MedicalCertificateModel.fromMap).toList();
  }

  Future<MedicalCertificateModel> create(
    MedicalCertificateModel certificate,
  ) async {
    final db = await _db.database;
    final id = await db.insert('medical_certificates', certificate.toMap());
    final rows = await db.query(
      'medical_certificates',
      where: 'id = ?',
      whereArgs: [id],
    );
    return MedicalCertificateModel.fromMap(rows.first);
  }
}

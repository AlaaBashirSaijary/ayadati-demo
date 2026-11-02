import '../../domain/entities/medical_certificate.dart';

class MedicalCertificateModel extends MedicalCertificate {
  const MedicalCertificateModel({
    super.id,
    required super.patientId,
    super.doctorId,
    super.type,
    super.restDays,
    required super.body,
    super.createdAt,
  });

  factory MedicalCertificateModel.fromEntity(MedicalCertificate c) =>
      MedicalCertificateModel(
        id: c.id,
        patientId: c.patientId,
        doctorId: c.doctorId,
        type: c.type,
        restDays: c.restDays,
        body: c.body,
        createdAt: c.createdAt,
      );

  factory MedicalCertificateModel.fromMap(Map<String, Object?> map) =>
      MedicalCertificateModel(
        id: map['id'] as int?,
        patientId: map['patient_id']! as int,
        doctorId: map['doctor_id'] as int?,
        type: MedicalCertificateType.fromValue(map['type']! as String),
        restDays: map['rest_days'] as int?,
        body: map['body']! as String,
        createdAt: DateTime.parse(map['created_at']! as String),
      );

  Map<String, Object?> toMap() {
    return {
      'patient_id': patientId,
      'doctor_id': doctorId,
      'type': type.name,
      'rest_days': restDays,
      'body': body,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }
}

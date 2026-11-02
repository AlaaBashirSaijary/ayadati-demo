import 'package:equatable/equatable.dart';

/// A sick-leave note (fixed number of rest days, little else to fill in)
/// versus a general medical report (a free-text body — a referral, a
/// summary for insurance, anything else a doctor is asked to put in
/// writing).
enum MedicalCertificateType {
  sickLeave,
  generalReport,
  referral;

  String get label => switch (this) {
    MedicalCertificateType.sickLeave => 'إجازة مرضية',
    MedicalCertificateType.generalReport => 'تقرير طبي عام',
    MedicalCertificateType.referral => 'تحويل لطبيب آخر',
  };

  static MedicalCertificateType fromValue(String value) =>
      MedicalCertificateType.values.firstWhere(
        (t) => t.name == value,
        orElse: () => MedicalCertificateType.sickLeave,
      );
}

/// Bureaucratic paperwork (work, school, insurance) handed to the patient —
/// kept as its own record the same way Prescription is, so a doctor can
/// reprint one without retyping it.
class MedicalCertificate extends Equatable {
  const MedicalCertificate({
    this.id,
    required this.patientId,
    this.doctorId,
    this.type = MedicalCertificateType.sickLeave,
    this.restDays,
    required this.body,
    this.createdAt,
  });

  final int? id;
  final int patientId;
  final int? doctorId;
  final MedicalCertificateType type;
  final int? restDays;
  final String body;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [id, patientId, doctorId, type, restDays, body];
}

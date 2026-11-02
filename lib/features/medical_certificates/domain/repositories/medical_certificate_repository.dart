import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/medical_certificate.dart';

abstract class MedicalCertificateRepository {
  Future<Either<Failure, List<MedicalCertificate>>> listForPatient(
    int patientId,
  );

  Future<Either<Failure, MedicalCertificate>> create(
    MedicalCertificate certificate,
  );
}

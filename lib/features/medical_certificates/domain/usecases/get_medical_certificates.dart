import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/medical_certificate.dart';
import '../repositories/medical_certificate_repository.dart';

class GetMedicalCertificates implements UseCase<List<MedicalCertificate>, int> {
  const GetMedicalCertificates(this._repository);

  final MedicalCertificateRepository _repository;

  @override
  Future<Either<Failure, List<MedicalCertificate>>> call(int patientId) {
    return _repository.listForPatient(patientId);
  }
}

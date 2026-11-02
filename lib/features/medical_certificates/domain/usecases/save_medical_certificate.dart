import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/medical_certificate.dart';
import '../repositories/medical_certificate_repository.dart';

class SaveMedicalCertificate
    implements UseCase<MedicalCertificate, MedicalCertificate> {
  const SaveMedicalCertificate(this._repository);

  final MedicalCertificateRepository _repository;

  @override
  Future<Either<Failure, MedicalCertificate>> call(MedicalCertificate params) {
    if (params.body.trim().isEmpty) {
      return Future.value(
        Left(ValidationFailure({'body': 'أدخلي نص التقرير أو سبب الإجازة.'})),
      );
    }
    return _repository.create(params);
  }
}

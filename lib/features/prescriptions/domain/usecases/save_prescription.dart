import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/prescription.dart';
import '../repositories/prescription_repository.dart';

class SavePrescription implements UseCase<Prescription, Prescription> {
  const SavePrescription(this._repository);

  final PrescriptionRepository _repository;

  @override
  Future<Either<Failure, Prescription>> call(Prescription params) {
    if (params.items.isEmpty) {
      return Future.value(
        Left(ValidationFailure({'items': 'أضيفي دواءً واحدًا على الأقل.'})),
      );
    }
    return _repository.create(params);
  }
}

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/patient.dart';
import '../patient_validator.dart';
import '../repositories/patient_repository.dart';

/// Mirrors PatientController::update().
class UpdatePatient implements UseCase<Patient, Patient> {
  const UpdatePatient(this._repository);

  final PatientRepository _repository;

  @override
  Future<Either<Failure, Patient>> call(Patient params) async {
    final validationError = PatientValidator.validate(params);
    if (validationError != null) return Left(validationError);

    return _repository.update(params);
  }
}

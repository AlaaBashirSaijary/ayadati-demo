import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/patient.dart';
import '../patient_validator.dart';
import '../repositories/patient_repository.dart';

/// Mirrors PatientController::store(): validate, then auto-assign the next
/// patient number when the field was left blank.
class CreatePatient implements UseCase<Patient, Patient> {
  const CreatePatient(this._repository);

  final PatientRepository _repository;

  @override
  Future<Either<Failure, Patient>> call(Patient params) async {
    final validationError = PatientValidator.validate(params);
    if (validationError != null) return Left(validationError);

    var patient = params;

    if ((patient.patientNumber ?? '').trim().isEmpty) {
      final numberResult = await _repository.nextPatientNumber();
      final assignError = numberResult.fold((f) => f, (_) => null);
      if (assignError != null) return Left(assignError);

      patient = patient.copyWith(
        patientNumber: numberResult.getOrElse(() => '1'),
      );
    }

    return _repository.create(patient);
  }
}

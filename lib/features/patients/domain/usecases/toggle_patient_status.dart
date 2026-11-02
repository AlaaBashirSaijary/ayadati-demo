import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/patient.dart';
import '../repositories/patient_repository.dart';

/// Mirrors PatientController::toggleStatus().
class TogglePatientStatus
    implements UseCase<Patient, TogglePatientStatusParams> {
  const TogglePatientStatus(this._repository);

  final PatientRepository _repository;

  @override
  Future<Either<Failure, Patient>> call(TogglePatientStatusParams params) {
    return _repository.toggleStatus(params.id);
  }
}

class TogglePatientStatusParams extends Equatable {
  const TogglePatientStatusParams({required this.id});

  final int id;

  @override
  List<Object?> get props => [id];
}

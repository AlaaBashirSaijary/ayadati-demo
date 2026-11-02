import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/patient.dart';
import '../repositories/patient_repository.dart';

/// Mirrors PatientController::show()/edit(): fetch one record from the
/// active clinic's database file.
class GetPatient implements UseCase<Patient, GetPatientParams> {
  const GetPatient(this._repository);

  final PatientRepository _repository;

  @override
  Future<Either<Failure, Patient>> call(GetPatientParams params) {
    return _repository.find(params.id);
  }
}

class GetPatientParams extends Equatable {
  const GetPatientParams({required this.id});

  final int id;

  @override
  List<Object?> get props => [id];
}

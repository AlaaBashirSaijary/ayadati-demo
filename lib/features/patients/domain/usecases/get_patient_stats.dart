import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/patient.dart';
import '../repositories/patient_repository.dart';

class GetPatientStats implements UseCase<PatientStats, NoParams> {
  const GetPatientStats(this._repository);

  final PatientRepository _repository;

  @override
  Future<Either<Failure, PatientStats>> call(NoParams params) {
    return _repository.stats();
  }
}

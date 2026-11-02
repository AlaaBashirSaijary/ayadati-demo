import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/visit.dart';
import '../repositories/visit_repository.dart';

class GetVisits implements UseCase<List<Visit>, int> {
  const GetVisits(this._repository);

  final VisitRepository _repository;

  @override
  Future<Either<Failure, List<Visit>>> call(int patientId) {
    return _repository.listForPatient(patientId);
  }
}

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/visit_field_value.dart';
import '../repositories/visit_repository.dart';

class GetVisitFieldValues implements UseCase<List<VisitFieldValue>, int> {
  const GetVisitFieldValues(this._repository);

  final VisitRepository _repository;

  @override
  Future<Either<Failure, List<VisitFieldValue>>> call(int visitId) {
    return _repository.listFieldValues(visitId);
  }
}

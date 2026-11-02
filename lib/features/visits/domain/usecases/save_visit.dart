import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/visit.dart';
import '../repositories/visit_repository.dart';

/// Handles both create and update — a Visit with a null [Visit.id] is new.
class SaveVisit implements UseCase<Visit, Visit> {
  const SaveVisit(this._repository);

  final VisitRepository _repository;

  @override
  Future<Either<Failure, Visit>> call(Visit params) {
    return params.id == null
        ? _repository.create(params)
        : _repository.update(params);
  }
}

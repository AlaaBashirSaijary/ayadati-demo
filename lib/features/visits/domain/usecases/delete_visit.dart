import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/visit_repository.dart';

class DeleteVisit implements UseCase<void, int> {
  const DeleteVisit(this._repository);

  final VisitRepository _repository;

  @override
  Future<Either<Failure, void>> call(int params) {
    return _repository.delete(params);
  }
}

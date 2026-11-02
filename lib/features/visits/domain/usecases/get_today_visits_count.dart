import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/visit_repository.dart';

class GetTodayVisitsCount implements UseCase<int, NoParams> {
  const GetTodayVisitsCount(this._repository);

  final VisitRepository _repository;

  @override
  Future<Either<Failure, int>> call(NoParams params) {
    return _repository.countDistinctPatientsToday();
  }
}

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/visit_field_value.dart';
import '../repositories/visit_repository.dart';

/// Batched counterpart to [GetVisitFieldValues] — fetches every visit's
/// exam readings in one query instead of one query per visit, for callers
/// (like the patient PDF export) that need a whole patient's exam history
/// at once.
class GetVisitFieldValuesForVisits
    implements UseCase<Map<int, List<VisitFieldValue>>, List<int>> {
  const GetVisitFieldValuesForVisits(this._repository);

  final VisitRepository _repository;

  @override
  Future<Either<Failure, Map<int, List<VisitFieldValue>>>> call(
    List<int> visitIds,
  ) {
    return _repository.listFieldValuesForVisits(visitIds);
  }
}

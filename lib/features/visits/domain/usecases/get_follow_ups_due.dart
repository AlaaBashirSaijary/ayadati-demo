import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/follow_up_due.dart';
import '../repositories/visit_repository.dart';

class GetFollowUpsDue implements UseCase<List<FollowUpDue>, NoParams> {
  const GetFollowUpsDue(this._repository);

  final VisitRepository _repository;

  @override
  Future<Either<Failure, List<FollowUpDue>>> call(NoParams params) {
    return _repository.listDueForFollowUp();
  }
}

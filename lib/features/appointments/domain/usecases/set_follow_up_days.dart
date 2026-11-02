import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/appointment_repository.dart';

class SetFollowUpDays implements UseCase<void, int> {
  const SetFollowUpDays(this._repository);

  final AppointmentRepository _repository;

  @override
  Future<Either<Failure, void>> call(int params) {
    return _repository.setFollowUpDays(params);
  }
}

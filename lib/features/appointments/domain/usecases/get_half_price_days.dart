import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/appointment_repository.dart';

class GetHalfPriceDays implements UseCase<int, NoParams> {
  const GetHalfPriceDays(this._repository);

  final AppointmentRepository _repository;

  @override
  Future<Either<Failure, int>> call(NoParams params) {
    return _repository.getHalfPriceDays();
  }
}

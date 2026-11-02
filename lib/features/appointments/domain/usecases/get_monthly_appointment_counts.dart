import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/appointment.dart';
import '../repositories/appointment_repository.dart';

class MonthRangeParams {
  const MonthRangeParams({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

class GetMonthlyAppointmentCounts
    implements UseCase<Map<AppointmentType, int>, MonthRangeParams> {
  const GetMonthlyAppointmentCounts(this._repository);

  final AppointmentRepository _repository;

  @override
  Future<Either<Failure, Map<AppointmentType, int>>> call(
    MonthRangeParams params,
  ) {
    return _repository.countByTypeBetween(params.start, params.end);
  }
}

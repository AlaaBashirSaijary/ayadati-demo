import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/appointment.dart';
import '../repositories/appointment_repository.dart';

class GetAppointmentsForDay implements UseCase<List<Appointment>, DateTime> {
  const GetAppointmentsForDay(this._repository);

  final AppointmentRepository _repository;

  @override
  Future<Either<Failure, List<Appointment>>> call(DateTime params) {
    final start = DateTime(params.year, params.month, params.day);
    final end = start.add(const Duration(days: 1));
    return _repository.listBetween(start, end);
  }
}

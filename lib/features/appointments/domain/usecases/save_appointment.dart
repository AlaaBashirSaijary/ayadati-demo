import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/appointment.dart';
import '../repositories/appointment_repository.dart';

/// Handles both create and update — an Appointment with a null [Appointment.id]
/// is new, same convention as SaveVisit.
class SaveAppointment implements UseCase<Appointment, Appointment> {
  const SaveAppointment(this._repository);

  final AppointmentRepository _repository;

  @override
  Future<Either<Failure, Appointment>> call(Appointment params) {
    return params.id == null
        ? _repository.create(params)
        : _repository.update(params);
  }
}

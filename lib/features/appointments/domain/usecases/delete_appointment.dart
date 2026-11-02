import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/appointment_repository.dart';

class DeleteAppointment implements UseCase<void, int> {
  const DeleteAppointment(this._repository);

  final AppointmentRepository _repository;

  @override
  Future<Either<Failure, void>> call(int params) {
    return _repository.delete(params);
  }
}

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/doctor.dart';
import '../repositories/doctor_repository.dart';

class ToggleDoctorStatus implements UseCase<Doctor, int> {
  const ToggleDoctorStatus(this._repository);

  final DoctorRepository _repository;

  @override
  Future<Either<Failure, Doctor>> call(int id) {
    return _repository.toggleStatus(id);
  }
}

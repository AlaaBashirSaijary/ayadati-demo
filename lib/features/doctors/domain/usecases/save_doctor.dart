import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/doctor.dart';
import '../repositories/doctor_repository.dart';

/// Creates a new doctor, or updates an existing one when [Doctor.id] is
/// set — the same create-or-update-by-id shape as SaveVisit.
class SaveDoctor implements UseCase<Doctor, Doctor> {
  const SaveDoctor(this._repository);

  final DoctorRepository _repository;

  @override
  Future<Either<Failure, Doctor>> call(Doctor params) {
    if (params.name.trim().isEmpty) {
      return Future.value(
        Left(ValidationFailure({'name': 'أدخلي اسم الطبيب.'})),
      );
    }
    return params.id == null
        ? _repository.create(params)
        : _repository.update(params);
  }
}

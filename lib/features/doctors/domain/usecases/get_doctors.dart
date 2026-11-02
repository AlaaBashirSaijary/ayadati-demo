import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/doctor.dart';
import '../repositories/doctor_repository.dart';

class GetDoctorsParams {
  const GetDoctorsParams({this.activeOnly = false});

  final bool activeOnly;
}

class GetDoctors implements UseCase<List<Doctor>, GetDoctorsParams> {
  const GetDoctors(this._repository);

  final DoctorRepository _repository;

  @override
  Future<Either<Failure, List<Doctor>>> call(GetDoctorsParams params) {
    return _repository.list(activeOnly: params.activeOnly);
  }
}

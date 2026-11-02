import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/doctor.dart';

abstract class DoctorRepository {
  Future<Either<Failure, List<Doctor>>> list({bool activeOnly = false});

  Future<Either<Failure, Doctor>> create(Doctor doctor);

  Future<Either<Failure, Doctor>> update(Doctor doctor);

  Future<Either<Failure, Doctor>> toggleStatus(int id);
}

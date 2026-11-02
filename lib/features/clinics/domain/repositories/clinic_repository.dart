import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/clinic.dart';

abstract class ClinicRepository {
  Future<Either<Failure, List<Clinic>>> list();

  /// Creates a new clinic — a new registry row plus a brand new, empty
  /// per-clinic database file for its patients/visits.
  Future<Either<Failure, Clinic>> create(String name, {String? specialtyId});

  Future<Either<Failure, Clinic>> rename(int id, String newName);
}

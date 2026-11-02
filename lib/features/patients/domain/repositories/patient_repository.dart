import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/patient.dart';

/// Mirrors the query surface PatientController + HomeController expose today
/// (index/search/store/update/toggle-status), kept framework-free so the
/// data layer (SQLite today) can be swapped without touching use cases.
///
/// No clinic scoping here: each clinic has its own separate database file
/// (see ClinicDataDatabase), so every query already runs against exactly one
/// clinic's data — there's nothing left to filter by.
abstract class PatientRepository {
  Future<Either<Failure, PatientPage>> list({
    String query = '',
    PatientStatusFilter status = PatientStatusFilter.all,
    int page = 1,
    int perPage = 15,
  });

  Future<Either<Failure, Patient>> find(int id);

  Future<Either<Failure, Patient>> create(Patient patient);

  Future<Either<Failure, Patient>> update(Patient patient);

  Future<Either<Failure, Patient>> toggleStatus(int id);

  /// Mirrors Patient::nextNumberForClinic(): highest numeric patient_number
  /// in the active clinic, plus one.
  Future<Either<Failure, String>> nextPatientNumber();

  Future<Either<Failure, PatientStats>> stats();

  /// New patients created within [start, end) — backs the monthly report.
  Future<Either<Failure, int>> countCreatedBetween(
    DateTime start,
    DateTime end,
  );
}

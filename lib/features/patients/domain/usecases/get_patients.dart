import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/patient.dart';
import '../repositories/patient_repository.dart';

/// Mirrors HomeController::__invoke() / PatientController::index(): a
/// searchable, status-filterable, paginated list — always against
/// whichever clinic's database file is currently active.
class GetPatients implements UseCase<PatientPage, GetPatientsParams> {
  const GetPatients(this._repository);

  final PatientRepository _repository;

  @override
  Future<Either<Failure, PatientPage>> call(GetPatientsParams params) {
    return _repository.list(
      query: params.query,
      status: params.status,
      page: params.page,
      perPage: params.perPage,
    );
  }
}

class GetPatientsParams extends Equatable {
  const GetPatientsParams({
    this.query = '',
    this.status = PatientStatusFilter.all,
    this.page = 1,
    this.perPage = 15,
  });

  final String query;
  final PatientStatusFilter status;
  final int page;
  final int perPage;

  @override
  List<Object?> get props => [query, status, page, perPage];
}

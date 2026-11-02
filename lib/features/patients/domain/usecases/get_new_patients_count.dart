import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/patient_repository.dart';

class DateRangeParams extends Equatable {
  const DateRangeParams({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  @override
  List<Object?> get props => [start, end];
}

class GetNewPatientsCount implements UseCase<int, DateRangeParams> {
  const GetNewPatientsCount(this._repository);

  final PatientRepository _repository;

  @override
  Future<Either<Failure, int>> call(DateRangeParams params) {
    return _repository.countCreatedBetween(params.start, params.end);
  }
}

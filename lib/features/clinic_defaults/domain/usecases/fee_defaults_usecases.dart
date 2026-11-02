import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/fee_defaults.dart';
import '../repositories/clinic_defaults_repository.dart';

class GetFeeDefaults implements UseCase<FeeDefaults, NoParams> {
  const GetFeeDefaults(this._repository);

  final ClinicDefaultsRepository _repository;

  @override
  Future<Either<Failure, FeeDefaults>> call(NoParams params) =>
      _repository.getFeeDefaults();
}

class SaveFeeDefaults implements UseCase<void, FeeDefaults> {
  const SaveFeeDefaults(this._repository);

  final ClinicDefaultsRepository _repository;

  @override
  Future<Either<Failure, void>> call(FeeDefaults params) =>
      _repository.saveFeeDefaults(params);
}

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/visit_field_value.dart';
import '../repositories/visit_repository.dart';

class SaveVisitFieldValuesParams {
  const SaveVisitFieldValuesParams({
    required this.visitId,
    required this.values,
  });

  final int visitId;
  final List<VisitFieldValue> values;
}

class SaveVisitFieldValues
    implements UseCase<void, SaveVisitFieldValuesParams> {
  const SaveVisitFieldValues(this._repository);

  final VisitRepository _repository;

  @override
  Future<Either<Failure, void>> call(SaveVisitFieldValuesParams params) {
    return _repository.saveFieldValues(params.visitId, params.values);
  }
}

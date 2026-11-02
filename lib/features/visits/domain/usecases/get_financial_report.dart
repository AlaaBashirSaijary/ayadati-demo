import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../patients/domain/usecases/get_new_patients_count.dart'
    show DateRangeParams;
import '../entities/financial_report.dart';
import '../repositories/visit_repository.dart';

class GetFinancialReport implements UseCase<FinancialReport, DateRangeParams> {
  const GetFinancialReport(this._repository);

  final VisitRepository _repository;

  @override
  Future<Either<Failure, FinancialReport>> call(DateRangeParams params) {
    return _repository.financialReport(params.start, params.end);
  }
}

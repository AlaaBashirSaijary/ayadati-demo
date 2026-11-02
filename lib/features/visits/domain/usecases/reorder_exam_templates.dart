import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/exam_template_repository.dart';

class ReorderExamTemplates implements UseCase<void, List<int>> {
  const ReorderExamTemplates(this._repository);

  final ExamTemplateRepository _repository;

  @override
  Future<Either<Failure, void>> call(List<int> params) {
    return _repository.reorder(params);
  }
}

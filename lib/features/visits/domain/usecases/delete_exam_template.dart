import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/exam_template_repository.dart';

class DeleteExamTemplate implements UseCase<void, int> {
  const DeleteExamTemplate(this._repository);

  final ExamTemplateRepository _repository;

  @override
  Future<Either<Failure, void>> call(int params) {
    return _repository.delete(params);
  }
}

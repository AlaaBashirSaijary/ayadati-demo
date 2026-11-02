import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/exam_field_template.dart';
import '../repositories/exam_template_repository.dart';

class GetExamTemplates implements UseCase<List<ExamFieldTemplate>, NoParams> {
  const GetExamTemplates(this._repository);

  final ExamTemplateRepository _repository;

  @override
  Future<Either<Failure, List<ExamFieldTemplate>>> call(NoParams params) {
    return _repository.list();
  }
}

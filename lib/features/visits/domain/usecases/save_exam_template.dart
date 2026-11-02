import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/exam_field_template.dart';
import '../repositories/exam_template_repository.dart';

/// Handles both create and update — a template with a null [ExamFieldTemplate
/// .id] is new.
class SaveExamTemplate
    implements UseCase<ExamFieldTemplate, ExamFieldTemplate> {
  const SaveExamTemplate(this._repository);

  final ExamTemplateRepository _repository;

  @override
  Future<Either<Failure, ExamFieldTemplate>> call(ExamFieldTemplate params) {
    return params.id == null
        ? _repository.create(params.label, params.hasSides, params.isLongText)
        : _repository.update(params);
  }
}

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/exam_field_template.dart';

abstract class ExamTemplateRepository {
  Future<Either<Failure, List<ExamFieldTemplate>>> list();

  Future<Either<Failure, ExamFieldTemplate>> create(
    String label,
    bool hasSides,
    bool isLongText,
  );

  Future<Either<Failure, ExamFieldTemplate>> update(ExamFieldTemplate template);

  Future<Either<Failure, void>> delete(int id);

  Future<Either<Failure, void>> reorder(List<int> orderedIds);
}

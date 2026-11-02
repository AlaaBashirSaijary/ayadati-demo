import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/exam_field_template.dart';
import '../../domain/repositories/exam_template_repository.dart';
import '../datasources/exam_template_local_datasource.dart';
import '../models/exam_field_template_model.dart';

class ExamTemplateRepositoryImpl implements ExamTemplateRepository {
  const ExamTemplateRepositoryImpl(this._local);

  final ExamTemplateLocalDataSource _local;

  @override
  Future<Either<Failure, List<ExamFieldTemplate>>> list() async {
    try {
      return Right(await _local.list());
    } catch (e) {
      return Left(StorageFailure.from('تعذّرت قراءة نموذج الفحص', e));
    }
  }

  @override
  Future<Either<Failure, ExamFieldTemplate>> create(
    String label,
    bool hasSides,
    bool isLongText,
  ) async {
    try {
      return Right(await _local.create(label, hasSides, isLongText));
    } catch (e) {
      return Left(StorageFailure.from('تعذّر إضافة حقل الفحص', e));
    }
  }

  @override
  Future<Either<Failure, ExamFieldTemplate>> update(
    ExamFieldTemplate template,
  ) async {
    try {
      return Right(
        await _local.update(
          ExamFieldTemplateModel(
            id: template.id,
            label: template.label,
            hasSides: template.hasSides,
            isLongText: template.isLongText,
            sortOrder: template.sortOrder,
          ),
        ),
      );
    } catch (e) {
      return Left(StorageFailure.from('تعذّر تحديث حقل الفحص', e));
    }
  }

  @override
  Future<Either<Failure, void>> delete(int id) async {
    try {
      await _local.delete(id);
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure.from('تعذّر حذف حقل الفحص', e));
    }
  }

  @override
  Future<Either<Failure, void>> reorder(List<int> orderedIds) async {
    try {
      await _local.reorder(orderedIds);
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure.from('تعذّر إعادة ترتيب حقول الفحص', e));
    }
  }
}

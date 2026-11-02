import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/activity_log_service.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/financial_report.dart';
import '../../domain/entities/follow_up_due.dart';
import '../../domain/entities/patient_photo.dart';
import '../../domain/entities/visit.dart';
import '../../domain/entities/visit_field_value.dart';
import '../../domain/entities/visit_photo.dart';
import '../../domain/repositories/visit_repository.dart';
import '../datasources/visit_local_datasource.dart';
import '../models/visit_field_value_model.dart';
import '../models/visit_model.dart';

class VisitRepositoryImpl implements VisitRepository {
  const VisitRepositoryImpl(this._local);

  final VisitLocalDataSource _local;

  static final _dateFormat = DateFormat('yyyy/MM/dd');

  @override
  Future<Either<Failure, List<Visit>>> listForPatient(int patientId) async {
    try {
      return Right(await _local.listForPatient(patientId));
    } catch (e) {
      return Left(StorageFailure.from('تعذّرت قراءة زيارات الفحص', e));
    }
  }

  @override
  Future<Either<Failure, Visit>> create(Visit visit) async {
    try {
      final created = await _local.create(VisitModel.fromEntity(visit));
      await ActivityLogService.instance.log(
        ActivityAction.visitCreated,
        entityLabel: _dateFormat.format(created.visitDate),
      );
      return Right(created);
    } catch (e) {
      return Left(StorageFailure.from('تعذّر حفظ زيارة الفحص', e));
    }
  }

  @override
  Future<Either<Failure, Visit>> update(Visit visit) async {
    try {
      final updated = await _local.update(VisitModel.fromEntity(visit));
      await ActivityLogService.instance.log(
        ActivityAction.visitUpdated,
        entityLabel: _dateFormat.format(updated.visitDate),
      );
      return Right(updated);
    } catch (e) {
      return Left(StorageFailure.from('تعذّر تحديث زيارة الفحص', e));
    }
  }

  @override
  Future<Either<Failure, void>> delete(int id) async {
    try {
      final existing = await _local.find(id);
      await _local.delete(id);
      await ActivityLogService.instance.log(
        ActivityAction.visitDeleted,
        entityLabel: existing == null
            ? null
            : _dateFormat.format(existing.visitDate),
      );
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure.from('تعذّر حذف زيارة الفحص', e));
    }
  }

  @override
  Future<Either<Failure, List<FollowUpDue>>> listDueForFollowUp() async {
    try {
      return Right(await _local.listDueForFollowUp());
    } catch (e) {
      return Left(StorageFailure.from('تعذّرت قراءة المتابعات المستحقة', e));
    }
  }

  @override
  Future<Either<Failure, FinancialReport>> financialReport(
    DateTime start,
    DateTime end,
  ) async {
    try {
      return Right(await _local.financialReport(start, end));
    } catch (e) {
      return Left(StorageFailure.from('تعذّرت قراءة التقرير المالي', e));
    }
  }

  @override
  Future<Either<Failure, int>> countDistinctPatientsToday() async {
    try {
      return Right(await _local.countDistinctPatientsToday());
    } catch (e) {
      return Left(StorageFailure.from('تعذّر حساب مرضى اليوم', e));
    }
  }

  @override
  Future<Either<Failure, List<VisitPhoto>>> listPhotos(int visitId) async {
    try {
      return Right(await _local.listPhotos(visitId));
    } catch (e) {
      return Left(StorageFailure.from('تعذّرت قراءة صور الزيارة', e));
    }
  }

  @override
  Future<Either<Failure, void>> addPhoto(
    int visitId,
    Uint8List imageData,
  ) async {
    try {
      await _local.addPhoto(visitId, imageData);
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure.from('تعذّر حفظ الصورة', e));
    }
  }

  @override
  Future<Either<Failure, void>> deletePhoto(int id) async {
    try {
      await _local.deletePhoto(id);
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure.from('تعذّر حذف الصورة', e));
    }
  }

  @override
  Future<Either<Failure, List<PatientPhoto>>> listPhotosForPatient(
    int patientId,
  ) async {
    try {
      return Right(await _local.listPhotosForPatient(patientId));
    } catch (e) {
      return Left(StorageFailure.from('تعذّرت قراءة صور المريض', e));
    }
  }

  @override
  Future<Either<Failure, List<VisitFieldValue>>> listFieldValues(
    int visitId,
  ) async {
    try {
      return Right(await _local.listFieldValues(visitId));
    } catch (e) {
      return Left(StorageFailure.from('تعذّرت قراءة بيانات الفحص', e));
    }
  }

  @override
  Future<Either<Failure, Map<int, List<VisitFieldValue>>>>
  listFieldValuesForVisits(List<int> visitIds) async {
    try {
      return Right(await _local.listFieldValuesForVisits(visitIds));
    } catch (e) {
      return Left(StorageFailure.from('تعذّرت قراءة بيانات الفحص', e));
    }
  }

  @override
  Future<Either<Failure, void>> saveFieldValues(
    int visitId,
    List<VisitFieldValue> values,
  ) async {
    try {
      await _local.saveFieldValues(visitId, [
        for (final value in values)
          VisitFieldValueModel(
            visitId: value.visitId,
            templateId: value.templateId,
            side: value.side,
            value: value.value,
          ),
      ]);
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure.from('تعذّر حفظ بيانات الفحص', e));
    }
  }
}

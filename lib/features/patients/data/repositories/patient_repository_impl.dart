import 'package:dartz/dartz.dart';

import '../../../../core/database/activity_log_service.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/patient.dart';
import '../../domain/repositories/patient_repository.dart';
import '../datasources/patient_local_datasource.dart';
import '../models/patient_model.dart';

class PatientRepositoryImpl implements PatientRepository {
  const PatientRepositoryImpl(this._local);

  final PatientLocalDataSource _local;

  @override
  Future<Either<Failure, PatientPage>> list({
    String query = '',
    PatientStatusFilter status = PatientStatusFilter.all,
    int page = 1,
    int perPage = 15,
  }) async {
    try {
      final result = await _local.list(
        query: query,
        status: status,
        page: page,
        perPage: perPage,
      );
      return Right(
        PatientPage(
          items: result.items,
          total: result.total,
          page: page,
          perPage: perPage,
        ),
      );
    } catch (e) {
      return Left(StorageFailure.from('تعذّرت قراءة قائمة المرضى', e));
    }
  }

  @override
  Future<Either<Failure, Patient>> find(int id) async {
    try {
      final patient = await _local.find(id);
      if (patient == null) {
        return const Left(NotFoundFailure('المريض غير موجود.'));
      }
      return Right(patient);
    } catch (e) {
      return Left(StorageFailure.from('تعذّرت قراءة بيانات المريض', e));
    }
  }

  @override
  Future<Either<Failure, Patient>> create(Patient patient) async {
    try {
      final created = await _local.create(PatientModel.fromEntity(patient));
      await ActivityLogService.instance.log(
        ActivityAction.patientCreated,
        entityLabel: created.fullName,
      );
      return Right(created);
    } catch (e) {
      return Left(StorageFailure.from('تعذّر حفظ إضبارة المريض', e));
    }
  }

  @override
  Future<Either<Failure, Patient>> update(Patient patient) async {
    try {
      final existing = await _local.find(patient.id!);
      if (existing == null) {
        return const Left(NotFoundFailure('المريض غير موجود.'));
      }
      final updated = await _local.update(PatientModel.fromEntity(patient));
      await ActivityLogService.instance.log(
        ActivityAction.patientUpdated,
        entityLabel: updated.fullName,
      );
      return Right(updated);
    } catch (e) {
      return Left(StorageFailure.from('تعذّر تحديث إضبارة المريض', e));
    }
  }

  @override
  Future<Either<Failure, Patient>> toggleStatus(int id) async {
    try {
      final existing = await _local.find(id);
      if (existing == null) {
        return const Left(NotFoundFailure('المريض غير موجود.'));
      }
      final updated = await _local.toggleStatus(id);
      await ActivityLogService.instance.log(
        updated.isActive
            ? ActivityAction.patientActivated
            : ActivityAction.patientDeactivated,
        entityLabel: updated.fullName,
      );
      return Right(updated);
    } catch (e) {
      return Left(StorageFailure.from('تعذّر تحديث حالة المريض', e));
    }
  }

  @override
  Future<Either<Failure, String>> nextPatientNumber() async {
    try {
      return Right(await _local.nextPatientNumber());
    } catch (e) {
      return Left(StorageFailure.from('تعذّر توليد رقم المريض', e));
    }
  }

  @override
  Future<Either<Failure, PatientStats>> stats() async {
    try {
      final counts = await _local.counts();
      return Right(
        PatientStats(
          total: counts.total,
          active: counts.active,
          inactive: counts.inactive,
        ),
      );
    } catch (e) {
      return Left(StorageFailure.from('تعذّرت قراءة إحصاءات المرضى', e));
    }
  }

  @override
  Future<Either<Failure, int>> countCreatedBetween(
    DateTime start,
    DateTime end,
  ) async {
    try {
      return Right(await _local.countCreatedBetween(start, end));
    } catch (e) {
      return Left(StorageFailure.from('تعذّر حساب المرضى الجدد', e));
    }
  }
}

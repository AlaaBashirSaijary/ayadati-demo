import 'package:dartz/dartz.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/activity_log_service.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/repositories/appointment_repository.dart';
import '../datasources/appointment_local_datasource.dart';
import '../models/appointment_model.dart';

class AppointmentRepositoryImpl implements AppointmentRepository {
  const AppointmentRepositoryImpl(this._local);

  final AppointmentLocalDataSource _local;

  static final _dateTimeFormat = DateFormat('yyyy/MM/dd h:mm a', 'ar');

  @override
  Future<Either<Failure, List<Appointment>>> listBetween(
    DateTime start,
    DateTime end,
  ) async {
    try {
      return Right(await _local.listBetween(start, end));
    } catch (e) {
      return Left(StorageFailure.from('تعذّرت قراءة المواعيد', e));
    }
  }

  @override
  Future<Either<Failure, List<Appointment>>> listUpcoming({
    int limit = 20,
  }) async {
    try {
      return Right(await _local.listUpcoming(limit: limit));
    } catch (e) {
      return Left(StorageFailure.from('تعذّرت قراءة المواعيد القادمة', e));
    }
  }

  @override
  Future<Either<Failure, Appointment>> create(Appointment appointment) async {
    try {
      final created = await _local.create(
        AppointmentModel.fromEntity(appointment),
      );
      await ActivityLogService.instance.log(
        ActivityAction.appointmentCreated,
        entityLabel: _label(created),
      );
      return Right(created);
    } catch (e) {
      return Left(StorageFailure.from('تعذّر حجز الموعد', e));
    }
  }

  @override
  Future<Either<Failure, Appointment>> update(Appointment appointment) async {
    try {
      final updated = await _local.update(
        AppointmentModel.fromEntity(appointment),
      );
      await ActivityLogService.instance.log(
        ActivityAction.appointmentUpdated,
        entityLabel: _label(updated),
      );
      return Right(updated);
    } catch (e) {
      return Left(StorageFailure.from('تعذّر تحديث الموعد', e));
    }
  }

  @override
  Future<Either<Failure, void>> delete(int id) async {
    try {
      final existing = await _local.find(id);
      await _local.delete(id);
      await ActivityLogService.instance.log(
        ActivityAction.appointmentDeleted,
        entityLabel: existing == null ? null : _label(existing),
      );
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure.from('تعذّر حذف الموعد', e));
    }
  }

  String _label(Appointment appointment) {
    final patient = appointment.patientName;
    final when = _dateTimeFormat.format(appointment.scheduledAt);
    return patient == null ? when : '$patient — $when';
  }

  @override
  Future<Either<Failure, DateTime?>> lastConsultationDate(int patientId) async {
    try {
      return Right(await _local.lastConsultationDate(patientId));
    } catch (e) {
      return Left(StorageFailure.from('تعذّرت قراءة سجل الكشفيات', e));
    }
  }

  @override
  Future<Either<Failure, int>> getFollowUpDays() async {
    try {
      return Right(await _local.getFollowUpDays());
    } catch (e) {
      return Left(StorageFailure.from('تعذّرت قراءة إعداد فترة المتابعة', e));
    }
  }

  @override
  Future<Either<Failure, void>> setFollowUpDays(int days) async {
    try {
      await _local.setFollowUpDays(days);
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure.from('تعذّر حفظ إعداد فترة المتابعة', e));
    }
  }

  @override
  Future<Either<Failure, int>> getHalfPriceDays() async {
    try {
      return Right(await _local.getHalfPriceDays());
    } catch (e) {
      return Left(
        StorageFailure.from('تعذّرت قراءة إعداد فترة المراجعة بنصف السعر', e),
      );
    }
  }

  @override
  Future<Either<Failure, void>> setHalfPriceDays(int days) async {
    try {
      await _local.setHalfPriceDays(days);
      return const Right(null);
    } catch (e) {
      return Left(
        StorageFailure.from('تعذّر حفظ إعداد فترة المراجعة بنصف السعر', e),
      );
    }
  }

  @override
  Future<Either<Failure, Map<AppointmentType, int>>> countByTypeBetween(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final raw = await _local.countByTypeBetween(start, end);
      return Right({
        for (final entry in raw.entries)
          AppointmentType.fromValue(entry.key): entry.value,
      });
    } catch (e) {
      return Left(StorageFailure.from('تعذّر حساب إحصاء المواعيد', e));
    }
  }

  @override
  Future<Either<Failure, Appointment?>> findConflict(
    DateTime scheduledAt, {
    int? excludeId,
  }) async {
    try {
      return Right(
        await _local.findConflict(scheduledAt, excludeId: excludeId),
      );
    } catch (e) {
      return Left(StorageFailure.from('تعذّر التحقق من تعارض الموعد', e));
    }
  }
}

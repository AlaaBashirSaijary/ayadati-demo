import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/repositories/doctor_repository.dart';
import '../datasources/doctor_local_datasource.dart';
import '../models/doctor_model.dart';

class DoctorRepositoryImpl implements DoctorRepository {
  const DoctorRepositoryImpl(this._local);

  final DoctorLocalDataSource _local;

  @override
  Future<Either<Failure, List<Doctor>>> list({bool activeOnly = false}) async {
    try {
      return Right(await _local.list(activeOnly: activeOnly));
    } catch (e) {
      return Left(StorageFailure.from('تعذّرت قراءة قائمة الأطباء', e));
    }
  }

  @override
  Future<Either<Failure, Doctor>> create(Doctor doctor) async {
    try {
      return Right(await _local.create(DoctorModel.fromEntity(doctor)));
    } catch (e) {
      return Left(StorageFailure.from('تعذّر إضافة الطبيب', e));
    }
  }

  @override
  Future<Either<Failure, Doctor>> update(Doctor doctor) async {
    try {
      return Right(await _local.update(DoctorModel.fromEntity(doctor)));
    } catch (e) {
      return Left(StorageFailure.from('تعذّر تعديل بيانات الطبيب', e));
    }
  }

  @override
  Future<Either<Failure, Doctor>> toggleStatus(int id) async {
    try {
      final existing = await _local.find(id);
      if (existing == null) {
        return const Left(StorageFailure('الطبيب غير موجود.'));
      }
      final updated = DoctorModel.fromEntity(
        existing.copyWith(isActive: !existing.isActive),
      );
      return Right(await _local.update(updated));
    } catch (e) {
      return Left(StorageFailure.from('تعذّر تغيير حالة الطبيب', e));
    }
  }
}

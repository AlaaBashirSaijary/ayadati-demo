import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/prescription.dart';
import '../../domain/repositories/prescription_repository.dart';
import '../datasources/prescription_local_datasource.dart';
import '../models/prescription_model.dart';

class PrescriptionRepositoryImpl implements PrescriptionRepository {
  const PrescriptionRepositoryImpl(this._local);

  final PrescriptionLocalDataSource _local;

  @override
  Future<Either<Failure, List<Prescription>>> listForPatient(
    int patientId,
  ) async {
    try {
      return Right(await _local.listForPatient(patientId));
    } catch (e) {
      return Left(StorageFailure.from('تعذّرت قراءة الوصفات الطبية', e));
    }
  }

  @override
  Future<Either<Failure, Prescription>> create(
    Prescription prescription,
  ) async {
    try {
      return Right(
        await _local.create(PrescriptionModel.fromEntity(prescription)),
      );
    } catch (e) {
      return Left(StorageFailure.from('تعذّر حفظ الوصفة الطبية', e));
    }
  }
}

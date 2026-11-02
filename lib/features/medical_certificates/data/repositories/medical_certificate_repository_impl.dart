import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/medical_certificate.dart';
import '../../domain/repositories/medical_certificate_repository.dart';
import '../datasources/medical_certificate_local_datasource.dart';
import '../models/medical_certificate_model.dart';

class MedicalCertificateRepositoryImpl implements MedicalCertificateRepository {
  const MedicalCertificateRepositoryImpl(this._local);

  final MedicalCertificateLocalDataSource _local;

  @override
  Future<Either<Failure, List<MedicalCertificate>>> listForPatient(
    int patientId,
  ) async {
    try {
      return Right(await _local.listForPatient(patientId));
    } catch (e) {
      return Left(StorageFailure.from('تعذّرت قراءة التقارير الطبية', e));
    }
  }

  @override
  Future<Either<Failure, MedicalCertificate>> create(
    MedicalCertificate certificate,
  ) async {
    try {
      return Right(
        await _local.create(MedicalCertificateModel.fromEntity(certificate)),
      );
    } catch (e) {
      return Left(StorageFailure.from('تعذّر حفظ التقرير الطبي', e));
    }
  }
}

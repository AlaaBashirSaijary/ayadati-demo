import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/clinic.dart';
import '../../domain/repositories/clinic_repository.dart';
import '../datasources/clinic_local_datasource.dart';

class ClinicRepositoryImpl implements ClinicRepository {
  const ClinicRepositoryImpl(this._local);

  final ClinicLocalDataSource _local;

  @override
  Future<Either<Failure, List<Clinic>>> list() async {
    try {
      // List<ClinicModel>.from(...) so the returned list is genuinely
      // reified as List<Clinic> — otherwise the object stays a
      // List<ClinicModel> at runtime despite the List<Clinic> return type,
      // and callers doing e.g. `clinics.firstWhere(orElse: () => clinics.first)`
      // hit a runtime type error since firstWhere's generic binds to the
      // list's actual (unwidened) element type.
      final models = await _local.list();
      return Right(List<Clinic>.from(models));
    } catch (e) {
      return Left(StorageFailure.from('تعذّرت قراءة قائمة العيادات', e));
    }
  }

  @override
  Future<Either<Failure, Clinic>> create(
    String name, {
    String? specialtyId,
  }) async {
    if (name.trim().isEmpty) {
      return const Left(ValidationFailure({'name': 'أدخلي اسم العيادة.'}));
    }
    try {
      return Right(await _local.create(name.trim(), specialtyId: specialtyId));
    } catch (e) {
      return Left(StorageFailure.from('تعذّر إنشاء العيادة', e));
    }
  }

  @override
  Future<Either<Failure, Clinic>> rename(int id, String newName) async {
    if (newName.trim().isEmpty) {
      return const Left(ValidationFailure({'name': 'أدخلي اسم العيادة.'}));
    }
    try {
      return Right(await _local.rename(id, newName.trim()));
    } catch (e) {
      return Left(StorageFailure.from('تعذّر تعديل اسم العيادة', e));
    }
  }
}

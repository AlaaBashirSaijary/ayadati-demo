import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/fee_defaults.dart';
import '../../domain/entities/phrase_kind.dart';
import '../../domain/repositories/clinic_defaults_repository.dart';
import '../datasources/clinic_defaults_local_datasource.dart';

class ClinicDefaultsRepositoryImpl implements ClinicDefaultsRepository {
  const ClinicDefaultsRepositoryImpl(this._local);

  final ClinicDefaultsLocalDataSource _local;

  @override
  Future<Either<Failure, FeeDefaults>> getFeeDefaults() async {
    try {
      return Right(await _local.getFeeDefaults());
    } catch (e) {
      return Left(StorageFailure.from('تعذّرت قراءة الأسعار الافتراضية', e));
    }
  }

  @override
  Future<Either<Failure, void>> saveFeeDefaults(FeeDefaults defaults) async {
    try {
      await _local.saveFeeDefaults(defaults);
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure.from('تعذّر حفظ الأسعار الافتراضية', e));
    }
  }

  @override
  Future<Either<Failure, List<String>>> listPhrases(PhraseKind kind) async {
    try {
      return Right(await _local.listPhrases(kind));
    } catch (e) {
      return Left(StorageFailure.from('تعذّرت قراءة العبارات السريعة', e));
    }
  }

  @override
  Future<Either<Failure, void>> recordPhrase(
    PhraseKind kind,
    String text,
  ) async {
    try {
      await _local.recordPhrase(kind, text);
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure.from('تعذّر حفظ العبارة', e));
    }
  }

  @override
  Future<Either<Failure, void>> deletePhrase(
    PhraseKind kind,
    String text,
  ) async {
    try {
      await _local.deletePhrase(kind, text);
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure.from('تعذّر حذف العبارة', e));
    }
  }
}

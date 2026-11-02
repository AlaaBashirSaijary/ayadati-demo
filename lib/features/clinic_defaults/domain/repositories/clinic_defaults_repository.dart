import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/fee_defaults.dart';
import '../entities/phrase_kind.dart';

abstract class ClinicDefaultsRepository {
  Future<Either<Failure, FeeDefaults>> getFeeDefaults();

  Future<Either<Failure, void>> saveFeeDefaults(FeeDefaults defaults);

  /// Most-used first, so the first chips are the ones the doctor reaches for.
  Future<Either<Failure, List<String>>> listPhrases(PhraseKind kind);

  /// Adds the phrase, or bumps its use count if it already exists — so
  /// anything the doctor types and saves becomes a suggestion by itself.
  Future<Either<Failure, void>> recordPhrase(PhraseKind kind, String text);

  Future<Either<Failure, void>> deletePhrase(PhraseKind kind, String text);
}

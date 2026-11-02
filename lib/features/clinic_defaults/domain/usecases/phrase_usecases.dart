import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/phrase_kind.dart';
import '../repositories/clinic_defaults_repository.dart';

class GetPhrases implements UseCase<List<String>, PhraseKind> {
  const GetPhrases(this._repository);

  final ClinicDefaultsRepository _repository;

  @override
  Future<Either<Failure, List<String>>> call(PhraseKind params) =>
      _repository.listPhrases(params);
}

class PhraseParams {
  const PhraseParams(this.kind, this.text);

  final PhraseKind kind;
  final String text;
}

class RecordPhrase implements UseCase<void, PhraseParams> {
  const RecordPhrase(this._repository);

  final ClinicDefaultsRepository _repository;

  @override
  Future<Either<Failure, void>> call(PhraseParams params) =>
      _repository.recordPhrase(params.kind, params.text);
}

class DeletePhrase implements UseCase<void, PhraseParams> {
  const DeletePhrase(this._repository);

  final ClinicDefaultsRepository _repository;

  @override
  Future<Either<Failure, void>> call(PhraseParams params) =>
      _repository.deletePhrase(params.kind, params.text);
}

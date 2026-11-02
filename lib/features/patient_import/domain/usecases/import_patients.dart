import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../patients/domain/entities/patient.dart'
    show Patient, PatientPage;
import '../../../patients/domain/repositories/patient_repository.dart';
import '../../../patients/domain/usecases/create_patient.dart';
import '../entities/import_summary.dart';

/// Creates every draft in [Params], skipping a draft whose full name
/// (trimmed, case-insensitive) already exists — either already in the
/// clinic, or earlier in this same batch — so re-running an import after
/// fixing a mapping mistake never doubles up patients. Reuses
/// [CreatePatient] so imported rows go through the exact same validation
/// and patient-number assignment as a manually-added patient.
class ImportPatients implements UseCase<ImportSummary, List<Patient>> {
  const ImportPatients(this._createPatient, this._repository);

  final CreatePatient _createPatient;
  final PatientRepository _repository;

  @override
  Future<Either<Failure, ImportSummary>> call(List<Patient> params) async {
    final existingResult = await _repository.list(perPage: 1000000);
    Failure? listFailure;
    PatientPage existingPage = const PatientPage(
      items: [],
      total: 0,
      page: 1,
      perPage: 0,
    );
    existingResult.fold((f) => listFailure = f, (p) => existingPage = p);
    if (listFailure != null) return Left(listFailure!);

    final seenNames = {
      for (final p in existingPage.items) _normalize(p.fullName),
    };

    var summary = const ImportSummary();
    for (final draft in params) {
      final key = _normalize(draft.fullName);
      if (key.isEmpty || seenNames.contains(key)) {
        summary = summary.copyWith(
          duplicatesSkipped: summary.duplicatesSkipped + 1,
        );
        continue;
      }

      final created = await _createPatient(draft);
      created.fold(
        (_) => summary = summary.copyWith(failed: summary.failed + 1),
        (_) => summary = summary.copyWith(imported: summary.imported + 1),
      );
      seenNames.add(key);
    }

    return Right(summary);
  }

  String _normalize(String name) => name.trim().toLowerCase();
}

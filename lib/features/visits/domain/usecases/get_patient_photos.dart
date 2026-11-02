import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/patient_photo.dart';
import '../repositories/visit_repository.dart';

class GetPatientPhotos implements UseCase<List<PatientPhoto>, int> {
  const GetPatientPhotos(this._repository);

  final VisitRepository _repository;

  @override
  Future<Either<Failure, List<PatientPhoto>>> call(int patientId) {
    return _repository.listPhotosForPatient(patientId);
  }
}

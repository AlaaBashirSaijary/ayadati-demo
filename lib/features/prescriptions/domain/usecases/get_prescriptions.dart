import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/prescription.dart';
import '../repositories/prescription_repository.dart';

class GetPrescriptions implements UseCase<List<Prescription>, int> {
  const GetPrescriptions(this._repository);

  final PrescriptionRepository _repository;

  @override
  Future<Either<Failure, List<Prescription>>> call(int patientId) {
    return _repository.listForPatient(patientId);
  }
}

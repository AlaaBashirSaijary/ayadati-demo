import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/prescription.dart';

abstract class PrescriptionRepository {
  Future<Either<Failure, List<Prescription>>> listForPatient(int patientId);

  Future<Either<Failure, Prescription>> create(Prescription prescription);
}

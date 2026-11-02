import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/appointment.dart';
import '../repositories/appointment_repository.dart';

class FindAppointmentConflictParams {
  const FindAppointmentConflictParams({
    required this.scheduledAt,
    this.excludeId,
  });

  final DateTime scheduledAt;

  /// The appointment being edited, if any — excluded from the conflict
  /// check so re-saving one at its own unchanged time doesn't flag itself.
  final int? excludeId;
}

/// Looks up whether another patient already has a non-cancelled
/// appointment at the exact same time — used to warn staff before they
/// double-book a slot by mistake, while still letting them confirm and
/// proceed if it's intentional.
class FindAppointmentConflict
    implements UseCase<Appointment?, FindAppointmentConflictParams> {
  const FindAppointmentConflict(this._repository);

  final AppointmentRepository _repository;

  @override
  Future<Either<Failure, Appointment?>> call(
    FindAppointmentConflictParams params,
  ) {
    return _repository.findConflict(
      params.scheduledAt,
      excludeId: params.excludeId,
    );
  }
}

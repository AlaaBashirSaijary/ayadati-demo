import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/appointment.dart';
import '../repositories/appointment_repository.dart';

class FollowUpSuggestion {
  const FollowUpSuggestion({
    required this.suggestedType,
    required this.followUpDays,
    required this.halfPriceDays,
    this.lastConsultationDate,
  });

  final AppointmentType suggestedType;
  final int followUpDays;
  final int halfPriceDays;
  final DateTime? lastConsultationDate;
}

/// Looks up a patient's last consultation and the clinic's two booking
/// windows, and suggests which type a new booking should default to: free
/// within [followUpDays], half price for the stretch after that up to
/// [halfPriceDays], and a fresh full-price consultation beyond it (or if
/// there's no prior consultation at all). Staff can still override it in
/// the form.
class GetFollowUpSuggestion implements UseCase<FollowUpSuggestion, int> {
  const GetFollowUpSuggestion(this._repository);

  final AppointmentRepository _repository;

  @override
  Future<Either<Failure, FollowUpSuggestion>> call(int patientId) async {
    final daysResult = await _repository.getFollowUpDays();
    return daysResult.fold((failure) => Future.value(Left(failure)), (
      followUpDays,
    ) async {
      final halfDaysResult = await _repository.getHalfPriceDays();
      return halfDaysResult.fold((failure) => Future.value(Left(failure)), (
        halfPriceDays,
      ) async {
        final lastResult = await _repository.lastConsultationDate(patientId);
        return lastResult.fold(Left.new, (last) {
          final daysSince = last == null
              ? null
              : DateTime.now().difference(last).inDays;

          final AppointmentType suggested;
          if (daysSince == null) {
            suggested = AppointmentType.consultation;
          } else if (daysSince <= followUpDays) {
            suggested = AppointmentType.followUp;
          } else if (daysSince <= halfPriceDays) {
            suggested = AppointmentType.halfConsultation;
          } else {
            suggested = AppointmentType.consultation;
          }

          return Right(
            FollowUpSuggestion(
              suggestedType: suggested,
              followUpDays: followUpDays,
              halfPriceDays: halfPriceDays,
              lastConsultationDate: last,
            ),
          );
        });
      });
    });
  }
}

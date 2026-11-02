import 'package:equatable/equatable.dart';

/// One row of the "متابعات مستحقة" list: a patient whose most recent visit
/// was flagged [Visit.needsFollowUp] and who hasn't been seen again since
/// — the moment they have a newer visit, they drop off this list on their
/// own, so there's nothing to mark "resolved" by hand.
class FollowUpDue extends Equatable {
  const FollowUpDue({
    required this.visitId,
    required this.patientId,
    required this.patientName,
    this.patientPhone,
    required this.visitDate,
    this.followUpBy,
  });

  final int visitId;
  final int patientId;
  final String patientName;
  final String? patientPhone;

  /// The flagged visit's own date — how long ago the doctor saw them.
  final DateTime visitDate;

  /// The doctor's target date for the follow-up, if one was set.
  final DateTime? followUpBy;

  /// True once [followUpBy] has passed — used to highlight overdue rows
  /// ahead of ones still coming up.
  bool get isOverdue =>
      followUpBy != null && followUpBy!.isBefore(DateTime.now());

  @override
  List<Object?> get props => [
    visitId,
    patientId,
    patientName,
    patientPhone,
    visitDate,
    followUpBy,
  ];
}

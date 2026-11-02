import 'package:equatable/equatable.dart';

import '../../../../core/money/currency.dart';
import 'visit_type.dart';

/// A single exam visit — the digital equivalent of one filled-in page from
/// the clinic's paper "إضبارة" chart. A patient accumulates one of these
/// per visit rather than the chart having a single fixed exam section.
///
/// What's actually measured (Auto/Cycl/Myder for an eye clinic, blood
/// pressure/temperature for a general one, ...) isn't fixed here — see
/// [ExamFieldTemplate] and [VisitFieldValue] for the doctor-configurable
/// exam form this visit's readings are recorded against.
class Visit extends Equatable {
  const Visit({
    this.id,
    required this.patientId,
    required this.visitDate,
    this.notes,
    this.needsFollowUp = false,
    this.followUpBy,
    this.feeAmount,
    this.amountPaid,
    this.createdAt,
    this.visitType = VisitType.consultation,
    this.followUpOutcome,
    this.examSummary,
    this.currency = Currency.syp,
  });

  final int? id;
  final int patientId;
  final DateTime visitDate;
  final String? notes;

  /// The doctor's diagnostic conclusion for this visit's exam — e.g. "التهاب
  /// ملتحمة خفيف" — kept separate from [notes] (which is free-form and
  /// often written before the exam readings are final) so the chart has one
  /// clear place a later visit's doctor looks first.
  final String? examSummary;

  /// معاينة (full-price visit) vs مراجعة (a reduced/free recheck within
  /// the clinic's follow-up window). Defaults to [VisitType.consultation];
  /// the form suggests [VisitType.checkup] instead once this visit falls
  /// inside the follow-up-days window after the patient's last consultation,
  /// but the doctor can always override it — see [VisitType].
  final VisitType visitType;

  /// What happened since the last visit — free text like "الالتهاب راح" or
  /// "ما تحسّن، بحاجة لعملية". Recorded for either visit type.
  final String? followUpOutcome;

  /// The doctor's own judgment call at the time of this visit — "this
  /// patient needs to be checked on again" — independent of the clinic's
  /// automatic free/half-price follow-up windows (see AppointmentType),
  /// which are about billing, not clinical need. Backs the "متابعات
  /// مستحقة" list: a patient shows up there while this is their most
  /// recent visit and it's still flagged, and drops off automatically the
  /// moment they're seen again — no separate "resolved" step needed.
  final bool needsFollowUp;

  /// Optional target date the doctor has in mind for that follow-up — null
  /// means "needs to come back at some point" with no specific deadline.
  final DateTime? followUpBy;

  /// What the visit costs — entered by hand each time rather than derived
  /// from a price list, since fees vary clinic to clinic and case to case.
  /// Null means no fee was recorded for this visit (e.g. a free follow-up).
  final double? feeAmount;

  /// What was actually collected. Equal to [feeAmount] for the common
  /// "كشفية تُدفع قبل الدخول" case; only falls below it for the rare
  /// surgical case paid in installments, in which case [remainingAmount]
  /// surfaces the difference instead of the app tracking a running debt.
  final double? amountPaid;

  final DateTime? createdAt;

  /// The currency [feeAmount] and [amountPaid] are in.
  final Currency currency;

  /// Null when there's nothing owed to track — either no fee was recorded,
  /// or it was paid in full (the default the visit form assumes).
  double? get remainingAmount {
    if (feeAmount == null) return null;
    final remaining = feeAmount! - (amountPaid ?? feeAmount!);
    return remaining > 0 ? remaining : null;
  }

  Visit copyWith({
    int? id,
    int? patientId,
    DateTime? visitDate,
    String? notes,
    bool? needsFollowUp,
    DateTime? followUpBy,
    bool clearFollowUpBy = false,
    double? feeAmount,
    bool clearFeeAmount = false,
    double? amountPaid,
    bool clearAmountPaid = false,
    DateTime? createdAt,
    VisitType? visitType,
    String? followUpOutcome,
    bool clearFollowUpOutcome = false,
    String? examSummary,
    bool clearExamSummary = false,
    Currency? currency,
  }) {
    return Visit(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      visitDate: visitDate ?? this.visitDate,
      notes: notes ?? this.notes,
      needsFollowUp: needsFollowUp ?? this.needsFollowUp,
      followUpBy: clearFollowUpBy ? null : (followUpBy ?? this.followUpBy),
      feeAmount: clearFeeAmount ? null : (feeAmount ?? this.feeAmount),
      amountPaid: clearAmountPaid ? null : (amountPaid ?? this.amountPaid),
      createdAt: createdAt ?? this.createdAt,
      visitType: visitType ?? this.visitType,
      followUpOutcome: clearFollowUpOutcome
          ? null
          : (followUpOutcome ?? this.followUpOutcome),
      examSummary: clearExamSummary ? null : (examSummary ?? this.examSummary),
      currency: currency ?? this.currency,
    );
  }

  @override
  List<Object?> get props => [
    id,
    patientId,
    visitDate,
    notes,
    needsFollowUp,
    followUpBy,
    feeAmount,
    amountPaid,
    currency,
    visitType,
    followUpOutcome,
    examSummary,
  ];
}

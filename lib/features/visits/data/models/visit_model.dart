import '../../../../core/money/currency.dart';
import '../../domain/entities/visit.dart';
import '../../domain/entities/visit_type.dart';

class VisitModel extends Visit {
  const VisitModel({
    super.id,
    required super.patientId,
    required super.visitDate,
    super.notes,
    super.needsFollowUp,
    super.followUpBy,
    super.feeAmount,
    super.amountPaid,
    super.createdAt,
    super.visitType,
    super.followUpOutcome,
    super.examSummary,
    super.currency,
  });

  factory VisitModel.fromEntity(Visit v) => VisitModel(
    id: v.id,
    patientId: v.patientId,
    visitDate: v.visitDate,
    notes: v.notes,
    needsFollowUp: v.needsFollowUp,
    followUpBy: v.followUpBy,
    feeAmount: v.feeAmount,
    amountPaid: v.amountPaid,
    createdAt: v.createdAt,
    visitType: v.visitType,
    followUpOutcome: v.followUpOutcome,
    examSummary: v.examSummary,
    currency: v.currency,
  );

  factory VisitModel.fromMap(Map<String, Object?> map) => VisitModel(
    id: map['id'] as int?,
    patientId: map['patient_id']! as int,
    visitDate: DateTime.parse(map['visit_date']! as String),
    notes: map['notes'] as String?,
    needsFollowUp: (map['needs_follow_up'] as int?) == 1,
    followUpBy: map['follow_up_by'] == null
        ? null
        : DateTime.parse(map['follow_up_by']! as String),
    feeAmount: (map['fee_amount'] as num?)?.toDouble(),
    amountPaid: (map['amount_paid'] as num?)?.toDouble(),
    createdAt: map['created_at'] == null
        ? null
        : DateTime.parse(map['created_at']! as String),
    visitType: VisitType.values.firstWhere(
      (t) => t.name == map['visit_type'],
      orElse: () => VisitType.consultation,
    ),
    followUpOutcome: map['follow_up_outcome'] as String?,
    examSummary: map['exam_summary'] as String?,
    currency: Currency.fromCode(map['currency'] as String?),
  );

  Map<String, Object?> toMap() {
    final now = DateTime.now().toIso8601String();
    return {
      'patient_id': patientId,
      'visit_date': visitDate.toIso8601String().split('T').first,
      'notes': notes,
      'needs_follow_up': needsFollowUp ? 1 : 0,
      'follow_up_by': followUpBy?.toIso8601String().split('T').first,
      'fee_amount': feeAmount,
      'amount_paid': amountPaid,
      'created_at': createdAt?.toIso8601String() ?? now,
      'updated_at': now,
      'visit_type': visitType.name,
      'follow_up_outcome': followUpOutcome,
      'exam_summary': examSummary,
      'currency': currency.code,
    };
  }
}

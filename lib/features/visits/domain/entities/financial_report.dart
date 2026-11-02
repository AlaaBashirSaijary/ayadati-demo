import 'package:equatable/equatable.dart';

import '../../../../core/money/currency.dart';

/// One priced visit within a [FinancialReport]'s date range — a
/// denormalized join row (visit + the patient's name), same shape as
/// [FollowUpDue]: built directly in the datasource rather than through a
/// `fromMap` on the entity, so the domain layer stays persistence-agnostic.
class FinancialVisitRow extends Equatable {
  const FinancialVisitRow({
    required this.visitId,
    required this.patientId,
    required this.patientName,
    required this.visitDate,
    required this.feeAmount,
    required this.amountPaid,
    this.currency = Currency.syp,
  });

  final int visitId;
  final int patientId;
  final String patientName;
  final DateTime visitDate;
  final double feeAmount;
  final double amountPaid;
  final Currency currency;

  double get remaining {
    final diff = feeAmount - amountPaid;
    return diff > 0 ? diff : 0;
  }

  @override
  List<Object?> get props => [visitId, patientId, visitDate];
}

/// Real money totals for a date range — what "تقرير مالي حقيقي بمبالغ"
/// means in this app: actual fee/payment amounts entered per visit, not a
/// count of appointment types.
class FinancialReport extends Equatable {
  const FinancialReport({this.rows = const []});

  final List<FinancialVisitRow> rows;

  /// Fees, collected money and the unpaid rest — each kept per currency, so
  /// a dollar visit never gets added to a pound visit.
  MoneyTotals get fees => _sum((r) => r.feeAmount);

  MoneyTotals get collected => _sum((r) => r.amountPaid);

  MoneyTotals get remaining => _sum((r) => r.remaining);

  MoneyTotals _sum(double Function(FinancialVisitRow) pick) {
    final totals = MoneyTotals();
    for (final row in rows) {
      totals.add(row.currency, pick(row));
    }
    return totals;
  }

  int get pricedVisitCount => rows.length;

  @override
  List<Object?> get props => [rows];
}

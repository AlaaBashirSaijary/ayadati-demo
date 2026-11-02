import '../../../core/money/currency.dart';

/// One unpaid (or part-paid) visit.
class DebtVisit {
  const DebtVisit({
    required this.visitId,
    required this.visitDate,
    required this.fee,
    required this.paid,
    required this.currency,
  });

  final int visitId;
  final DateTime visitDate;
  final double fee;
  final double paid;
  final Currency currency;

  double get remaining => (fee - paid) > 0 ? fee - paid : 0;
}

/// What a patient still owes the clinic, split by currency.
class PatientDebt {
  PatientDebt({
    required this.patientId,
    required this.name,
    required this.phone,
    required this.visits,
  });

  final int patientId;
  final String name;
  final String? phone;

  /// Oldest first.
  final List<DebtVisit> visits;

  MoneyTotals get owed {
    final t = MoneyTotals();
    for (final v in visits) {
      t.add(v.currency, v.remaining);
    }
    return t;
  }

  DateTime get oldest => visits.first.visitDate;
}

/// One step of spreading a payment over visits.
class PaymentPart {
  const PaymentPart(this.visitId, this.amount);

  final int visitId;
  final double amount;
}

/// Spreads [amount] over [visits] (same currency, oldest first), settling the
/// oldest balance before the next. Anything above what's owed is not applied;
/// the caller should have capped [amount] at the total owed.
List<PaymentPart> allocatePayment(List<DebtVisit> visits, double amount) {
  final parts = <PaymentPart>[];
  var left = amount;
  for (final v in visits) {
    if (left <= 0) break;
    final remaining = v.remaining;
    if (remaining <= 0) continue;
    final apply = left < remaining ? left : remaining;
    parts.add(PaymentPart(v.visitId, apply));
    left -= apply;
  }
  return parts;
}

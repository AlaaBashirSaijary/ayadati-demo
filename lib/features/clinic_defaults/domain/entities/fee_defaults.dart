import 'package:equatable/equatable.dart';

import '../../../../core/money/currency.dart';

/// The clinic's usual fee for each kind of visit, set once so the visit form
/// can pre-fill "الكشفية" instead of the doctor retyping it every time.
/// Null means "no default" — the field just starts empty, as before.
class FeeDefaults extends Equatable {
  const FeeDefaults({
    this.consultationFee,
    this.checkupFee,
    this.currency = Currency.syp,
    this.usdRate,
  });

  /// معاينة — the full-price visit.
  final double? consultationFee;

  /// مراجعة — usually half-price or free.
  final double? checkupFee;

  /// The currency the fees above are in, and what a new visit starts with.
  final Currency currency;

  /// Syrian pounds per 1 US dollar — only used to show one combined total in
  /// reports; individual visits are never converted.
  final double? usdRate;

  @override
  List<Object?> get props => [consultationFee, checkupFee, currency, usdRate];
}

/// The two currencies a Syrian clinic actually handles day to day. Amounts
/// are never converted silently: each visit keeps the currency it was priced
/// in, and reports total each currency separately (with an optional combined
/// estimate when the clinic has set an exchange rate).
enum Currency {
  syp('SYP', 'ل.س'),
  usd('USD', r'$');

  const Currency(this.code, this.symbol);

  final String code;
  final String symbol;

  static Currency fromCode(String? code) =>
      Currency.values.firstWhere((c) => c.code == code, orElse: () => syp);

  /// "25,000 ل.س" / "$40" — thousands separated, no needless decimals.
  String format(num amount) {
    final negative = amount < 0;
    final abs = amount.abs();
    final whole = abs == abs.roundToDouble();
    final text = whole ? abs.toStringAsFixed(0) : abs.toStringAsFixed(2);
    final parts = text.split('.');
    final grouped = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    final number = parts.length > 1 ? '$grouped.${parts[1]}' : grouped;
    final signed = negative ? '-$number' : number;
    return this == usd ? '\$$signed' : '$signed $symbol';
  }
}

/// Sums amounts per currency, keeping the two apart.
class MoneyTotals {
  MoneyTotals() : _byCurrency = {};

  final Map<Currency, double> _byCurrency;

  void add(Currency currency, double amount) =>
      _byCurrency[currency] = (_byCurrency[currency] ?? 0) + amount;

  double of(Currency currency) => _byCurrency[currency] ?? 0;

  bool get isEmpty => _byCurrency.values.every((v) => v == 0);

  /// Currencies with a non-zero total, SYP first.
  List<Currency> get currencies => [
    for (final c in Currency.values)
      if (of(c) != 0) c,
  ];

  /// Everything expressed in [Currency.syp] using [usdRate] (SYP per 1 USD),
  /// or null when there's USD but no rate to convert it with.
  double? inSyp(double? usdRate) {
    final usd = of(Currency.usd);
    if (usd != 0 && (usdRate == null || usdRate <= 0)) return null;
    return of(Currency.syp) + usd * (usdRate ?? 0);
  }

  String describe() =>
      isEmpty ? '0' : currencies.map((c) => c.format(of(c))).join('  +  ');
}

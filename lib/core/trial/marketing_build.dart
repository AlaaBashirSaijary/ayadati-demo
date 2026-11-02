/// A demo build handed to a marketer: compiled with
/// `--dart-define=MARKETING_BUILD=true --dart-define=MARKETING_EXPIRY=yyyy-MM-dd`
/// (see tools/build_marketing.sh). It never activates, ends on a date fixed
/// at build time — not on first launch, so reinstalling doesn't restart it —
/// hides backup and patient import so real clinic data can't be moved in or
/// out, and shows a permanent "demo" ribbon. The normal build is unaffected:
/// without the flag every getter here is inert.
class MarketingBuild {
  MarketingBuild._();

  // Always on in this repository: it only ever produces the demo build.
  static const enabled = true;
  static const _expiryRaw = String.fromEnvironment('MARKETING_EXPIRY');
  static const holder = String.fromEnvironment('MARKETING_HOLDER');

  /// End of the last valid day. A missing or unreadable date leaves the build
  /// already expired, so a mistyped define fails closed instead of open.
  static DateTime get expiry {
    final parsed = DateTime.tryParse(_expiryRaw);
    if (parsed == null) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime(parsed.year, parsed.month, parsed.day, 23, 59, 59);
  }

  static String get ribbonText => holder.isEmpty ? 'نسخة عرض' : 'عرض · $holder';
}

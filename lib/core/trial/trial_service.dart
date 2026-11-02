import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'marketing_build.dart';

/// A 14-day, fully-featured evaluation period, gated entirely offline —
/// there's no licensing server, so both the device code and the activation
/// code that unlocks it are computed locally. The pairing between the two
/// is a shared secret baked into this app and into the vendor-only
/// generator tool (kept outside the app itself, never shipped in the APK,
/// so a doctor evaluating the trial has no way to reach it): given a
/// device code, only that tool can produce the matching activation code.
///
/// This is deliberately a soft gate, not DRM — it matches the "بيع مباشر +
/// دعم شخصي" model (see the roadmap study): the goal is a real hands-on
/// trial instead of relying on personal trust alone, not stopping a
/// determined bypass.
class TrialService {
  TrialService._();

  static final TrialService instance = TrialService._();

  static const trialLength = Duration(days: 14);

  /// Must match the generator tool exactly — changing this invalidates
  /// every activation code already handed out.
  static const _salt = 'DEMO-BUILD-NOT-A-LICENCE-SECRET';

  static const _deviceCodeKey = 'clinic_manager.trial.device_code';
  static const _firstLaunchKey = 'clinic_manager.trial.first_launch_millis';
  static const _activatedKey = 'clinic_manager.trial.activated';
  static const _lastSeenKey = 'clinic_manager.trial.last_seen_millis';

  /// This install's device code — generated once on first launch and
  /// persisted, formatted as "XXXX-XXXX" so it's short enough to read out
  /// over a phone call or a WhatsApp message.
  Future<String> deviceCode() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceCodeKey);
    if (existing != null) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(4, (_) => random.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final code = '${hex.substring(0, 4)}-${hex.substring(4, 8)}'.toUpperCase();

    await prefs.setString(_deviceCodeKey, code);
    // The trial clock starts the moment a device code first exists, not
    // whenever this method is next called — see isTrialExpired().
    await prefs.setInt(_firstLaunchKey, DateTime.now().millisecondsSinceEpoch);
    return code;
  }

  /// The one code that unlocks [deviceCode] permanently — same formula the
  /// vendor's own generator tool runs, so entering it here is just
  /// re-deriving and comparing, no network call involved.
  static String activationCodeFor(String deviceCode) {
    final digest = sha256.convert(utf8.encode('$deviceCode|$_salt'));
    final hex = digest.toString().toUpperCase();
    return '${hex.substring(0, 5)}-${hex.substring(5, 10)}';
  }

  Future<bool> isActivated() async {
    if (MarketingBuild.enabled) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_activatedKey) ?? false;
  }

  /// Compares [enteredCode] against the code this device's own [deviceCode]
  /// should produce — accepts a little formatting sloppiness (spaces,
  /// missing dash, lowercase) since it'll usually be typed by hand from a
  /// WhatsApp message.
  Future<bool> activate(String enteredCode) async {
    if (MarketingBuild.enabled) return false;
    final code = await deviceCode();
    final expected = activationCodeFor(code);
    if (_normalize(enteredCode) != _normalize(expected)) return false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_activatedKey, true);
    return true;
  }

  /// Null once activated — the trial clock stops mattering entirely rather
  /// than just reading as "0 days left" forever.
  Future<int?> daysRemaining() async {
    if (MarketingBuild.enabled) return _marketingDaysRemaining();
    if (await isActivated()) return null;

    final prefs = await SharedPreferences.getInstance();
    // Ensures a device code (and therefore a first-launch timestamp)
    // exists even if this is called before deviceCode() ever was.
    await deviceCode();
    final firstLaunchMillis = prefs.getInt(_firstLaunchKey)!;
    final elapsed = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(firstLaunchMillis),
    );
    final remaining = trialLength - elapsed;
    return remaining.isNegative ? 0 : remaining.inDays + 1;
  }

  /// Days left until the build's fixed end date. The latest time ever seen is
  /// remembered, so winding the device clock back doesn't buy more days.
  Future<int> _marketingDaysRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    final lastSeen = prefs.getInt(_lastSeenKey) ?? 0;
    final effective = max(nowMillis, lastSeen);
    if (effective > lastSeen) await prefs.setInt(_lastSeenKey, effective);

    final remaining = MarketingBuild.expiry.difference(
      DateTime.fromMillisecondsSinceEpoch(effective),
    );
    return remaining.isNegative ? 0 : remaining.inDays + 1;
  }

  Future<bool> isTrialExpired() async {
    final remaining = await daysRemaining();
    return remaining == 0;
  }

  String _normalize(String s) =>
      s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}

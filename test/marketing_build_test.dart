import 'package:clinic_manager_flutter/core/trial/marketing_build.dart';
import 'package:clinic_manager_flutter/core/trial/trial_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Compile-time flags, so run with:
//   flutter test test/marketing_build_test.dart \
//     --dart-define=MARKETING_BUILD=true --dart-define=MARKETING_EXPIRY=2099-01-01
// A plain `flutter test` skips these (the normal build is the other branch).
void main() {
  final skip = const String.fromEnvironment('MARKETING_EXPIRY').isEmpty
      ? 'needs MARKETING_EXPIRY define'
      : null;

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('never activates, even with the correct code', () async {
    final code = await TrialService.instance.deviceCode();
    final ok = await TrialService.instance.activate(
      TrialService.activationCodeFor(code),
    );
    expect(ok, isFalse);
    expect(await TrialService.instance.isActivated(), isFalse);
  }, skip: skip);

  test(
    'days left follow the fixed end date, and a rolled-back clock cannot add '
    'days',
    () async {
      final days = await TrialService.instance.daysRemaining();
      final expected =
          MarketingBuild.expiry.difference(DateTime.now()).inDays + 1;
      expect(days, expected.clamp(0, 100000));

      // Pretend the device already ran past the end date, then "rewind" it.
      SharedPreferences.setMockInitialValues({
        'clinic_manager.trial.last_seen_millis':
            MarketingBuild.expiry.millisecondsSinceEpoch + 86400000,
      });
      expect(await TrialService.instance.daysRemaining(), 0);
      expect(await TrialService.instance.isTrialExpired(), isTrue);
    },
    skip: skip,
  );
}

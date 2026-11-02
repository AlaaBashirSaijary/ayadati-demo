import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:clinic_manager_flutter/core/di/injection.dart';
import 'package:clinic_manager_flutter/main.dart';

void main() {
  setUpAll(() {
    // `flutter test` runs in a headless Dart VM with no native iOS/Android
    // platform channel, so sqflite needs the FFI engine here instead of the
    // real plugin the app uses on-device, and shared_preferences needs its
    // values mocked instead of hitting a native channel that never replies.
    sqfliteFfiInit();
    // The isolate-backed factory (databaseFactoryFfi) spawns a worker
    // isolate whose completion signals don't interleave properly with
    // TestWidgetsFlutterBinding's test zone, which left the app stuck
    // showing its loading spinner forever under `testWidgets` specifically
    // (a bare `test()`/ProviderContainer body doesn't hit this).
    databaseFactory = databaseFactoryFfiNoIsolate;
    SharedPreferences.setMockInitialValues({});
    setupDependencyInjection();
  });

  testWidgets('App boots to the onboarding screen on first launch', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ClinicManagerApp()));

    // Not pumpAndSettle(): AppLockGate/AuthGate show an indeterminate
    // CircularProgressIndicator while auth + app-lock state resolve, and
    // that widget's animation never finishes on its own, so pumpAndSettle
    // would time out waiting for it. tester.pump(duration) also isn't
    // enough on its own — it advances a *fake* clock without yielding real
    // wall-clock time, and sqflite's FFI engine does genuine (if fast) disk
    // I/O. Use runAsync to step outside the fake zone and really wait for
    // it. How long that takes varies a lot (from under 100ms to several
    // seconds) depending on machine load, so poll in short real-time
    // slices and bail out early once onboarding actually appears, instead
    // of gambling on one fixed delay being long enough.
    final onboardingText = find.text('إعداد العيادة لأول مرة');
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      if (onboardingText.evaluate().isNotEmpty) break;
    }

    // No clinic/admin exists yet, so the app should route to onboarding
    // instead of the login screen — see AuthGate in lib/main.dart.
    expect(onboardingText, findsOneWidget);
  });
}

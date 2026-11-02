// A scripted walk-through of the real app, meant to be screen-recorded:
//
//   xcrun simctl uninstall <udid> com.example.clinicManagerFlutter   # clean slate
//   xcrun simctl io <udid> recordVideo demo.mp4 &
//   flutter test integration_test/demo_test.dart -d <udid>
//
// It drives the UI through finders (no keyboard needed) with short pauses
// between steps so the recording is watchable. Re-run it after any UI change
// to refresh the video.
import 'package:clinic_manager_flutter/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Future<void> settle(WidgetTester t, {int seconds = 1}) async {
  try {
    await t.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 8),
    );
  } catch (_) {}
  await t.pump(Duration(seconds: seconds));
}

/// Long forms build their fields lazily, so scroll until the target exists.
Future<void> reveal(WidgetTester t, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await t.scrollUntilVisible(
      finder,
      250,
      scrollable: find
          .descendant(
            of: find.byType(Scaffold).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
}

Future<void> tapText(WidgetTester t, String text, {int seconds = 1}) async {
  final finder = find.text(text).first;
  await reveal(t, find.text(text));
  await t.ensureVisible(finder);
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(finder);
  await settle(t, seconds: seconds);
}

Future<void> fill(WidgetTester t, String label, String value) async {
  await reveal(t, find.widgetWithText(TextField, label));
  final finder = find.widgetWithText(TextField, label).first;
  await t.ensureVisible(finder);
  await t.enterText(finder, value);
  await t.pump(const Duration(milliseconds: 400));
}

/// Prints a marker the host-side watcher turns into a simulator screenshot
/// (xcrun simctl io UDID screenshot), then waits so the frame is stable.
Future<void> shot(WidgetTester t, String name) async {
  await settle(t, seconds: 1);
  // ignore: avoid_print
  print('SHOT:$name');
  await t.pump(const Duration(seconds: 3));
}

/// The AppBar back arrow isn't a platform back button here, so pop the
/// route directly.
Future<void> back(WidgetTester t, {int seconds = 1}) async {
  await t.state<NavigatorState>(find.byType(Navigator).first).maybePop();
  await settle(t, seconds: seconds);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('عيادتي — جولة كاملة', (tester) async {
    app.main();
    await settle(tester, seconds: 3);

    // 1) First run: create the clinic.
    await fill(tester, 'اسم العيادة', 'عيادة الشفاء للعيون');
    await fill(tester, 'اسمك', 'د. ليلى حداد');
    await fill(tester, 'البريد الإلكتروني', 'laila@example.com');
    await fill(tester, 'كلمة المرور', 'Clinic#2026');
    await fill(tester, 'تأكيد كلمة المرور', 'Clinic#2026');
    await shot(tester, '01-clinic-setup');
    await settle(tester, seconds: 2);
    await tapText(tester, 'إنشاء الحساب والدخول', seconds: 3);
    await tester.tap(find.byType(CheckboxListTile));
    await settle(tester);
    await tapText(tester, 'متابعة', seconds: 3);

    // 2) Set the clinic's default fees once.
    await tapText(tester, 'الإدارة', seconds: 2);
    await tapText(tester, 'الأسعار والعبارات السريعة', seconds: 2);
    await fill(tester, 'معاينة (كشفية كاملة)', '20000');
    await fill(tester, 'مراجعة (نصف السعر أو مجانية)', '10000');
    await shot(tester, '02-default-fees');
    await settle(tester, seconds: 1);
    await tapText(tester, 'حفظ الأسعار', seconds: 2);
    await back(tester);
    await tapText(tester, 'المرضى', seconds: 1);

    // 3) Register a patient.
    for (final name in ['سارة منصور', 'أحمد خالد']) {
      await tapText(tester, 'إضافة', seconds: 2);
      await fill(tester, 'اسم المريض الكامل', name);
      await fill(tester, 'رقم الهاتف (اختياري)', '0944123456');
      await tapText(tester, 'معلومات إضافية (اختياري)', seconds: 1);
      await fill(tester, 'العمر (اختياري)', '34');
      await fill(tester, 'الشكاية (ماذا يعاني؟)', 'احمرار وألم بالعين اليمنى');
      await shot(tester, '03-new-patient');
      await settle(tester, seconds: 1);
      await tapText(tester, 'حفظ الإضبارة', seconds: 2);
      await tapText(tester, 'لاحقًا', seconds: 2);
    }

    // 4) First visit: type and fee fill in by themselves.
    await tapText(tester, 'سارة منصور', seconds: 2);
    await tapText(tester, 'زيارة جديدة', seconds: 3);
    await fill(tester, 'خلاصة الفحص', 'التهاب ملتحمة خفيف');
    await shot(tester, '04-first-visit');
    await settle(tester, seconds: 2);
    await tapText(tester, 'حفظ الزيارة', seconds: 3);

    // 5) Follow-up visit inside the window: reduced fee, outcome note.
    await tapText(tester, 'زيارة جديدة', seconds: 3);
    await fill(tester, 'نتيجة المتابعة', 'الالتهاب راح، تحسنت الرؤية');
    await fill(tester, 'خلاصة الفحص', 'شفاء كامل');
    await shot(tester, '05-followup-visit');
    await settle(tester, seconds: 2);
    await tapText(tester, 'حفظ الزيارة', seconds: 4);
    await shot(tester, '06-patient-file');
    await back(tester, seconds: 2);

    // 6) Appointments.
    await tapText(tester, 'المواعيد', seconds: 2);
    await tapText(tester, 'موعد جديد', seconds: 2);
    await tester.enterText(find.byType(TextField).first, 'أحمد');
    await settle(tester, seconds: 2);
    await tapText(tester, 'أحمد خالد', seconds: 2);
    await shot(tester, '07-new-appointment');
    await tapText(tester, 'حجز الموعد', seconds: 3);
    await shot(tester, '08-appointments');

    // 7) Booking link + QR.
    await tapText(tester, 'الإدارة', seconds: 2);
    await shot(tester, '09-admin-hub');
    await tapText(tester, 'رابط الحجز عبر واتساب', seconds: 2);
    await fill(tester, 'رقم واتساب العيادة', '0944123456');
    await settle(tester, seconds: 4);
    await shot(tester, '10-booking-link-qr');
    await back(tester, seconds: 3);
  });
}

import 'package:clinic_manager_flutter/core/error/error_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('duplicate patient number becomes a clear instruction', () {
    final msg = friendlyMessage(
      'تعذّر حفظ إضبارة المريض',
      'DatabaseException(UNIQUE constraint failed: patients.patient_number)',
    );
    expect(msg, contains('رقم المريض هذا مستخدم'));
    expect(msg, isNot(contains('UNIQUE')));
  });

  test('missing column asks for a full restart', () {
    final msg = friendlyMessage('x', 'table visits has no column named foo');
    expect(msg, contains('أغلق التطبيق'));
  });

  test('unknown errors never leak raw text', () {
    final msg = friendlyMessage('تعذّر الحفظ', 'weird internal thing 0xDEAD');
    expect(msg, startsWith('تعذّر الحفظ'));
    expect(msg, isNot(contains('0xDEAD')));
  });
}

import 'package:clinic_manager_flutter/features/appointments/domain/services/booking_request_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A Thursday.
  final now = DateTime(2026, 10, 1, 9);

  test('reads the structured booking-link format exactly', () {
    final r = BookingRequestParser.parse(
      'طلب حجز موعد\nالاسم: أحمد خالد\nالهاتف: 0944 123 456\n'
      'اليوم: السبت\nالوقت: الساعة 5 مساءً\nالسبب: ألم بالعين',
      now: now,
    );
    expect(r.name, 'أحمد خالد');
    expect(r.phone, '0944123456');
    expect(r.day, DateTime(2026, 10, 3));
    expect(r.time, (hour: 17, minute: 0));
    expect(r.reason, 'ألم بالعين');
  });

  test('understands Syrian-dialect free text', () {
    final r = BookingRequestParser.parse(
      'مرحبا دكتور بدي موعد بكرا الساعة ٥ ونص رقمي ٠٩٣٣٢٢١١٣٣',
      now: now,
    );
    expect(r.day, DateTime(2026, 10, 2));
    expect(r.phone, '0933221133');
    expect(r.time?.hour, 17);
  });

  test('"after tomorrow" wins over "tomorrow"', () {
    final r = BookingRequestParser.parse('بدي موعد بعد بكرا صباحا', now: now);
    expect(r.day, DateTime(2026, 10, 3));
    expect(r.period, 'morning');
    expect(r.time, (hour: 10, minute: 0));
  });

  test('numeric date and international phone', () {
    final r = BookingRequestParser.parse(
      'موعد 15/10 رقمي +963 955 111 222',
      now: now,
    );
    expect(r.day, DateTime(2026, 10, 15));
    expect(r.phone, '0955111222');
  });

  test('unrelated text yields an empty request', () {
    expect(BookingRequestParser.parse('شكرا دكتور', now: now).isEmpty, isTrue);
  });

  test('reads exactly what docs/book.html sends', () {
    // Copied from the message built in docs/book.html's submit handler.
    final r = BookingRequestParser.parse(
      'طلب حجز موعد\nالاسم: فاطمة علي\nالهاتف: 0944 123 456\n'
      'اليوم: الأحد 4/10\nالوقت: الساعة 5:00 مساءً\nالسبب: ألم بالعين',
      now: DateTime(2026, 10, 3, 9),
    );
    expect(r.name, 'فاطمة علي');
    expect(r.phone, '0944123456');
    expect(r.day, DateTime(2026, 10, 4));
    expect(r.time, (hour: 17, minute: 0));
    expect(r.reason, 'ألم بالعين');
  });
}

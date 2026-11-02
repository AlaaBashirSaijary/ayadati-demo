import 'package:clinic_manager_flutter/core/whatsapp/whatsapp_service.dart';
import 'package:clinic_manager_flutter/features/appointments/domain/entities/appointment.dart';
import 'package:clinic_manager_flutter/features/appointments/presentation/util/appointment_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes Syrian numbers for wa.me', () {
    expect(WhatsAppService.normalize('0944 123 456'), '963944123456');
    expect(WhatsAppService.normalize('+963944123456'), '963944123456');
    expect(WhatsAppService.normalize('00963944123456'), '963944123456');
    expect(WhatsAppService.normalize('٠٩٤٤١٢٣٤٥٦'), '963944123456');
    expect(WhatsAppService.normalize(''), isNull);
    expect(WhatsAppService.normalize(null), isNull);
  });

  test('reminder message names the day, time and clinic', () {
    final now = DateTime(2026, 10, 1, 9);
    final appt = Appointment(
      patientId: 1,
      scheduledAt: DateTime(2026, 10, 2, 17, 30),
      patientName: 'أحمد',
    );
    final text = AppointmentMessages.build(
      kind: AppointmentMessageKind.reminder,
      appointment: appt,
      clinicName: 'عيادة الشفاء',
      now: now,
    );
    expect(text, contains('مرحبًا أحمد'));
    expect(text, contains('غدًا'));
    expect(text, contains('5:30 مساءً'));
    expect(text, contains('عيادة الشفاء'));
  });
}

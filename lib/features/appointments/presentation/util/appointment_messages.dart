import '../../domain/entities/appointment.dart';

enum AppointmentMessageKind {
  confirmation,
  reminder,
  reschedule;

  String get label => switch (this) {
    AppointmentMessageKind.confirmation => 'تأكيد الموعد',
    AppointmentMessageKind.reminder => 'تذكير بالموعد',
    AppointmentMessageKind.reschedule => 'طلب تغيير الموعد',
  };
}

/// Ready-to-send WhatsApp wording for an appointment — short and polite, in
/// plain Arabic, with the clinic name so the patient knows who's writing.
class AppointmentMessages {
  const AppointmentMessages._();

  static const _weekdays = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  static const _months = [
    'كانون الثاني',
    'شباط',
    'آذار',
    'نيسان',
    'أيار',
    'حزيران',
    'تموز',
    'آب',
    'أيلول',
    'تشرين الأول',
    'تشرين الثاني',
    'كانون الأول',
  ];

  static String dayLabel(DateTime at, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final d = DateTime(at.year, at.month, at.day);
    final t = DateTime(today.year, today.month, today.day);
    final diff = d.difference(t).inDays;
    final base =
        '${_weekdays[at.weekday - 1]} ${at.day} ${_months[at.month - 1]}';
    if (diff == 0) return 'اليوم ($base)';
    if (diff == 1) return 'غدًا ($base)';
    return base;
  }

  static String timeLabel(DateTime at) {
    final hour12 = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final minutes = at.minute.toString().padLeft(2, '0');
    final period = at.hour < 12 ? 'صباحًا' : 'مساءً';
    return '$hour12:$minutes $period';
  }

  static String build({
    required AppointmentMessageKind kind,
    required Appointment appointment,
    required String clinicName,
    DateTime? now,
  }) {
    final name = appointment.patientName?.trim();
    final greeting = name == null || name.isEmpty ? 'مرحبًا' : 'مرحبًا $name';
    final day = dayLabel(appointment.scheduledAt, now: now);
    final time = timeLabel(appointment.scheduledAt);
    final clinic = clinicName.trim().isEmpty ? 'العيادة' : clinicName.trim();

    return switch (kind) {
      AppointmentMessageKind.confirmation =>
        '$greeting،\nتم تأكيد موعدك في $clinic:\n'
            '📅 $day\n🕒 الساعة $time\n'
            'نرجو الحضور قبل الموعد بقليل. شكرًا لك.',
      AppointmentMessageKind.reminder =>
        '$greeting،\nتذكير بموعدك في $clinic:\n'
            '📅 $day\n🕒 الساعة $time\n'
            'يرجى الرد بـ "تم" لتأكيد الحضور.',
      AppointmentMessageKind.reschedule =>
        '$greeting،\nنعتذر، نحتاج لتغيير موعدك في $clinic '
            '(الحالي: $day الساعة $time).\n'
            'ما هو الوقت الأنسب لك؟',
    };
  }
}

/// Why a patient is on the recall list.
enum RecallKind {
  overdueFollowUp('متابعات مستحقة'),
  lapsed3('انقطعوا ٣ أشهر'),
  lapsed6('انقطعوا ٦ أشهر'),
  lapsed12('انقطعوا سنة');

  const RecallKind(this.label);

  final String label;

  /// Months without a visit for the "lapsed" kinds.
  int? get months => switch (this) {
    RecallKind.lapsed3 => 3,
    RecallKind.lapsed6 => 6,
    RecallKind.lapsed12 => 12,
    _ => null,
  };

  String get defaultMessage => this == RecallKind.overdueFollowUp
      ? 'مرحبًا {name}، نذكّركم بموعد المتابعة في {clinic}. يسعدنا استقبالكم، '
            'تواصلوا معنا لتحديد موعد مناسب.'
      : 'مرحبًا {name}، مرّ وقت منذ آخر زيارة لكم في {clinic}. نطمئن عليكم، '
            'وإن رغبتم بفحص دوري يسعدنا حجز موعد لكم.';
}

class RecallCandidate {
  const RecallCandidate({
    required this.patientId,
    required this.name,
    required this.phone,
    required this.lastVisit,
    this.followUpBy,
  });

  final int patientId;
  final String name;
  final String? phone;
  final DateTime lastVisit;
  final DateTime? followUpBy;
}

/// Fills {name} and {clinic} in a recall template.
String fillRecallTemplate(
  String template, {
  required String name,
  required String clinic,
}) => template.replaceAll('{name}', name).replaceAll('{clinic}', clinic);

/// True when a recall message was already sent less than [days] days ago, so
/// the same patient isn't pestered twice in a short while.
bool isCoolingDown(DateTime? lastSent, DateTime now, {int days = 14}) =>
    lastSent != null && now.difference(lastSent).inDays < days;

/// Prompt builders for the patient-level AI helpers. They take only the
/// clinical facts and never the patient's name, phone or address, so nothing
/// identifying leaves the device. Each prompt tells the model to stick to
/// what it was given and not to diagnose or prescribe: the result is always a
/// draft the doctor reads and edits.
class VisitBrief {
  const VisitBrief({
    required this.date,
    required this.type,
    this.summary,
    this.notes,
    this.outcome,
  });

  final String date;
  final String type;
  final String? summary;
  final String? notes;
  final String? outcome;

  String describe() {
    final parts = [
      'التاريخ $date',
      'النوع $type',
      if (_has(summary)) 'الخلاصة: ${summary!.trim()}',
      if (_has(notes)) 'ملاحظات: ${notes!.trim()}',
      if (_has(outcome)) 'نتيجة المتابعة: ${outcome!.trim()}',
    ];
    return parts.join(' — ');
  }
}

bool _has(String? s) => s != null && s.trim().isNotEmpty;

String _line(String label, String? value) =>
    _has(value) ? '$label: ${value!.trim()}\n' : '';

String _visitLines(List<VisitBrief> visits) => visits.isEmpty
    ? 'لا توجد زيارات سابقة مسجلة.\n'
    : '${[for (final v in visits) '- ${v.describe()}'].join('\n')}\n';

String patientBriefPrompt({
  int? age,
  String? gender,
  String? allergies,
  String? history,
  String? currentMedications,
  String? complaint,
  required List<VisitBrief> lastVisits,
}) =>
    'أنت مساعد لطبيب في عيادة. لخّص بالعربية في خمسة أسطر كحد أقصى، بنقاط '
    'قصيرة، ما يجب أن يعرفه الطبيب عن هذا المريض قبل دخوله، اعتمادًا فقط على '
    'المعلومات التالية. لا تضف أي معلومة غير مذكورة، ولا تشخّص ولا توصِ '
    'بعلاج. ابدأ بالأهم (الحساسية والأدوية إن وُجدت). إن كانت المعلومات '
    'قليلة فقل ذلك باختصار.\n\n'
    '${age == null ? '' : 'العمر: $age سنة\n'}'
    '${_line('الجنس', gender)}'
    '${_line('الشكاية المسجلة', complaint)}'
    '${_line('الحساسية', allergies)}'
    '${_line('التاريخ المرضي', history)}'
    '${_line('الأدوية الحالية', currentMedications)}'
    'آخر الزيارات:\n${_visitLines(lastVisits)}';

class RxLine {
  const RxLine({
    required this.drug,
    this.dosage,
    this.frequency,
    this.duration,
    this.notes,
  });

  final String drug;
  final String? dosage;
  final String? frequency;
  final String? duration;
  final String? notes;

  String describe() {
    final parts = [
      drug,
      if (_has(dosage)) 'الجرعة ${dosage!.trim()}',
      if (_has(frequency)) 'المرات ${frequency!.trim()}',
      if (_has(duration)) 'المدة ${duration!.trim()}',
      if (_has(notes)) 'ملاحظة ${notes!.trim()}',
    ];
    return parts.join(' — ');
  }
}

String patientInstructionsPrompt({
  required List<RxLine> items,
  String? prescriptionNotes,
  int? age,
}) =>
    'اكتب للمريض تعليمات استخدام أدويته بالعربية البسيطة المفهومة لعامة '
    'الناس (لهجة بيضاء قريبة من السورية دون تعقيد). لكل دواء سطر أو '
    'سطران: لماذا وكيف ومتى يأخذه، ثم ٢ إلى ٣ نصائح عامة آمنة، ثم جملة '
    'تطلب مراجعة الطبيب عند ظهور أعراض مقلقة. التزم حرفيًا بالجرعات '
    'والمدد المكتوبة ولا تغيّرها، ولا تضف أدوية أو معلومات غير مؤكدة، '
    'وإن كان بيان ناقصًا فلا تخمّنه. اجعل النص مناسبًا للإرسال في رسالة '
    'واتساب (نقاط قصيرة وبلا عناوين طويلة).\n\n'
    '${age == null ? '' : 'عمر المريض: $age سنة\n'}'
    'الأدوية:\n${[for (final i in items) '- ${i.describe()}'].join('\n')}\n'
    '${_line('ملاحظات الوصفة', prescriptionNotes)}';

String referralPrompt({
  int? age,
  String? gender,
  String? allergies,
  String? currentMedications,
  String? doctorNote,
  String? target,
  required List<VisitBrief> lastVisits,
}) =>
    'أنت مساعد كتابة لطبيب سوري. اكتب رسالة تحويل رسمية مختصرة بالعربية '
    'الفصحى (فقرة أو فقرتان) من الطبيب المعالج إلى '
    '${_has(target) ? 'الزميل ($target)' : 'الزميل المختص'}، تلخّص حالة '
    'المريض وسبب التحويل والمطلوب، اعتمادًا فقط على المعلومات التالية. '
    'ابدأ بـ"الزميل الفاضل"، ولا تذكر اسم المريض (يُضاف في الترويسة)، ولا '
    'تضف تشخيصًا أو نتائج غير مذكورة، واختم بالشكر دون توقيع.\n\n'
    '${age == null ? '' : 'العمر: $age سنة\n'}'
    '${_line('الجنس', gender)}'
    '${_line('الحساسية', allergies)}'
    '${_line('الأدوية الحالية', currentMedications)}'
    '${_line('ملاحظة الطبيب (سبب التحويل)', doctorNote)}'
    'آخر الزيارات:\n${_visitLines(lastVisits)}';

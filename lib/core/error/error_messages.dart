/// Turns a low-level exception (almost always a sqflite DatabaseException)
/// into a sentence a clinic user can act on, instead of leaking SQL text
/// like "UNIQUE constraint failed: patients.patient_number" into the UI.
/// [action] is the short failed-operation phrase, e.g. "تعذّر حفظ إضبارة
/// المريض" — only used as the lead-in for errors with no friendlier cause.
String friendlyMessage(String action, Object error) {
  final text = error.toString();
  final lower = text.toLowerCase();

  if (lower.contains('unique constraint failed')) {
    if (lower.contains('patients.patient_number')) {
      return 'رقم المريض هذا مستخدم لمريض آخر. اختر رقمًا مختلفًا أو اترك الحقل فارغًا ليُولَّد تلقائيًا.';
    }
    if (lower.contains('users.email')) {
      return 'هذا البريد الإلكتروني مسجَّل مسبقًا.';
    }
    return 'هذه البيانات موجودة مسبقًا ولا يمكن تكرارها.';
  }
  if (lower.contains('foreign key constraint failed')) {
    return 'لا يمكن إتمام العملية لأن السجل مرتبط ببيانات أخرى.';
  }
  if (lower.contains('no such table') ||
      lower.contains('no column named') ||
      lower.contains('has no column')) {
    return 'قاعدة البيانات تحتاج تحديثًا. أغلق التطبيق بالكامل ثم افتحه من جديد.';
  }
  if (lower.contains('database is locked') ||
      lower.contains('database_closed')) {
    return 'قاعدة البيانات مشغولة حاليًا. انتظر لحظات ثم حاول مرة أخرى.';
  }
  if (lower.contains('disk full') ||
      lower.contains('sqlite_full') ||
      lower.contains('code=13')) {
    return 'مساحة التخزين على الجهاز ممتلئة. احذف ملفات غير ضرورية ثم حاول مجددًا.';
  }
  if (lower.contains('readonly') || lower.contains('read-only')) {
    return 'تعذّرت الكتابة في مكان التخزين الحالي. تحقق من صلاحيات المجلد أو من توصيل القرص الخارجي.';
  }
  if (lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('timeoutexception')) {
    return 'تعذّر الاتصال بالإنترنت. تحقق من الشبكة وحاول مرة أخرى.';
  }
  return '$action. حاول مرة أخرى، وإن تكرّر الأمر تواصل مع الدعم.';
}

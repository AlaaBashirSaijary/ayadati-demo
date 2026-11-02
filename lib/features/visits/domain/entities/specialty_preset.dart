import 'exam_field_template.dart';

/// One exam-form row inside a [SpecialtyPreset].
class PresetField {
  const PresetField(this.label, {this.sides = false, this.long = false});

  final String label;

  /// Recorded separately for right and left (eyes, ears, joints…).
  final bool sides;

  /// A descriptive finding, so its input is a multi-line box.
  final bool long;
}

/// A ready-made exam form for one specialty. Applying it fills the clinic's
/// `exam_field_templates`, which the doctor can still edit freely afterwards.
class SpecialtyPreset {
  const SpecialtyPreset({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.summary,
    required this.fields,
  });

  final String id;
  final String name;

  /// Resolved to an icon in the presentation layer (keeps this file pure Dart).
  final String iconKey;
  final String summary;
  final List<PresetField> fields;

  /// The fields that aren't already on the clinic's form (matched by label,
  /// ignoring case and surrounding spaces), so adding a preset never creates
  /// duplicates.
  List<PresetField> missingFrom(List<ExamFieldTemplate> existing) {
    final have = existing.map((t) => t.label.trim().toLowerCase()).toSet();
    return fields
        .where((f) => !have.contains(f.label.trim().toLowerCase()))
        .toList();
  }
}

const specialtyPresets = <SpecialtyPreset>[
  SpecialtyPreset(
    id: 'eyes',
    name: 'طب العيون',
    iconKey: 'eye',
    summary: 'انكسار وقاع العين وضغط العين',
    fields: [
      PresetField('Auto', sides: true),
      PresetField('Cycl/Myder', sides: true),
      PresetField('Old. Glass', sides: true),
      PresetField('Pers.Refract', sides: true),
      PresetField('Near', sides: true),
      PresetField('IOP', sides: true),
      PresetField('Anter.S', sides: true, long: true),
      PresetField('Lens', sides: true, long: true),
      PresetField('Poster.S', sides: true, long: true),
    ],
  ),
  SpecialtyPreset(
    id: 'dental',
    name: 'طب الأسنان',
    iconKey: 'dental',
    summary: 'السن المصاب والتشخيص والإجراء وخطة العلاج',
    fields: [
      PresetField('السن المصاب'),
      PresetField('التشخيص السني', long: true),
      PresetField('حالة اللثة', long: true),
      PresetField('التسوس', long: true),
      PresetField('الأشعة السنية', long: true),
      PresetField('الإجراء المنفّذ', long: true),
      PresetField('نوع التخدير'),
      PresetField('خطة العلاج', long: true),
    ],
  ),
  SpecialtyPreset(
    id: 'pediatrics',
    name: 'طب الأطفال',
    iconKey: 'child',
    summary: 'نمو وقياسات وتلقيحات وفحص الصدر والبطن',
    fields: [
      PresetField('الوزن (كغ)'),
      PresetField('الطول (سم)'),
      PresetField('محيط الرأس (سم)'),
      PresetField('الحرارة'),
      PresetField('النبض'),
      PresetField('معدل التنفس'),
      PresetField('الأذنان', sides: true, long: true),
      PresetField('الحلق واللوزتان', long: true),
      PresetField('فحص الصدر', long: true),
      PresetField('فحص البطن', long: true),
      PresetField('النمو والتطور', long: true),
      PresetField('التلقيحات', long: true),
      PresetField('التغذية', long: true),
    ],
  ),
  SpecialtyPreset(
    id: 'obgyn',
    name: 'النسائية والتوليد',
    iconKey: 'pregnant',
    summary: 'متابعة الحمل والسونار والفحص النسائي',
    fields: [
      PresetField('ضغط الدم'),
      PresetField('الوزن (كغ)'),
      PresetField('تاريخ آخر دورة (LMP)'),
      PresetField('تاريخ الولادة المتوقع (EDD)'),
      PresetField('عمر الحمل (أسابيع)'),
      PresetField('نبض الجنين'),
      PresetField('ارتفاع قاع الرحم'),
      PresetField('سونار', long: true),
      PresetField('المبيضان (سونار)', sides: true, long: true),
      PresetField('الفحص النسائي', long: true),
      PresetField('ملاحظات المتابعة', long: true),
    ],
  ),
  SpecialtyPreset(
    id: 'internal',
    name: 'الباطنية والطب العام',
    iconKey: 'steth',
    summary: 'العلامات الحيوية وفحص القلب والصدر والبطن',
    fields: [
      PresetField('ضغط الدم'),
      PresetField('النبض'),
      PresetField('الحرارة'),
      PresetField('الوزن (كغ)'),
      PresetField('سكر الدم'),
      PresetField('إشباع الأكسجين SpO2'),
      PresetField('فحص القلب', long: true),
      PresetField('فحص الصدر', long: true),
      PresetField('فحص البطن', long: true),
      PresetField('الأطراف', long: true),
    ],
  ),
  SpecialtyPreset(
    id: 'cardio',
    name: 'أمراض القلب',
    iconKey: 'heart',
    summary: 'ضغط ونبض وتخطيط وإيكو وعوامل الخطورة',
    fields: [
      PresetField('ضغط الدم', sides: true),
      PresetField('النبض'),
      PresetField('أصوات القلب', long: true),
      PresetField('فحص الصدر', long: true),
      PresetField('وذمة الأطراف'),
      PresetField('تخطيط القلب ECG', long: true),
      PresetField('إيكو (EF)', long: true),
      PresetField('عوامل الخطورة', long: true),
      PresetField('الأدوية الحالية', long: true),
    ],
  ),
  SpecialtyPreset(
    id: 'ent',
    name: 'أنف وأذن وحنجرة',
    iconKey: 'ear',
    summary: 'الأذنان والسمع والأنف والبلعوم والحنجرة',
    fields: [
      PresetField('الأذن', sides: true, long: true),
      PresetField('السمع', sides: true),
      PresetField('الأنف', long: true),
      PresetField('الحاجز الأنفي'),
      PresetField('البلعوم واللوزتان', long: true),
      PresetField('الحنجرة', long: true),
      PresetField('منظار', long: true),
    ],
  ),
  SpecialtyPreset(
    id: 'derma',
    name: 'الجلدية',
    iconKey: 'skin',
    summary: 'وصف الآفة وموضعها وانتشارها والعلاج السابق',
    fields: [
      PresetField('موقع الآفة'),
      PresetField('نوع الآفة', long: true),
      PresetField('الحجم والانتشار', long: true),
      PresetField('مدة الظهور'),
      PresetField('شدة الحالة'),
      PresetField('العلاج السابق', long: true),
      PresetField('تنظير جلدي', long: true),
    ],
  ),
  SpecialtyPreset(
    id: 'ortho',
    name: 'العظمية',
    iconKey: 'bone',
    summary: 'المفاصل ومدى الحركة والقوة والعمود الفقري',
    fields: [
      PresetField('المفصل المصاب', sides: true),
      PresetField('مدى الحركة', sides: true),
      PresetField('القوة العضلية', sides: true),
      PresetField('شدة الألم (0-10)'),
      PresetField('فحص العمود الفقري', long: true),
      PresetField('الأشعة', long: true),
      PresetField('الجبيرة / العلاج', long: true),
    ],
  ),
  SpecialtyPreset(
    id: 'neuro',
    name: 'الأعصاب',
    iconKey: 'brain',
    summary: 'الأعصاب القحفية والقوة والمنعكسات والتوازن',
    fields: [
      PresetField('مستوى الوعي'),
      PresetField('الأعصاب القحفية', long: true),
      PresetField('القوة العضلية', sides: true),
      PresetField('المنعكسات', sides: true),
      PresetField('الحس', sides: true),
      PresetField('التوازن والمشية', long: true),
      PresetField('MRI / CT', long: true),
      PresetField('EEG / EMG', long: true),
    ],
  ),
  SpecialtyPreset(
    id: 'surgery',
    name: 'الجراحة العامة',
    iconKey: 'surgery',
    summary: 'الفحص قبل العملية والعملية المقترحة والمتابعة',
    fields: [
      PresetField('موضع الشكوى'),
      PresetField('فحص البطن', long: true),
      PresetField('العملية المقترحة', long: true),
      PresetField('تحاليل ما قبل العملية', long: true),
      PresetField('تصنيف التخدير ASA'),
      PresetField('ملاحظات بعد العملية', long: true),
    ],
  ),
  SpecialtyPreset(
    id: 'other',
    name: 'اختصاص آخر (نموذج عام)',
    iconKey: 'steth',
    summary: 'علامات حيوية وفحص سريري تعدّله كما تشاء',
    fields: [
      PresetField('ضغط الدم'),
      PresetField('النبض'),
      PresetField('الحرارة'),
      PresetField('الوزن (كغ)'),
      PresetField('الفحص السريري', long: true),
    ],
  ),
];

/// Name for the "pick your specialty" dropdowns (onboarding, adding a clinic).
SpecialtyPreset? presetById(String? id) =>
    specialtyPresets.where((p) => p.id == id).firstOrNull;

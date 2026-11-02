/// One target column on the [Patient] entity that an imported spreadsheet
/// column can be mapped to. [headerHints] are lowercased substrings used to
/// guess the right spreadsheet column automatically, in both Arabic and
/// English, since a doctor's old ledger could be headed either way.
enum ImportField {
  fullName('الاسم الكامل *', [
    'الاسم الكامل',
    'اسم المريض',
    'الاسم',
    'full name',
    'patient name',
    'name',
  ]),
  patientNumber('رقم المريض', [
    'رقم المريض',
    'رقم الملف',
    'patient number',
    'patient no',
    'file number',
  ]),
  phone('رقم الهاتف', ['رقم الهاتف', 'الهاتف', 'جوال', 'phone', 'mobile']),
  gender('الجنس', ['الجنس', 'sex', 'gender']),
  address('العنوان', ['العنوان', 'address']),
  age('العمر', ['العمر', 'age']),
  diagnosis('الشكاية', ['الشكاية', 'التشخيص', 'diagnosis', 'complaint']),
  previousMedications('الأدوية السابقة', [
    'الأدوية السابقة',
    'previous medications',
  ]),
  currentMedications('الأدوية الحالية', [
    'الأدوية الحالية',
    'current medications',
  ]),
  allergies('الحساسية', ['الحساسية', 'allergies']),
  medicalHistory('التاريخ المرضي', ['التاريخ المرضي', 'medical history']),
  surgeriesHistory('عمليات سابقة', [
    'عمليات سابقة',
    'العمليات',
    'surgeries',
    'surgery history',
  ]),
  notes('ملاحظات إضافية', ['ملاحظات', 'notes']);

  const ImportField(this.label, this.headerHints);

  final String label;
  final List<String> headerHints;

  bool get isRequired => this == ImportField.fullName;
}

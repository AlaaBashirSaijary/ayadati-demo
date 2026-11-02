import 'package:equatable/equatable.dart';

enum Gender { male, female }

extension GenderLabel on Gender? {
  /// Mirrors Patient::genderLabel() in app/Models/Patient.php.
  String get label => switch (this) {
    Gender.male => 'ذكر',
    Gender.female => 'أنثى',
    null => '—',
  };
}

/// Mirrors app/Models/Patient.php field-for-field, so the Flutter app
/// captures exactly the same record the Laravel app does.
class Patient extends Equatable {
  const Patient({
    this.id,
    this.patientNumber,
    required this.fullName,
    this.gender,
    this.phone,
    this.address,
    this.birthDate,
    this.age,
    this.diagnosis,
    this.previousMedications,
    this.currentMedications,
    this.allergies,
    this.medicalHistory,
    this.surgeriesHistory,
    this.notes,
    this.isActive = true,
    this.followUpPlanMonths,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String? patientNumber;
  final String fullName;
  final Gender? gender;
  final String? phone;
  final String? address;
  final DateTime? birthDate;
  final int? age;
  final String? diagnosis;
  final String? previousMedications;
  final String? currentMedications;
  final String? allergies;
  final String? medicalHistory;
  final String? surgeriesHistory;
  final String? notes;
  final bool isActive;

  /// A recurring care-plan interval in months (e.g. 3, 6, 12) — for a
  /// chronic-condition patient who needs checking every N months as a
  /// matter of course. When set, a new visit for this patient defaults to
  /// "يحتاج متابعة" with a target date N months out, instead of the doctor
  /// re-flagging it by hand every single time. Null means no standing plan.
  final int? followUpPlanMonths;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Mirrors Patient::statusLabel().
  String get statusLabel => isActive ? 'نشط' : 'غير نشط';

  /// Mirrors Patient::displayAge(): explicit age wins, otherwise derive
  /// from birth date.
  int? get displayAge {
    if (age != null) return age;
    if (birthDate == null) return null;

    final now = DateTime.now();
    var years = now.year - birthDate!.year;
    final hadBirthdayThisYear =
        now.month > birthDate!.month ||
        (now.month == birthDate!.month && now.day >= birthDate!.day);
    if (!hadBirthdayThisYear) years--;
    return years;
  }

  Patient copyWith({
    int? id,
    String? patientNumber,
    String? fullName,
    Gender? gender,
    String? phone,
    String? address,
    DateTime? birthDate,
    int? age,
    String? diagnosis,
    String? previousMedications,
    String? currentMedications,
    String? allergies,
    String? medicalHistory,
    String? surgeriesHistory,
    String? notes,
    bool? isActive,
    int? followUpPlanMonths,
    bool clearFollowUpPlanMonths = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Patient(
      id: id ?? this.id,
      patientNumber: patientNumber ?? this.patientNumber,
      fullName: fullName ?? this.fullName,
      gender: gender ?? this.gender,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      birthDate: birthDate ?? this.birthDate,
      age: age ?? this.age,
      diagnosis: diagnosis ?? this.diagnosis,
      previousMedications: previousMedications ?? this.previousMedications,
      currentMedications: currentMedications ?? this.currentMedications,
      allergies: allergies ?? this.allergies,
      medicalHistory: medicalHistory ?? this.medicalHistory,
      surgeriesHistory: surgeriesHistory ?? this.surgeriesHistory,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      followUpPlanMonths: clearFollowUpPlanMonths
          ? null
          : (followUpPlanMonths ?? this.followUpPlanMonths),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    patientNumber,
    fullName,
    gender,
    phone,
    address,
    birthDate,
    age,
    diagnosis,
    previousMedications,
    currentMedications,
    allergies,
    medicalHistory,
    surgeriesHistory,
    notes,
    isActive,
    followUpPlanMonths,
  ];
}

/// Dashboard status filter — mirrors the 'all' | 'active' | 'inactive'
/// query param handled by HomeController / Patient::scopeStatus().
enum PatientStatusFilter {
  all,
  active,
  inactive;

  String get queryValue => switch (this) {
    PatientStatusFilter.all => 'all',
    PatientStatusFilter.active => 'active',
    PatientStatusFilter.inactive => 'inactive',
  };

  String get label => switch (this) {
    PatientStatusFilter.all => 'الكل',
    PatientStatusFilter.active => 'نشط',
    PatientStatusFilter.inactive => 'غير نشط',
  };
}

/// A page of results — mirrors Laravel's LengthAwarePaginator shape closely
/// enough for the presentation layer to reuse the same pagination UI ideas.
class PatientPage extends Equatable {
  const PatientPage({
    required this.items,
    required this.total,
    required this.page,
    required this.perPage,
  });

  final List<Patient> items;
  final int total;
  final int page;
  final int perPage;

  bool get hasMore => page * perPage < total;

  @override
  List<Object?> get props => [items, total, page, perPage];
}

/// Dashboard stat-card numbers for the active clinic.
class PatientStats extends Equatable {
  const PatientStats({this.total = 0, this.active = 0, this.inactive = 0});

  final int total;
  final int active;
  final int inactive;

  @override
  List<Object?> get props => [total, active, inactive];
}

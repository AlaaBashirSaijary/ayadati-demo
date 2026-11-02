import '../../domain/entities/patient.dart';

/// Maps between the domain [Patient] entity and a sqflite row
/// (a `Map<String, Object?>` row) — the Flutter analogue of Eloquent's attribute
/// casting ('birth_date' => 'date', 'is_active' => 'boolean', etc.).
class PatientModel extends Patient {
  const PatientModel({
    super.id,
    super.patientNumber,
    required super.fullName,
    super.gender,
    super.phone,
    super.address,
    super.birthDate,
    super.age,
    super.diagnosis,
    super.previousMedications,
    super.currentMedications,
    super.allergies,
    super.medicalHistory,
    super.surgeriesHistory,
    super.notes,
    super.isActive,
    super.followUpPlanMonths,
    super.createdAt,
    super.updatedAt,
  });

  factory PatientModel.fromEntity(Patient patient) => PatientModel(
    id: patient.id,
    patientNumber: patient.patientNumber,
    fullName: patient.fullName,
    gender: patient.gender,
    phone: patient.phone,
    address: patient.address,
    birthDate: patient.birthDate,
    age: patient.age,
    diagnosis: patient.diagnosis,
    previousMedications: patient.previousMedications,
    currentMedications: patient.currentMedications,
    allergies: patient.allergies,
    medicalHistory: patient.medicalHistory,
    surgeriesHistory: patient.surgeriesHistory,
    notes: patient.notes,
    isActive: patient.isActive,
    followUpPlanMonths: patient.followUpPlanMonths,
    createdAt: patient.createdAt,
    updatedAt: patient.updatedAt,
  );

  factory PatientModel.fromMap(Map<String, Object?> map) => PatientModel(
    id: map['id'] as int?,
    patientNumber: map['patient_number'] as String?,
    fullName: map['full_name']! as String,
    gender: switch (map['gender']) {
      'male' => Gender.male,
      'female' => Gender.female,
      _ => null,
    },
    phone: map['phone'] as String?,
    address: map['address'] as String?,
    birthDate: map['birth_date'] == null
        ? null
        : DateTime.parse(map['birth_date']! as String),
    age: map['age'] as int?,
    diagnosis: map['diagnosis'] as String?,
    previousMedications: map['previous_medications'] as String?,
    currentMedications: map['current_medications'] as String?,
    allergies: map['allergies'] as String?,
    medicalHistory: map['medical_history'] as String?,
    surgeriesHistory: map['surgeries_history'] as String?,
    notes: map['notes'] as String?,
    isActive: (map['is_active']! as int) == 1,
    followUpPlanMonths: map['follow_up_plan_months'] as int?,
    createdAt: map['created_at'] == null
        ? null
        : DateTime.parse(map['created_at']! as String),
    updatedAt: map['updated_at'] == null
        ? null
        : DateTime.parse(map['updated_at']! as String),
  );

  /// Excludes 'id' — callers add it back only for updates (sqflite's
  /// update()/insert() take the id separately via the where clause / return).
  Map<String, Object?> toMap() {
    final now = DateTime.now().toIso8601String();
    return {
      'patient_number': patientNumber,
      'full_name': fullName,
      'gender': switch (gender) {
        Gender.male => 'male',
        Gender.female => 'female',
        null => null,
      },
      'phone': phone,
      'address': address,
      'birth_date': birthDate?.toIso8601String().split('T').first,
      'age': age,
      'diagnosis': diagnosis,
      'previous_medications': previousMedications,
      'current_medications': currentMedications,
      'allergies': allergies,
      'medical_history': medicalHistory,
      'surgeries_history': surgeriesHistory,
      'notes': notes,
      'is_active': isActive ? 1 : 0,
      'follow_up_plan_months': followUpPlanMonths,
      'created_at': createdAt?.toIso8601String() ?? now,
      'updated_at': now,
    };
  }
}

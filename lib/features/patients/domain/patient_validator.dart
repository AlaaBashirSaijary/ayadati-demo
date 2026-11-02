import '../../../core/error/failures.dart';
import 'entities/patient.dart';

/// Same rules as PatientController::validated() in the Laravel app —
/// full_name required, everything else optional, age 0-120, birth date not
/// in the future. Kept as a plain function so both the create and edit forms
/// (which share one rule set, same as patients._form.blade.php) call it
/// identically.
class PatientValidator {
  const PatientValidator._();

  static ValidationFailure? validate(Patient patient) {
    final errors = <String, String>{};

    if (patient.fullName.trim().isEmpty) {
      errors['full_name'] = 'أدخل اسم المريض.';
    } else if (patient.fullName.length > 255) {
      errors['full_name'] = 'الاسم طويل جدًا.';
    }

    if (patient.age != null && (patient.age! < 0 || patient.age! > 120)) {
      errors['age'] = 'العمر غير صحيح.';
    }

    if (patient.followUpPlanMonths != null &&
        (patient.followUpPlanMonths! < 1 || patient.followUpPlanMonths! > 24)) {
      errors['follow_up_plan_months'] = 'مدة خطة المتابعة غير صحيحة.';
    }

    if (patient.birthDate != null &&
        patient.birthDate!.isAfter(DateTime.now())) {
      errors['birth_date'] = 'تاريخ الميلاد لا يمكن أن يكون في المستقبل.';
    }

    if ((patient.patientNumber ?? '').length > 50) {
      errors['patient_number'] = 'رقم المريض طويل جدًا.';
    }

    if ((patient.phone ?? '').length > 40) {
      errors['phone'] = 'رقم الهاتف طويل جدًا.';
    }

    for (final MapEntry(:key, value: text) in {
      'diagnosis': patient.diagnosis,
      'previous_medications': patient.previousMedications,
      'current_medications': patient.currentMedications,
      'allergies': patient.allergies,
      'medical_history': patient.medicalHistory,
      'surgeries_history': patient.surgeriesHistory,
      'notes': patient.notes,
    }.entries) {
      if ((text ?? '').length > 5000) {
        errors[key] = 'النص طويل جدًا.';
      }
    }

    return errors.isEmpty ? null : ValidationFailure(errors);
  }
}

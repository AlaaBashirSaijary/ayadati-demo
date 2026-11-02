import 'package:get_it/get_it.dart';

import '../database/app_database.dart';
import '../database/clinic_data_database.dart';
import '../security/app_lock_service.dart';
import '../../features/clinic_defaults/data/datasources/clinic_defaults_local_datasource.dart';
import '../../features/debts/data/debts_local_datasource.dart';
import '../../features/recall/data/recall_local_datasource.dart';
import '../../features/clinic_defaults/data/repositories/clinic_defaults_repository_impl.dart';
import '../../features/clinic_defaults/domain/repositories/clinic_defaults_repository.dart';
import '../../features/clinic_defaults/domain/usecases/fee_defaults_usecases.dart';
import '../../features/clinic_defaults/domain/usecases/phrase_usecases.dart';
import '../../features/appointments/data/datasources/appointment_local_datasource.dart';
import '../../features/appointments/data/repositories/appointment_repository_impl.dart';
import '../../features/appointments/domain/repositories/appointment_repository.dart';
import '../../features/appointments/domain/usecases/delete_appointment.dart';
import '../../features/appointments/domain/usecases/get_appointments_for_day.dart';
import '../../features/appointments/domain/usecases/get_follow_up_days.dart';
import '../../features/appointments/domain/usecases/find_appointment_conflict.dart';
import '../../features/appointments/domain/usecases/get_follow_up_suggestion.dart';
import '../../features/appointments/domain/usecases/get_half_price_days.dart';
import '../../features/appointments/domain/usecases/get_monthly_appointment_counts.dart';
import '../../features/appointments/domain/usecases/get_upcoming_appointments.dart';
import '../../features/appointments/domain/usecases/save_appointment.dart';
import '../../features/appointments/domain/usecases/set_follow_up_days.dart';
import '../../features/appointments/domain/usecases/set_half_price_days.dart';
import '../../features/auth/data/datasources/auth_local_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login.dart';
import '../../features/clinics/data/datasources/clinic_local_datasource.dart';
import '../../features/clinics/data/repositories/clinic_repository_impl.dart';
import '../../features/clinics/domain/repositories/clinic_repository.dart';
import '../../features/doctors/data/datasources/doctor_local_datasource.dart';
import '../../features/doctors/data/repositories/doctor_repository_impl.dart';
import '../../features/doctors/domain/repositories/doctor_repository.dart';
import '../../features/doctors/domain/usecases/get_doctors.dart';
import '../../features/doctors/domain/usecases/save_doctor.dart';
import '../../features/doctors/domain/usecases/toggle_doctor_status.dart';
import '../../features/medical_certificates/data/datasources/medical_certificate_local_datasource.dart';
import '../../features/medical_certificates/data/repositories/medical_certificate_repository_impl.dart';
import '../../features/medical_certificates/domain/repositories/medical_certificate_repository.dart';
import '../../features/medical_certificates/domain/usecases/get_medical_certificates.dart';
import '../../features/medical_certificates/domain/usecases/save_medical_certificate.dart';
import '../../features/prescriptions/data/datasources/prescription_local_datasource.dart';
import '../../features/prescriptions/data/repositories/prescription_repository_impl.dart';
import '../../features/prescriptions/domain/repositories/prescription_repository.dart';
import '../../features/prescriptions/domain/usecases/get_prescriptions.dart';
import '../../features/prescriptions/domain/usecases/save_prescription.dart';
import '../../features/patients/data/datasources/patient_local_datasource.dart';
import '../../features/patients/data/repositories/patient_repository_impl.dart';
import '../../features/patients/domain/repositories/patient_repository.dart';
import '../../features/patient_import/domain/usecases/import_patients.dart';
import '../../features/patients/domain/usecases/create_patient.dart';
import '../../features/patients/domain/usecases/get_new_patients_count.dart';
import '../../features/patients/domain/usecases/get_patient.dart';
import '../../features/patients/domain/usecases/get_patient_stats.dart';
import '../../features/patients/domain/usecases/get_patients.dart';
import '../../features/patients/domain/usecases/toggle_patient_status.dart';
import '../../features/patients/domain/usecases/update_patient.dart';
import '../../features/visits/data/datasources/exam_template_local_datasource.dart';
import '../../features/visits/data/datasources/visit_local_datasource.dart';
import '../../features/visits/data/repositories/exam_template_repository_impl.dart';
import '../../features/visits/data/repositories/visit_repository_impl.dart';
import '../../features/visits/domain/repositories/exam_template_repository.dart';
import '../../features/visits/domain/repositories/visit_repository.dart';
import '../../features/visits/domain/usecases/add_visit_photo.dart';
import '../../features/visits/domain/usecases/delete_exam_template.dart';
import '../../features/visits/domain/usecases/delete_visit.dart';
import '../../features/visits/domain/usecases/delete_visit_photo.dart';
import '../../features/visits/domain/usecases/get_exam_templates.dart';
import '../../features/visits/domain/usecases/get_today_visits_count.dart';
import '../../features/visits/domain/usecases/get_visit_field_values.dart';
import '../../features/visits/domain/usecases/get_visit_field_values_for_visits.dart';
import '../../features/visits/domain/usecases/get_visit_photos.dart';
import '../../features/visits/domain/usecases/get_financial_report.dart';
import '../../features/visits/domain/usecases/get_follow_ups_due.dart';
import '../../features/visits/domain/usecases/get_patient_photos.dart';
import '../../features/visits/domain/usecases/get_visits.dart';
import '../../features/visits/domain/usecases/reorder_exam_templates.dart';
import '../../features/visits/domain/usecases/save_exam_template.dart';
import '../../features/visits/domain/usecases/save_visit.dart';
import '../../features/visits/domain/usecases/save_visit_field_values.dart';

final sl = GetIt.instance;

/// Wires every layer together once, at app start — the Flutter equivalent
/// of Laravel's service container auto-resolving controllers' dependencies.
void setupDependencyInjection() {
  sl.registerLazySingleton(() => AppDatabase.instance);
  // Per-clinic data connection — which file it points at changes at
  // runtime (see ActiveClinicNotifier), but the instance itself is a
  // singleton, same as AppDatabase.
  sl.registerLazySingleton(() => ClinicDataDatabase.instance);
  sl.registerLazySingleton(() => AppLockService());

  // Clinics registry
  sl.registerLazySingleton(() => ClinicLocalDataSource(sl()));
  sl.registerLazySingleton<ClinicRepository>(() => ClinicRepositoryImpl(sl()));

  // Auth
  sl.registerLazySingleton(() => AuthLocalDataSource(sl(), sl()));
  sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(sl()));
  sl.registerFactory(() => Login(sl()));

  // Doctors (per active clinic — a scheduling/attribution label, not a
  // login account; see doctors table doc comment)
  sl.registerLazySingleton(() => DoctorLocalDataSource(sl()));
  sl.registerLazySingleton<DoctorRepository>(() => DoctorRepositoryImpl(sl()));
  sl.registerFactory(() => GetDoctors(sl()));
  sl.registerFactory(() => SaveDoctor(sl()));
  sl.registerFactory(() => ToggleDoctorStatus(sl()));

  // Clinic defaults (fees per visit type + learned quick phrases)
  sl.registerLazySingleton(() => ClinicDefaultsLocalDataSource(sl()));
  sl.registerLazySingleton<ClinicDefaultsRepository>(
    () => ClinicDefaultsRepositoryImpl(sl()),
  );
  sl.registerFactory(() => GetFeeDefaults(sl()));
  sl.registerFactory(() => SaveFeeDefaults(sl()));
  sl.registerFactory(() => GetPhrases(sl()));
  sl.registerFactory(() => RecordPhrase(sl()));
  sl.registerFactory(() => DeletePhrase(sl()));

  // Patient balances (الذمم) and payments
  sl.registerLazySingleton(() => DebtsLocalDataSource(sl()));

  // Recall list (follow-ups due + lapsed patients)
  sl.registerLazySingleton(() => RecallLocalDataSource(sl()));

  // Prescriptions
  sl.registerLazySingleton(() => PrescriptionLocalDataSource(sl()));
  sl.registerLazySingleton<PrescriptionRepository>(
    () => PrescriptionRepositoryImpl(sl()),
  );
  sl.registerFactory(() => GetPrescriptions(sl()));
  sl.registerFactory(() => SavePrescription(sl()));

  // Medical certificates (sick leave / general reports)
  sl.registerLazySingleton(() => MedicalCertificateLocalDataSource(sl()));
  sl.registerLazySingleton<MedicalCertificateRepository>(
    () => MedicalCertificateRepositoryImpl(sl()),
  );
  sl.registerFactory(() => GetMedicalCertificates(sl()));
  sl.registerFactory(() => SaveMedicalCertificate(sl()));

  // Patients (always against whichever clinic is currently active)
  sl.registerLazySingleton(() => PatientLocalDataSource(sl()));
  sl.registerLazySingleton<PatientRepository>(
    () => PatientRepositoryImpl(sl()),
  );
  sl.registerFactory(() => GetPatients(sl()));
  sl.registerFactory(() => GetPatient(sl()));
  sl.registerFactory(() => CreatePatient(sl()));
  sl.registerFactory(() => UpdatePatient(sl()));
  sl.registerFactory(() => TogglePatientStatus(sl()));
  sl.registerFactory(() => ImportPatients(sl(), sl()));
  sl.registerFactory(() => GetPatientStats(sl()));
  sl.registerFactory(() => GetNewPatientsCount(sl()));

  // Visits (per-patient exam records)
  sl.registerLazySingleton(() => VisitLocalDataSource(sl()));
  sl.registerLazySingleton<VisitRepository>(() => VisitRepositoryImpl(sl()));
  sl.registerFactory(() => GetVisits(sl()));
  sl.registerFactory(() => GetFollowUpsDue(sl()));
  sl.registerFactory(() => GetFinancialReport(sl()));
  sl.registerFactory(() => SaveVisit(sl()));
  sl.registerFactory(() => DeleteVisit(sl()));
  sl.registerFactory(() => GetTodayVisitsCount(sl()));
  sl.registerFactory(() => GetVisitPhotos(sl()));
  sl.registerFactory(() => GetPatientPhotos(sl()));
  sl.registerFactory(() => AddVisitPhoto(sl()));
  sl.registerFactory(() => DeleteVisitPhoto(sl()));
  sl.registerFactory(() => GetVisitFieldValues(sl()));
  sl.registerFactory(() => GetVisitFieldValuesForVisits(sl()));
  sl.registerFactory(() => SaveVisitFieldValues(sl()));

  // Exam form templates (doctor-configurable exam fields)
  sl.registerLazySingleton(() => ExamTemplateLocalDataSource(sl()));
  sl.registerLazySingleton<ExamTemplateRepository>(
    () => ExamTemplateRepositoryImpl(sl()),
  );
  sl.registerFactory(() => GetExamTemplates(sl()));
  sl.registerFactory(() => SaveExamTemplate(sl()));
  sl.registerFactory(() => DeleteExamTemplate(sl()));
  sl.registerFactory(() => ReorderExamTemplates(sl()));

  // Appointments (future-dated bookings, distinct from historical visits)
  sl.registerLazySingleton(() => AppointmentLocalDataSource(sl()));
  sl.registerLazySingleton<AppointmentRepository>(
    () => AppointmentRepositoryImpl(sl()),
  );
  sl.registerFactory(() => GetAppointmentsForDay(sl()));
  sl.registerFactory(() => GetUpcomingAppointments(sl()));
  sl.registerFactory(() => SaveAppointment(sl()));
  sl.registerFactory(() => DeleteAppointment(sl()));
  sl.registerFactory(() => GetFollowUpSuggestion(sl()));
  sl.registerFactory(() => FindAppointmentConflict(sl()));
  sl.registerFactory(() => GetFollowUpDays(sl()));
  sl.registerFactory(() => SetFollowUpDays(sl()));
  sl.registerFactory(() => GetHalfPriceDays(sl()));
  sl.registerFactory(() => SetHalfPriceDays(sl()));
  sl.registerFactory(() => GetMonthlyAppointmentCounts(sl()));
}

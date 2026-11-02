import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../appointments/domain/usecases/get_appointments_for_day.dart';
import '../../../clinics/presentation/providers/active_clinic_provider.dart';
import '../../../visits/domain/usecases/get_today_visits_count.dart';
import '../../domain/entities/patient.dart';
import '../../domain/usecases/get_new_patients_count.dart';
import '../../domain/usecases/get_patient_stats.dart';
import 'patients_provider.dart';

class DashboardStats {
  const DashboardStats({
    this.patients = const PatientStats(),
    this.seenToday = 0,
    this.appointmentsToday = 0,
    this.newPatientsThisWeek = 0,
    this.isLoading = true,
  });

  final PatientStats patients;
  final int seenToday;

  /// Scheduled bookings for today, cancelled ones included — the same raw
  /// count AppointmentsPage would show for today, used here for the
  /// dashboard's morning-greeting summary sentence.
  final int appointmentsToday;

  /// New patient records created in the last 7 days (a rolling window, not
  /// a calendar week) — also feeds the greeting sentence.
  final int newPatientsThisWeek;

  final bool isLoading;

  DashboardStats copyWith({
    PatientStats? patients,
    int? seenToday,
    int? appointmentsToday,
    int? newPatientsThisWeek,
    bool? isLoading,
  }) {
    return DashboardStats(
      patients: patients ?? this.patients,
      seenToday: seenToday ?? this.seenToday,
      appointmentsToday: appointmentsToday ?? this.appointmentsToday,
      newPatientsThisWeek: newPatientsThisWeek ?? this.newPatientsThisWeek,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// The dashboard header's stat cards (total/active/inactive patients,
/// distinct patients seen today) — refreshes whenever the patient list does
/// (so toggling a status or adding a patient updates the numbers) and
/// whenever the active clinic changes.
class DashboardStatsNotifier extends Notifier<DashboardStats> {
  late final GetPatientStats _getPatientStats;
  late final GetTodayVisitsCount _getTodayVisitsCount;
  late final GetAppointmentsForDay _getAppointmentsForDay;
  late final GetNewPatientsCount _getNewPatientsCount;

  @override
  DashboardStats build() {
    _getPatientStats = sl<GetPatientStats>();
    _getTodayVisitsCount = sl<GetTodayVisitsCount>();
    _getAppointmentsForDay = sl<GetAppointmentsForDay>();
    _getNewPatientsCount = sl<GetNewPatientsCount>();

    // Same numbers change whenever the patient list does (a status toggle,
    // a new patient, a switched clinic) — piggyback on that instead of
    // polling independently.
    ref.listen(patientsListProvider, (previous, next) {
      if (previous?.isLoading == true && next.isLoading == false) {
        refresh();
      }
    });

    if (ref.read(activeClinicProvider).isReady) {
      Future.microtask(refresh);
    }

    return const DashboardStats();
  }

  Future<void> refresh() async {
    if (!ref.read(activeClinicProvider).isReady) return;

    state = state.copyWith(isLoading: true);

    // Kicked off together (not `await`ed one at a time) so the queries run
    // concurrently — Future.wait needs a single element type, which these
    // Eithers/List don't share.
    final statsFuture = _getPatientStats(const NoParams());
    final todayFuture = _getTodayVisitsCount(const NoParams());
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final appointmentsFuture = _getAppointmentsForDay(today);
    final weekAgo = today.subtract(const Duration(days: 7));
    final newPatientsFuture = _getNewPatientsCount(
      DateRangeParams(start: weekAgo, end: today.add(const Duration(days: 1))),
    );

    final statsResult = await statsFuture;
    final todayResult = await todayFuture;
    final appointmentsResult = await appointmentsFuture;
    final newPatientsResult = await newPatientsFuture;

    state = state.copyWith(
      patients: statsResult.fold((_) => state.patients, (s) => s),
      seenToday: todayResult.fold((_) => state.seenToday, (c) => c),
      appointmentsToday: appointmentsResult.fold(
        (_) => state.appointmentsToday,
        (list) => list.length,
      ),
      newPatientsThisWeek: newPatientsResult.fold(
        (_) => state.newPatientsThisWeek,
        (c) => c,
      ),
      isLoading: false,
    );
  }
}

final dashboardStatsProvider =
    NotifierProvider<DashboardStatsNotifier, DashboardStats>(
      DashboardStatsNotifier.new,
    );

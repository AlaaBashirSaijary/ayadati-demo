import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../../clinics/presentation/providers/active_clinic_provider.dart';
import '../../domain/entities/patient.dart';
import '../../domain/usecases/get_patients.dart';
import '../../domain/usecases/toggle_patient_status.dart';

/// Mirrors HomeController's query state ($q, $status, pagination) — the
/// dashboard reads/writes this instead of GET query params.
class PatientsListState {
  const PatientsListState({
    this.query = '',
    this.status = PatientStatusFilter.all,
    this.page = 1,
    this.items = const [],
    this.total = 0,
    this.isLoading = true,
    this.error,
  });

  final String query;
  final PatientStatusFilter status;
  final int page;
  final List<Patient> items;
  final int total;
  final bool isLoading;
  final String? error;

  bool get searched => query.isNotEmpty || status != PatientStatusFilter.all;

  static const perPage = 20;

  int get lastPage => total == 0 ? 1 : (total / perPage).ceil();

  PatientsListState copyWith({
    String? query,
    PatientStatusFilter? status,
    int? page,
    List<Patient>? items,
    int? total,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return PatientsListState(
      query: query ?? this.query,
      status: status ?? this.status,
      page: page ?? this.page,
      items: items ?? this.items,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PatientsListNotifier extends Notifier<PatientsListState> {
  static const _perPage = PatientsListState.perPage;

  late final GetPatients _getPatients;
  late final TogglePatientStatus _toggleStatus;

  @override
  PatientsListState build() {
    _getPatients = sl<GetPatients>();
    _toggleStatus = sl<TogglePatientStatus>();

    // Re-fetch whenever the active clinic changes — its database file is a
    // completely different set of patients.
    ref.listen(activeClinicProvider, (previous, next) {
      if (next.active != null && previous?.active?.id != next.active?.id) {
        refresh();
      }
    });

    if (ref.read(activeClinicProvider).isReady) {
      Future.microtask(refresh);
    }

    return const PatientsListState();
  }

  Future<void> refresh() async {
    if (!ref.read(activeClinicProvider).isReady) return;

    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _getPatients(
      GetPatientsParams(
        query: state.query,
        status: state.status,
        page: state.page,
        perPage: _perPage,
      ),
    );

    result.fold(
      (failure) =>
          state = state.copyWith(isLoading: false, error: failure.message),
      (page) => state = state.copyWith(
        items: page.items,
        total: page.total,
        isLoading: false,
      ),
    );
  }

  Future<void> search(String query) async {
    state = state.copyWith(query: query, page: 1);
    await refresh();
  }

  Future<void> setStatus(PatientStatusFilter status) async {
    state = state.copyWith(status: status, page: 1);
    await refresh();
  }

  Future<void> clearFilters() async {
    state = state.copyWith(query: '', status: PatientStatusFilter.all, page: 1);
    await refresh();
  }

  Future<void> goToPage(int page) async {
    state = state.copyWith(page: page);
    await refresh();
  }

  Future<void> toggleStatus(int patientId) async {
    final result = await _toggleStatus(
      TogglePatientStatusParams(id: patientId),
    );
    result.fold(
      (failure) => state = state.copyWith(error: failure.message),
      (_) => refresh(),
    );
  }
}

final patientsListProvider =
    NotifierProvider<PatientsListNotifier, PatientsListState>(
      PatientsListNotifier.new,
    );

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/visit.dart';
import '../../domain/usecases/delete_visit.dart';
import '../../domain/usecases/get_visits.dart';

class VisitsState {
  const VisitsState({
    this.visits = const [],
    this.isLoading = true,
    this.error,
  });

  final List<Visit> visits;
  final bool isLoading;
  final String? error;

  VisitsState copyWith({List<Visit>? visits, bool? isLoading, String? error}) {
    return VisitsState(
      visits: visits ?? this.visits,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class VisitsNotifier extends FamilyNotifier<VisitsState, int> {
  late final GetVisits _getVisits;
  late final DeleteVisit _deleteVisit;
  late final int _patientId;

  @override
  VisitsState build(int arg) {
    _getVisits = sl<GetVisits>();
    _deleteVisit = sl<DeleteVisit>();
    _patientId = arg;
    Future.microtask(refresh);
    return const VisitsState();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    final result = await _getVisits(_patientId);
    result.fold(
      (failure) =>
          state = state.copyWith(isLoading: false, error: failure.message),
      (visits) =>
          state = state.copyWith(visits: visits, isLoading: false, error: null),
    );
  }

  Future<void> delete(int id) async {
    final result = await _deleteVisit(id);
    result.fold(
      (failure) => state = state.copyWith(error: failure.message),
      (_) => refresh(),
    );
  }
}

final visitsProvider =
    NotifierProvider.family<VisitsNotifier, VisitsState, int>(
      VisitsNotifier.new,
    );

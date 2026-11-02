import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../clinics/presentation/providers/active_clinic_provider.dart';
import '../../domain/entities/follow_up_due.dart';
import '../../domain/usecases/get_follow_ups_due.dart';

class FollowUpsState {
  const FollowUpsState({this.items = const [], this.isLoading = true});

  final List<FollowUpDue> items;
  final bool isLoading;

  FollowUpsState copyWith({List<FollowUpDue>? items, bool? isLoading}) {
    return FollowUpsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Backs both the dashboard's "متابعات مستحقة" banner (just the count) and
/// the dedicated list page — refreshes whenever the active clinic changes,
/// same as the other dashboard-adjacent providers.
class FollowUpsNotifier extends Notifier<FollowUpsState> {
  late final GetFollowUpsDue _getFollowUpsDue;

  @override
  FollowUpsState build() {
    _getFollowUpsDue = sl<GetFollowUpsDue>();

    ref.listen(activeClinicProvider, (previous, next) {
      if (next.active != null && previous?.active?.id != next.active?.id) {
        refresh();
      }
    });

    if (ref.read(activeClinicProvider).isReady) {
      Future.microtask(refresh);
    }

    return const FollowUpsState();
  }

  Future<void> refresh() async {
    if (!ref.read(activeClinicProvider).isReady) return;
    state = state.copyWith(isLoading: true);
    final result = await _getFollowUpsDue(const NoParams());
    state = result.fold(
      (_) => state.copyWith(isLoading: false),
      (items) => state.copyWith(items: items, isLoading: false),
    );
  }
}

final followUpsProvider = NotifierProvider<FollowUpsNotifier, FollowUpsState>(
  FollowUpsNotifier.new,
);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../../clinics/presentation/providers/active_clinic_provider.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/usecases/get_doctors.dart';
import '../../domain/usecases/save_doctor.dart';
import '../../domain/usecases/toggle_doctor_status.dart';

class DoctorsState {
  const DoctorsState({this.items = const [], this.isLoading = true});

  final List<Doctor> items;
  final bool isLoading;

  DoctorsState copyWith({List<Doctor>? items, bool? isLoading}) {
    return DoctorsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Backs both the Admin "الأطباء" list and the doctor picker/filter used
/// from appointments, visits, prescriptions and certificates — refreshes on
/// clinic switch like every other clinic-scoped provider.
class DoctorsNotifier extends Notifier<DoctorsState> {
  late final GetDoctors _getDoctors;
  late final SaveDoctor _saveDoctor;
  late final ToggleDoctorStatus _toggleDoctorStatus;

  @override
  DoctorsState build() {
    _getDoctors = sl<GetDoctors>();
    _saveDoctor = sl<SaveDoctor>();
    _toggleDoctorStatus = sl<ToggleDoctorStatus>();

    ref.listen(activeClinicProvider, (previous, next) {
      if (next.active != null && previous?.active?.id != next.active?.id) {
        refresh();
      }
    });

    if (ref.read(activeClinicProvider).isReady) {
      Future.microtask(refresh);
    }

    return const DoctorsState();
  }

  Future<void> refresh() async {
    if (!ref.read(activeClinicProvider).isReady) return;
    state = state.copyWith(isLoading: true);
    final result = await _getDoctors(const GetDoctorsParams());
    state = result.fold(
      (_) => state.copyWith(isLoading: false),
      (items) => state.copyWith(items: items, isLoading: false),
    );
  }

  Future<String?> save(Doctor doctor) async {
    final result = await _saveDoctor(doctor);
    return result.fold((failure) => failure.message, (_) {
      refresh();
      return null;
    });
  }

  Future<void> toggleStatus(int id) async {
    await _toggleDoctorStatus(id);
    refresh();
  }
}

final doctorsProvider = NotifierProvider<DoctorsNotifier, DoctorsState>(
  DoctorsNotifier.new,
);

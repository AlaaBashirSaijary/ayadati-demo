import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/database/activity_log_service.dart';
import '../../../../core/database/clinic_backup_service.dart';
import '../../../../core/database/clinic_data_database.dart';
import '../../../../core/database/update_safety_service.dart';
import '../../../../core/di/injection.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../lan_sync/data/lan_sync_service.dart';
import '../../domain/entities/clinic.dart';
import '../../domain/repositories/clinic_repository.dart';

class ActiveClinicState {
  const ActiveClinicState({
    this.clinics = const [],
    this.active,
    this.isLoading = true,
    this.error,
  });

  final List<Clinic> clinics;
  final Clinic? active;
  final bool isLoading;
  final String? error;

  bool get isReady => !isLoading && active != null;

  ActiveClinicState copyWith({
    List<Clinic>? clinics,
    Clinic? active,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ActiveClinicState(
      clinics: clinics ?? this.clinics,
      active: active ?? this.active,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Resolves and holds the clinic whose database file is currently open —
/// the piece that makes the clinic switcher work. Loads once auth
/// resolves (a signed-in session is required before any clinic data makes
/// sense), defaulting to the last one used (remembered in
/// SharedPreferences) or the first registered clinic otherwise.
class ActiveClinicNotifier extends Notifier<ActiveClinicState> {
  static const _prefKey = 'clinic_manager.active_clinic_id';

  late final ClinicRepository _repository;

  @override
  ActiveClinicState build() {
    _repository = sl<ClinicRepository>();

    // Re-resolve whenever sign-in state changes (covers login, onboarding,
    // and logout — the next sign-in may be a different clinic set entirely
    // if this device is ever reset, though in practice it's the same one).
    ref.listen(authProvider, (previous, next) {
      if (next.isSignedIn && previous?.isSignedIn != true) {
        _resolve();
      }
    });

    if (ref.read(authProvider).isSignedIn) {
      Future.microtask(_resolve);
    }

    return const ActiveClinicState();
  }

  Future<void> _resolve() async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _repository.list();
    await result.fold(
      (failure) async {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
      (clinics) async {
        if (clinics.isEmpty) {
          // Shouldn't happen post-onboarding, but fail loudly rather than
          // silently showing an empty dashboard if it ever does.
          state = state.copyWith(
            isLoading: false,
            error: 'لا توجد عيادة مسجّلة على هذا الجهاز.',
          );
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        final lastId = prefs.getInt(_prefKey);
        final chosen = clinics.firstWhere(
          (c) => c.id == lastId,
          orElse: () => clinics.first,
        );

        await ClinicDataDatabase.instance.switchTo(chosen.dbFileName);
        LanSyncService.instance.clinicName = chosen.name;
        LanSyncService.instance.autoStart();
        state = state.copyWith(
          clinics: clinics,
          active: chosen,
          isLoading: false,
        );

        // Runs quietly after the dashboard is already showing, not before
        // — a backup-safety check shouldn't add to how long opening the
        // app after an update takes. See UpdateSafetyService's own doc
        // comment for what this actually guards against.
        UpdateSafetyService.instance.backupIfVersionChanged();
      },
    );
  }

  /// Switches to an already-registered clinic.
  Future<void> switchTo(Clinic clinic) async {
    if (state.active?.id == clinic.id) return;

    state = state.copyWith(isLoading: true, clearError: true);
    await ClinicDataDatabase.instance.switchTo(clinic.dbFileName);
    LanSyncService.instance.clinicName = clinic.name;
    LanSyncService.instance.autoStart();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKey, clinic.id);

    state = state.copyWith(active: clinic, isLoading: false);
  }

  /// Creates a new clinic (its own empty database file) and switches to it
  /// immediately, so "add clinic" feels like one action, not two.
  Future<bool> createAndSwitch(String name, {String? specialtyId}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _repository.create(name, specialtyId: specialtyId);
    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (clinic) {
        state = state.copyWith(clinics: [...state.clinics, clinic]);
        switchTo(clinic);
        return true;
      },
    );
  }

  /// Restores [backup] into a brand-new clinic instead of overwriting the
  /// active one — the non-destructive alternative to
  /// ClinicBackupService.restoreBackup: the current clinic's data is never
  /// touched at all, and the restored data becomes its own separate clinic
  /// the doctor can switch to, browse, export from, and rename freely.
  Future<bool> restoreBackupAsNewClinic(
    ClinicBackup backup,
    String name,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _repository.create(name);
    final clinic = result.fold((failure) {
      state = state.copyWith(isLoading: false, error: failure.message);
      return null;
    }, (clinic) => clinic);
    if (clinic == null) return false;

    try {
      await ClinicBackupService.instance.restoreBackupInto(
        clinic.dbFileName,
        backup,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'تعذّرت استعادة النسخة كعيادة جديدة: $e',
      );
      return false;
    }

    state = state.copyWith(clinics: [...state.clinics, clinic]);
    await switchTo(clinic);
    await ActivityLogService.instance.log(
      ActivityAction.backupRestored,
      entityLabel: backup.fileName,
    );
    return true;
  }

  Future<bool> rename(Clinic clinic, String newName) async {
    final result = await _repository.rename(clinic.id, newName);
    return result.fold(
      (failure) {
        state = state.copyWith(error: failure.message);
        return false;
      },
      (renamed) {
        state = state.copyWith(
          clinics: [
            for (final c in state.clinics)
              if (c.id == renamed.id) renamed else c,
          ],
          active: state.active?.id == renamed.id ? renamed : state.active,
          clearError: true,
        );
        return true;
      },
    );
  }
}

final activeClinicProvider =
    NotifierProvider<ActiveClinicNotifier, ActiveClinicState>(
      ActiveClinicNotifier.new,
    );

import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'clinic_backup_service.dart';
import 'clinic_data_database.dart';

/// A safety net for the moment right after installing a new APK version —
/// on Android, updating an app in place (same package + signing key, which
/// the CI workflow always uses) never touches its existing data on its
/// own; the only way data actually gets lost around an update is a human
/// step outside the app entirely (uninstalling the old build before
/// installing the new one, wiping its private storage first). This can't
/// prevent that step, but it can make sure a fresh backup exists the
/// moment a version change is first seen, so even a surprising update
/// leaves a recent, restorable copy behind.
class UpdateSafetyService {
  UpdateSafetyService._();

  static final UpdateSafetyService instance = UpdateSafetyService._();

  static const _lastSeenBuildKey = 'clinic_manager.last_seen_build_number';

  /// Call once a clinic is active and its database is open. Compares the
  /// running app's build number against the last one this device recorded;
  /// if it changed (and there was a previous one to compare against — a
  /// brand-new install has nothing to protect yet), takes a backup of the
  /// now-active clinic before recording the new build number. Best-effort
  /// throughout: a failure here must never block the app from opening.
  Future<void> backupIfVersionChanged() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentBuild = '${info.version}+${info.buildNumber}';

      final prefs = await SharedPreferences.getInstance();
      final lastSeenBuild = prefs.getString(_lastSeenBuildKey);

      if (lastSeenBuild != null &&
          lastSeenBuild != currentBuild &&
          ClinicDataDatabase.instance.activeDbFileName != null) {
        await ClinicBackupService.instance.createBackup();
      }

      await prefs.setString(_lastSeenBuildKey, currentBuild);
    } catch (_) {
      // Never let a backup-safety check keep the clinic from opening.
    }
  }
}

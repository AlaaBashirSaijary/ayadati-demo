import 'package:shared_preferences/shared_preferences.dart';

import 'clinic_backup_service.dart';
import 'clinic_data_database.dart';

/// Result of checking whether the backup reminder should show — [lastBackup]
/// is null when a backup exists but is stale, or when there has never been
/// one at all (distinguish the two via [hasAnyBackup]).
class BackupReminder {
  const BackupReminder({required this.hasAnyBackup, this.lastBackup});

  final bool hasAnyBackup;
  final DateTime? lastBackup;
}

/// Decides whether the "you haven't backed up in a while" banner should
/// show — backups are otherwise entirely manual, so nothing else in the
/// app would ever notice a stale or missing backup on its own.
class BackupReminderService {
  BackupReminderService._();

  static final BackupReminderService instance = BackupReminderService._();

  /// How many days without a backup before nagging about it.
  static const int reminderIntervalDays = 7;

  /// How long a "remind me later" tap silences the banner for.
  static const Duration snoozeDuration = Duration(days: 1);

  String get _snoozeKey {
    final dbFileName = ClinicDataDatabase.instance.activeDbFileName ?? 'none';
    return 'backup_reminder.snoozed_until.$dbFileName';
  }

  /// Returns a [BackupReminder] when one is due, or null when the active
  /// clinic's backup is recent enough or the reminder was snoozed.
  Future<BackupReminder?> checkIfDue() async {
    final prefs = await SharedPreferences.getInstance();
    final snoozedUntilMillis = prefs.getInt(_snoozeKey);
    if (snoozedUntilMillis != null) {
      final snoozedUntil = DateTime.fromMillisecondsSinceEpoch(
        snoozedUntilMillis,
      );
      if (DateTime.now().isBefore(snoozedUntil)) return null;
    }

    final lastBackup = await ClinicBackupService.instance.lastBackupDate();
    if (lastBackup == null) {
      return const BackupReminder(hasAnyBackup: false);
    }

    final daysSince = DateTime.now().difference(lastBackup).inDays;
    if (daysSince < reminderIntervalDays) return null;
    return BackupReminder(hasAnyBackup: true, lastBackup: lastBackup);
  }

  Future<void> snooze() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _snoozeKey,
      DateTime.now().add(snoozeDuration).millisecondsSinceEpoch,
    );
  }
}

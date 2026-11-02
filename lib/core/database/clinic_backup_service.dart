import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'activity_log_service.dart';
import 'app_database.dart';
import 'clinic_data_database.dart';

/// A snapshot of one backup file on disk.
class ClinicBackup {
  const ClinicBackup({
    required this.filePath,
    required this.fileName,
    required this.createdAt,
    required this.sizeBytes,
  });

  final String filePath;
  final String fileName;
  final DateTime createdAt;
  final int sizeBytes;
}

/// Copies the active clinic's SQLite file to a timestamped snapshot under
/// `{storageFolder}/backups/`, and can restore one back over the live file —
/// the in-app equivalent of Laravel's old `clinic:backup` command, since
/// each clinic's data now lives in its own file (see [ClinicDataDatabase])
/// rather than one shared, server-backed database.
class ClinicBackupService {
  ClinicBackupService._();

  static final ClinicBackupService instance = ClinicBackupService._();

  /// How many backups to keep per clinic file before pruning the oldest —
  /// mirrors the old command's default retention.
  static const int retentionCount = 14;

  Future<Directory> _backupsDir() async {
    final folder = await AppDatabase.instance.currentFolder();
    final dir = Directory(p.join(folder, 'backups'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _stamp(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${time.year}${two(time.month)}${two(time.day)}_'
        '${two(time.hour)}${two(time.minute)}${two(time.second)}';
  }

  /// Copies the currently-active clinic's file into the backups folder,
  /// then prunes anything past [retentionCount] for that same clinic.
  Future<ClinicBackup> createBackup() async {
    final activeFileName = ClinicDataDatabase.instance.activeDbFileName;
    final activePath = await ClinicDataDatabase.instance.activeFilePath();
    if (activeFileName == null || activePath == null) {
      throw StateError('لا توجد عيادة نشطة لعمل نسخة احتياطية لها.');
    }
    if (!await File(activePath).exists()) {
      throw StateError('ملف قاعدة بيانات العيادة غير موجود.');
    }

    final dir = await _backupsDir();
    final baseName = p.basenameWithoutExtension(activeFileName);
    final backupName = '${baseName}_${_stamp(DateTime.now())}.sqlite';
    final backupPath = p.join(dir.path, backupName);

    final copied = await File(activePath).copy(backupPath);
    final stat = await copied.stat();

    await _pruneOldBackups(dir, baseName);

    await ActivityLogService.instance.log(
      ActivityAction.backupCreated,
      entityLabel: backupName,
    );

    return ClinicBackup(
      filePath: copied.path,
      fileName: backupName,
      createdAt: stat.modified,
      sizeBytes: stat.size,
    );
  }

  Future<void> _pruneOldBackups(Directory dir, String baseName) async {
    final backups = await _listForBaseName(dir, baseName);
    if (backups.length <= retentionCount) return;
    for (final backup in backups.skip(retentionCount)) {
      await File(backup.filePath).delete();
    }
  }

  Future<List<ClinicBackup>> _listForBaseName(
    Directory dir,
    String baseName,
  ) async {
    final entries = await dir
        .list()
        .where(
          (e) =>
              e is File &&
              p.basename(e.path).startsWith('${baseName}_') &&
              p.extension(e.path) == '.sqlite',
        )
        .cast<File>()
        .toList();

    final backups = <ClinicBackup>[];
    for (final file in entries) {
      final stat = await file.stat();
      backups.add(
        ClinicBackup(
          filePath: file.path,
          fileName: p.basename(file.path),
          createdAt: stat.modified,
          sizeBytes: stat.size,
        ),
      );
    }
    backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return backups;
  }

  /// All backups for the currently-active clinic, newest first.
  Future<List<ClinicBackup>> listBackups() async {
    final activeFileName = ClinicDataDatabase.instance.activeDbFileName;
    if (activeFileName == null) return const [];
    final dir = await _backupsDir();
    final baseName = p.basenameWithoutExtension(activeFileName);
    return _listForBaseName(dir, baseName);
  }

  /// When the active clinic's most recent backup was made, or null if it
  /// has never been backed up — backs the dashboard's reminder banner.
  Future<DateTime?> lastBackupDate() async {
    final backups = await listBackups();
    if (backups.isEmpty) return null;
    return backups.first.createdAt;
  }

  /// Copies [backup] to a temp file beside [targetPath] and opens it once
  /// to confirm it's actually a readable SQLite database *before*
  /// [targetPath] is touched at all — returns the validated temp path for
  /// the caller to swap into place with a rename (atomic on the
  /// filesystems this app runs on) once it's ready to. Deletes the temp
  /// file and throws instead if the backup turns out corrupt.
  Future<String> _copyToValidatedTemp(
    ClinicBackup backup,
    String targetPath,
  ) async {
    final tempPath = '$targetPath.restoring';
    await File(backup.filePath).copy(tempPath);

    try {
      final probe = await openDatabase(tempPath, readOnly: true);
      await probe.close();
    } catch (e) {
      await File(tempPath).delete();
      throw StateError('ملف النسخة الاحتياطية تالف أو غير صالح: $e');
    }

    return tempPath;
  }

  /// Overwrites the active clinic's live file with [backup] — the "استبدال"
  /// choice, destructive to the clinic's current data. Callers must confirm
  /// with the user first (see AdminHomePage's restore-choice dialog, which
  /// also offers [restoreBackupInto] as the non-destructive alternative).
  /// The current live file is snapshotted as an ordinary backup right
  /// before being touched, so a restore done by mistake can itself be
  /// undone from the same "النسخ المحفوظة" list afterward. The backup is
  /// copied and validated *before* the live connection is closed, so the
  /// clinic stays usable for as long as possible and only goes offline for
  /// the brief close-rename-reopen swap itself.
  Future<void> restoreBackup(ClinicBackup backup) async {
    final activeFileName = ClinicDataDatabase.instance.activeDbFileName;
    if (activeFileName == null) {
      throw StateError('لا توجد عيادة نشطة لاستعادة النسخة إليها.');
    }

    final folder = await AppDatabase.instance.currentFolder();
    final targetPath = p.join(folder, activeFileName);

    if (await File(targetPath).exists()) {
      await createBackup();
    }

    final tempPath = await _copyToValidatedTemp(backup, targetPath);

    await ClinicDataDatabase.instance.closeActive();
    await File(tempPath).rename(targetPath);
    await ClinicDataDatabase.instance.switchTo(activeFileName);

    await ActivityLogService.instance.log(
      ActivityAction.backupRestored,
      entityLabel: backup.fileName,
    );
  }

  /// Copies [backup]'s bytes into the file for [dbFileName] — the
  /// non-destructive "عيادة جديدة منفصلة" restore choice. Meant to be
  /// called right after a brand-new, still-empty clinic is registered (see
  /// ActiveClinicNotifier.restoreBackupAsNewClinic), before that clinic's
  /// file has ever been opened, so it starts out holding this backup's data
  /// instead of a blank schema — the currently-active clinic is never
  /// touched at all.
  Future<void> restoreBackupInto(String dbFileName, ClinicBackup backup) async {
    final folder = await AppDatabase.instance.currentFolder();
    final targetPath = p.join(folder, dbFileName);
    final tempPath = await _copyToValidatedTemp(backup, targetPath);
    await File(tempPath).rename(targetPath);
  }
}

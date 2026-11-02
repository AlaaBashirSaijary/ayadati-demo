import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns the single "app-level" SQLite connection — accounts (`users`) and
/// the registry of clinics (`clinics`), shared across the whole app
/// regardless of which clinic is currently active.
///
/// Patient records and visits are deliberately NOT here — each clinic has
/// its own separate database file for that (see [ClinicDataDatabase]), so
/// two clinics' data never share a file. This class only holds what has to
/// be readable before a clinic is even picked: who's logged in, and which
/// clinics exist to switch between.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _db;
  String? _customPath;

  static const _schemaVersion = 4;

  /// Where the database file currently lives. Defaults to sqflite's own
  /// databases directory (asking the active `databaseFactory` rather than
  /// path_provider keeps this working identically under both the real
  /// on-device plugin and the FFI engine `flutter test` swaps in — see
  /// test/widget_test.dart); call [useCustomPath] (after the user picks a
  /// folder via file_picker) to move it to an external drive instead — the
  /// Flutter equivalent of the Laravel admin settings' database_path.
  Future<String> currentPath() async {
    if (_customPath != null) return _customPath!;
    final dir = await databaseFactory.getDatabasesPath();
    return p.join(dir, 'clinic_manager.sqlite');
  }

  /// The folder the app-level database currently lives in — per-clinic data
  /// files (see [ClinicDataDatabase]) are kept right beside it, so moving
  /// storage to an external drive moves everything together.
  Future<String> currentFolder() async {
    final path = await currentPath();
    return p.dirname(path);
  }

  /// Switches the database to a new folder (e.g. one on an external drive),
  /// copying the existing file across so no records are lost — mirrors
  /// SettingsController::update()'s "copy across on move" behaviour.
  Future<void> useCustomPath(String folderPath) async {
    final newPath = p.join(folderPath, 'clinic_manager.sqlite');

    if (_db != null) {
      final oldPath = await currentPath();
      await _db!.close();
      _db = null;

      if (oldPath != newPath && await File(oldPath).exists()) {
        await File(oldPath).copy(newPath);
      }
    }

    _customPath = newPath;
    await database; // Re-open at the new location.
  }

  Future<Database> get database async {
    if (_db != null) return _db!;
    final path = await currentPath();
    _db = await openDatabase(
      path,
      version: _schemaVersion,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );
    return _db!;
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE clinics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        slug TEXT NOT NULL UNIQUE,
        db_file_name TEXT NOT NULL UNIQUE,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clinic_id INTEGER REFERENCES clinics(id) ON DELETE SET NULL,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'nurse',
        recovery_code_hash TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
  }

  Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Versions 1-2 kept `patients`/`visits` in this same database, scoped by
    // clinic_id. Nothing has shipped to a real client yet, so rather than
    // migrate that data, this drops and recreates the app-level tables —
    // per-clinic data now lives in ClinicDataDatabase files instead.
    if (oldVersion < 3) {
      await db.execute('DROP TABLE IF EXISTS visits');
      await db.execute('DROP TABLE IF EXISTS patients');
      await db.execute('DROP TABLE IF EXISTS users');
      await db.execute('DROP TABLE IF EXISTS clinics');
      await _createSchema(db, newVersion);
      return;
    }

    // Adds the "forgot password" recovery-code column onto a real, already
    // populated `users` table — a genuine ALTER TABLE rather than the
    // drop-and-recreate above, since by this version real accounts exist.
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE users ADD COLUMN recovery_code_hash TEXT');
    }
  }
}

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/clinic_data_database.dart';
import '../models/clinic_model.dart';

/// Raw SQLite access to the `clinics` registry table in the app-level
/// database (see AppDatabase — this is NOT a per-clinic file; it's the
/// small shared table that lists which per-clinic files exist).
class ClinicLocalDataSource {
  const ClinicLocalDataSource(this._db);

  final AppDatabase _db;

  Future<List<ClinicModel>> list() async {
    final db = await _db.database;
    final rows = await db.query('clinics', orderBy: 'id ASC');
    return rows.map(ClinicModel.fromMap).toList();
  }

  Future<ClinicModel?> find(int id) async {
    final db = await _db.database;
    final rows = await db.query('clinics', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return ClinicModel.fromMap(rows.first);
  }

  /// [specialtyId] (a SpecialtyPreset id) decides which exam form the new
  /// clinic's data file starts with; null keeps the generic default.
  Future<ClinicModel> create(String name, {String? specialtyId}) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    final slug = await _uniqueSlug(name);

    final id = await db.insert('clinics', {
      'name': name,
      'slug': slug,
      // Same slug drives both — one clinic, one file, one obvious name.
      'db_file_name': 'clinic_$slug.sqlite',
      'created_at': now,
      'updated_at': now,
    });

    final created = (await find(id))!;
    if (specialtyId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        ClinicDataDatabase.specialtyPrefKey(created.dbFileName),
        specialtyId,
      );
    }
    return created;
  }

  /// Renames the display name only — slug/db_file_name stay put, since the
  /// actual data file is already sitting on disk under that name and there's
  /// nothing to gain from renaming the file too.
  Future<ClinicModel> rename(int id, String newName) async {
    final db = await _db.database;
    await db.update(
      'clinics',
      {'name': newName, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    return (await find(id))!;
  }

  Future<String> _uniqueSlug(String name) async {
    final base = _slugify(name);
    final db = await _db.database;

    var candidate = base;
    var suffix = 2;
    while (true) {
      final existing = await db.query(
        'clinics',
        where: 'slug = ?',
        whereArgs: [candidate],
        limit: 1,
      );
      if (existing.isEmpty) return candidate;
      candidate = '$base-$suffix';
      suffix++;
    }
  }

  String _slugify(String name) {
    final ascii = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return ascii.isEmpty
        ? 'clinic-${DateTime.now().millisecondsSinceEpoch}'
        : ascii;
  }
}

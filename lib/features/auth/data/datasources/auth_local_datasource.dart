import 'dart:math';

import 'package:bcrypt/bcrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/database/app_database.dart';
import '../../../clinics/data/datasources/clinic_local_datasource.dart';
import '../models/app_user_model.dart';

/// One offline account's worth of onboarding output: the row itself, plus
/// the one-time plaintext recovery code — never stored anywhere but this
/// return value, since only its bcrypt hash is persisted (see
/// [AuthLocalDataSource.createClinicAndAdmin]).
class NewAccount {
  const NewAccount({required this.user, required this.recoveryCode});

  final AppUserModel user;
  final String recoveryCode;
}

/// Local equivalent of Laravel's `users` table lookups + session cookie.
/// [_prefKey] stores the signed-in user's id the same way Laravel's session
/// stores it server-side — just on-device instead.
class AuthLocalDataSource {
  const AuthLocalDataSource(this._db, this._clinics);

  final AppDatabase _db;
  final ClinicLocalDataSource _clinics;

  static const _prefKey = 'clinic_manager.current_user_id';

  Future<bool> hasAnyUser() async {
    final db = await _db.database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM users');
    return (rows.first['c']! as int) > 0;
  }

  Future<AppUserModel?> findByEmail(String email) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT users.*, clinics.name AS clinic_name
      FROM users
      LEFT JOIN clinics ON clinics.id = users.clinic_id
      WHERE users.email = ?
      LIMIT 1
    ''',
      [email.trim().toLowerCase()],
    );

    if (rows.isEmpty) return null;
    return AppUserModel.fromMap(rows.first);
  }

  Future<AppUserModel?> findById(int id) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT users.*, clinics.name AS clinic_name
      FROM users
      LEFT JOIN clinics ON clinics.id = users.clinic_id
      WHERE users.id = ?
      LIMIT 1
    ''',
      [id],
    );

    if (rows.isEmpty) return null;
    return AppUserModel.fromMap(rows.first);
  }

  /// Fetches the row's raw password hash so the repository can verify it —
  /// kept separate from AppUserModel, which never carries the hash around.
  Future<String?> passwordHashFor(String email) async {
    final db = await _db.database;
    final rows = await db.query(
      'users',
      columns: ['password'],
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
    );
    if (rows.isEmpty) return null;
    return rows.first['password'] as String?;
  }

  bool verifyPassword(String plain, String hash) {
    return BCrypt.checkpw(plain, hash);
  }

  /// First-run onboarding: creates the first clinic + admin account. Mirrors
  /// what ClinicSeeder does in the Laravel project, but done once on-device
  /// instead of shipped as seed data.
  ///
  /// Also generates the admin's one-time recovery code — with the app fully
  /// offline (no email to send a reset link to), this is the only way to
  /// recover the account if the password is forgotten, so it's issued right
  /// away rather than left for the admin to set up later and possibly skip.
  Future<NewAccount> createClinicAndAdmin({
    required String clinicName,
    required String adminName,
    required String email,
    required String password,
    String? specialtyId,
  }) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();

    // Shares the same slug/db-file-name generation the "add another clinic"
    // flow uses later, so the first clinic isn't special-cased.
    final clinic = await _clinics.create(clinicName, specialtyId: specialtyId);
    final recoveryCode = _generateRecoveryCode();

    final userId = await db.insert('users', {
      'clinic_id': clinic.id,
      'name': adminName,
      'email': email.trim().toLowerCase(),
      'password': BCrypt.hashpw(password, BCrypt.gensalt()),
      'role': 'admin',
      'recovery_code_hash': BCrypt.hashpw(recoveryCode, BCrypt.gensalt()),
      'created_at': now,
      'updated_at': now,
    });

    return NewAccount(
      user: (await findById(userId))!,
      recoveryCode: recoveryCode,
    );
  }

  /// Replaces [id]'s recovery code with a freshly generated one and returns
  /// it in plaintext — the only moment it's ever visible, same as at
  /// account creation. Lets an admin who's still signed in refresh their
  /// recovery code (e.g. after forgetting whether they saved the first one)
  /// without that requiring the old code.
  Future<String> regenerateRecoveryCode(int id) async {
    final db = await _db.database;
    final code = _generateRecoveryCode();
    await db.update(
      'users',
      {
        'recovery_code_hash': BCrypt.hashpw(code, BCrypt.gensalt()),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return code;
  }

  /// Verifies [recoveryCode] against [email]'s stored hash and, if it
  /// matches, overwrites the password — the offline stand-in for a
  /// "reset link" email. Returns false for any mismatch (unknown email, no
  /// code ever generated, wrong code) without distinguishing which, same as
  /// login's unified wrong-credentials message.
  Future<bool> resetPasswordWithRecoveryCode({
    required String email,
    required String recoveryCode,
    required String newPassword,
  }) async {
    final db = await _db.database;
    final rows = await db.query(
      'users',
      columns: ['id', 'recovery_code_hash'],
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
    );
    if (rows.isEmpty) return false;

    final hash = rows.first['recovery_code_hash'] as String?;
    if (hash == null ||
        !BCrypt.checkpw(recoveryCode.trim().toUpperCase(), hash)) {
      return false;
    }

    await db.update(
      'users',
      {
        'password': BCrypt.hashpw(newPassword, BCrypt.gensalt()),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [rows.first['id']! as int],
    );
    return true;
  }

  /// A short, hand-copyable code — uppercase letters/digits only, and
  /// excludes visually ambiguous characters (0/O, 1/I/L) since this is
  /// meant to be written down on paper and typed back in later.
  String _generateRecoveryCode() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    String group() =>
        List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
    return '${group()}-${group()}-${group()}';
  }

  Future<void> rememberSession(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKey, userId);
  }

  Future<void> forgetSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }

  Future<int?> currentSessionUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefKey);
  }

  Future<AppUserModel> updateName(int id, String name) async {
    final db = await _db.database;
    await db.update(
      'users',
      {'name': name, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    return (await findById(id))!;
  }

  /// Returns false if [currentPassword] doesn't match the stored hash —
  /// callers surface that as a validation error rather than a generic
  /// failure, same as the login screen's wrong-password message.
  Future<bool> changePassword(
    int id,
    String currentPassword,
    String newPassword,
  ) async {
    final db = await _db.database;
    final rows = await db.query(
      'users',
      columns: ['password'],
      where: 'id = ?',
      whereArgs: [id],
    );
    final hash = rows.first['password'] as String;
    if (!verifyPassword(currentPassword, hash)) return false;

    await db.update(
      'users',
      {
        'password': BCrypt.hashpw(newPassword, BCrypt.gensalt()),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return true;
  }

  /// Every account in [clinicId] — the clinic's admin always exists, staff
  /// ("nurse") accounts are created via [createStaffUser]. Admins first,
  /// then alphabetical, so the person who owns the clinic reads as such.
  Future<List<AppUserModel>> listUsersForClinic(int clinicId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT users.*, clinics.name AS clinic_name
      FROM users
      LEFT JOIN clinics ON clinics.id = users.clinic_id
      WHERE users.clinic_id = ?
      ORDER BY (users.role = 'admin') DESC, users.name COLLATE NOCASE ASC
      ''',
      [clinicId],
    );
    return rows.map(AppUserModel.fromMap).toList();
  }

  /// Adds another account to [clinicId] — the multi-user feature a single
  /// shared login can't give any real clinic: separate credentials per
  /// staff member, and (via [role]) whether they can reach the Admin page.
  /// No recovery code is issued here — a staff account that forgets its
  /// password gets reset by the clinic's admin instead (see
  /// [adminSetPassword]), matching how AuthGate only ever grants Admin
  /// access to `role == 'admin'`.
  Future<AppUserModel> createStaffUser({
    required int clinicId,
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final db = await _db.database;
    final normalizedEmail = email.trim().toLowerCase();

    final existing = await db.query(
      'users',
      columns: ['id'],
      where: 'email = ?',
      whereArgs: [normalizedEmail],
    );
    if (existing.isNotEmpty) {
      throw StateError('هذا البريد الإلكتروني مستخدم مسبقًا.');
    }

    final now = DateTime.now().toIso8601String();
    final userId = await db.insert('users', {
      'clinic_id': clinicId,
      'name': name,
      'email': normalizedEmail,
      'password': BCrypt.hashpw(password, BCrypt.gensalt()),
      'role': role,
      'created_at': now,
      'updated_at': now,
    });
    return (await findById(userId))!;
  }

  /// Admin-only password reset for someone else's account — no current
  /// password required, since the whole point is the other person can't
  /// provide one. Callers must verify the acting user is an admin first.
  Future<void> adminSetPassword(int userId, String newPassword) async {
    final db = await _db.database;
    await db.update(
      'users',
      {
        'password': BCrypt.hashpw(newPassword, BCrypt.gensalt()),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Removes a staff account, refusing to remove a clinic's last admin so
  /// it never ends up with no one able to reach the Admin page at all.
  Future<void> deleteUser(int userId) async {
    final db = await _db.database;
    final user = await findById(userId);
    if (user == null) return;

    if (user.role == 'admin') {
      final admins = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM users WHERE clinic_id = ? AND role = 'admin'",
        [user.clinicId],
      );
      if ((admins.first['c']! as int) <= 1) {
        throw StateError('لا يمكن حذف آخر مدير في العيادة.');
      }
    }

    await db.delete('users', where: 'id = ?', whereArgs: [userId]);
  }
}

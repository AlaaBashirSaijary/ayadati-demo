import 'package:bcrypt/bcrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Optional PIN lock shown before the app's own content — a device-level
/// concern (protects whichever clinic happens to be loaded), so it lives in
/// SharedPreferences rather than either clinic's SQLite file: it must work
/// before any clinic is even picked, and shouldn't travel with a clinic
/// backup/restore.
class AppLockService {
  static const _enabledKey = 'app_lock.enabled';
  static const _pinHashKey = 'app_lock.pin_hash';

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  /// Hashes and stores [pin], turning the lock on.
  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinHashKey, BCrypt.hashpw(pin, BCrypt.gensalt()));
    await prefs.setBool(_enabledKey, true);
  }

  /// Turns the lock off and forgets the PIN entirely.
  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinHashKey);
    await prefs.setBool(_enabledKey, false);
  }

  Future<bool> verify(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final hash = prefs.getString(_pinHashKey);
    if (hash == null) return false;
    return BCrypt.checkpw(pin, hash);
  }
}

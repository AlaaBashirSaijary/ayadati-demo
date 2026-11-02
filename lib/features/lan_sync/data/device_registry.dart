import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/paired_device.dart';
import '../domain/sync_permissions.dart';

/// The doctor's list of paired tablets, kept on the doctor's device only.
class DeviceRegistry {
  DeviceRegistry._();

  static final DeviceRegistry instance = DeviceRegistry._();

  static const _key = 'lan_sync.paired_devices';

  Future<List<PairedDevice>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    return [
      for (final j in (jsonDecode(raw) as List))
        PairedDevice.fromJson(j as Map<String, dynamic>),
    ];
  }

  Future<PairedDevice?> find(String id) async =>
      (await all()).where((d) => d.id == id).firstOrNull;

  Future<void> _save(List<PairedDevice> devices) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([for (final d in devices) d.toJson()]),
    );
  }

  Future<void> add(PairedDevice device) async =>
      _save([...await all(), device]);

  Future<void> remove(String id) async => _save([
    for (final d in await all())
      if (d.id != id) d,
  ]);

  Future<void> setPermissions(
    String id,
    Set<SyncPermission> permissions,
  ) async => _save([
    for (final d in await all())
      d.id == id ? d.copyWith(permissions: permissions) : d,
  ]);

  Future<void> touch(String id) async => _save([
    for (final d in await all())
      d.id == id ? d.copyWith(lastSeen: DateTime.now()) : d,
  ]);
}

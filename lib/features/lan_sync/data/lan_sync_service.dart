import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/database/clinic_data_database.dart';
import 'lan_sync_server.dart';
import 'sync_ops.dart';

/// Owns the doctor-side server for the whole app: remembers whether the
/// doctor turned sharing on, restarts it when the app opens, and keeps the
/// screen awake while it's on (a sleeping tablet stops answering).
class LanSyncService {
  LanSyncService._();

  static final LanSyncService instance = LanSyncService._();

  static const _enabledKey = 'lan_sync.host_enabled';

  String clinicName = '';

  late final LanSyncServer server = LanSyncServer(
    ops: SyncOps(clinicName: () => clinicName),
    clinicName: () => clinicName,
  );

  bool get isRunning => server.isRunning;

  Future<bool> wasEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_enabledKey) ?? false;

  /// Called once the app has a clinic open, so the server can answer.
  Future<void> autoStart() async {
    if (await wasEnabled() &&
        ClinicDataDatabase.instance.activeDbFileName != null) {
      await start(remember: false);
    }
  }

  Future<void> start({bool remember = true}) async {
    await server.start();
    try {
      await WakelockPlus.enable();
    } catch (_) {}
    if (remember) {
      (await SharedPreferences.getInstance()).setBool(_enabledKey, true);
    }
  }

  Future<void> stop() async {
    await server.stop();
    try {
      await WakelockPlus.disable();
    } catch (_) {}
    (await SharedPreferences.getInstance()).setBool(_enabledKey, false);
  }

  /// This device's Wi-Fi/LAN addresses, to show the doctor what to type on
  /// the other tablet if automatic discovery doesn't find it.
  Future<List<String>> localAddresses() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    return [
      for (final i in interfaces)
        for (final a in i.addresses)
          if (!a.isLinkLocal) a.address,
    ];
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:clinic_manager_flutter/core/database/clinic_data_database.dart';
import 'package:clinic_manager_flutter/core/di/injection.dart';
import 'package:clinic_manager_flutter/features/lan_sync/data/device_registry.dart';
import 'package:clinic_manager_flutter/features/lan_sync/data/lan_sync_client.dart';
import 'package:clinic_manager_flutter/features/lan_sync/data/lan_sync_server.dart';
import 'package:clinic_manager_flutter/features/lan_sync/data/sync_crypto.dart';
import 'package:clinic_manager_flutter/features/lan_sync/data/sync_ops.dart';
import 'package:clinic_manager_flutter/features/lan_sync/domain/sync_permissions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late LanSyncServer server;

  setUpAll(() async {
    await initializeDateFormatting('ar');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    SharedPreferences.setMockInitialValues({});
    setupDependencyInjection();
    await ClinicDataDatabase.instance.closeActive();
    await ClinicDataDatabase.instance.switchTo(
      'clinic_t_sync_${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );
    server = LanSyncServer(
      ops: SyncOps(clinicName: () => 'عيادة الاختبار'),
      clinicName: () => 'عيادة الاختبار',
    );
    await server.start(port: 0, discovery: false);
  });

  tearDownAll(() async {
    await server.stop();
    await ClinicDataDatabase.instance.closeActive();
  });

  Future<LanSyncClient> pairWith(DevicePreset preset, String name) async {
    final session = server.openPairing(preset);
    final connection = await LanSyncClient.pair(
      host: '127.0.0.1',
      port: server.port!,
      code: session.code,
      deviceName: name,
    );
    return LanSyncClient(connection);
  }

  test('crypto round-trips and rejects the wrong key', () async {
    final key = SyncCrypto.randomKey();
    final enc = await SyncCrypto.encrypt(key, 'مريض سري');
    expect(enc, isNot(contains('مريض')));
    expect(await SyncCrypto.decrypt(key, enc), 'مريض سري');
    expect(
      () => SyncCrypto.decrypt(SyncCrypto.randomKey(), enc),
      throwsA(anything),
    );
  });

  test(
    'a wrong pairing code is refused and five misses close the window',
    () async {
      final session = server.openPairing(DevicePreset.secretary);
      for (var i = 0; i < 5; i++) {
        await expectLater(
          LanSyncClient.pair(
            host: '127.0.0.1',
            port: server.port!,
            code: '000000',
            deviceName: 'x',
          ),
          throwsA(isA<SyncClientException>()),
        );
      }
      expect(server.pairing, isNull);
      await expectLater(
        LanSyncClient.pair(
          host: '127.0.0.1',
          port: server.port!,
          code: session.code,
          deviceName: 'x',
        ),
        throwsA(isA<SyncClientException>()),
      );
    },
  );

  test(
    'a paired secretary registers a patient, books and collects; the doctor side sees it',
    () async {
      final sec = await pairWith(DevicePreset.secretary, 'آيباد السكرتيرة');
      final info = await sec.call('session.info') as Map;
      expect(info['clinic'], 'عيادة الاختبار');
      expect(info['permissions'], contains('collectPayments'));

      final created =
          await sec.call('patients.create', {
                'name': 'سارة أحمد',
                'phone': '0911111111',
                'age': 30,
              })
              as Map;
      expect(created['name'], 'سارة أحمد');
      final id = created['id'] as int;

      final found = await sec.call('patients.search', {'q': 'سارة'}) as List;
      expect(found.any((p) => (p as Map)['id'] == id), true);
      // Reception sees no medical record fields.
      expect((found.first as Map).containsKey('allergies'), false);

      final at = DateTime.now().add(const Duration(days: 1));
      final appt =
          await sec.call('appointments.create', {
                'patientId': id,
                'at': at.toIso8601String(),
              })
              as Map;
      expect(appt['status'], 'scheduled');
      final dup = sec.call('appointments.create', {
        'patientId': id,
        'at': at.toIso8601String(),
      });
      await expectLater(
        dup,
        throwsA(
          predicate((e) => e is SyncClientException && e.code == 'conflict'),
        ),
      );
      final updated =
          await sec.call('appointments.setStatus', {
                'id': appt['id'],
                'status': 'completed',
              })
              as Map;
      expect(updated['status'], 'completed');

      // It really is in the doctor's database.
      final db = await ClinicDataDatabase.instance.database;
      final row = await db.query('patients', where: 'id = ?', whereArgs: [id]);
      expect(row.single['full_name'], 'سارة أحمد');
      final log = await db.query('activity_log');
      expect(log.map((r) => r['actor_name']), contains('آيباد السكرتيرة'));
    },
  );

  test(
    'a nurse without payment permission is refused on the doctor device',
    () async {
      final nurse = await pairWith(DevicePreset.nurse, 'آيباد الممرضة');
      await expectLater(
        nurse.call('payments.debts'),
        throwsA(predicate((e) => e is SyncClientException && e.isForbidden)),
      );
      expect(await nurse.call('patients.search', {'q': ''}), isA<List>());
    },
  );

  test('the doctor can change permissions and revoke a device', () async {
    final dev = await pairWith(DevicePreset.viewer, 'عرض');
    await expectLater(
      dev.call('patients.create', {'name': 'ن'}),
      throwsA(isA<SyncClientException>()),
    );
    await DeviceRegistry.instance.setPermissions(dev.connection.deviceId, {
      SyncPermission.viewPatients,
      SyncPermission.registerPatients,
    });
    final made =
        await dev.call('patients.create', {'name': 'مريض جديد'}) as Map;
    expect(made['name'], 'مريض جديد');

    await DeviceRegistry.instance.remove(dev.connection.deviceId);
    await expectLater(
      dev.call('patients.search', {'q': ''}),
      throwsA(
        predicate((e) => e is SyncClientException && e.code == 'unpaired'),
      ),
    );
  });

  test('a replayed request is rejected', () async {
    final sec = await pairWith(DevicePreset.secretary, 'مكرر');
    final c = sec.connection;
    final payload = jsonEncode({
      'ts': DateTime.now().millisecondsSinceEpoch,
      'n': 'fixed-nonce',
      'op': 'session.info',
      'args': <String, dynamic>{},
    });
    final enc = await SyncCrypto.encrypt(c.key, payload);
    Future<Map<String, dynamic>> send() async {
      final client = HttpClient();
      final req = await client.postUrl(
        Uri.parse('http://127.0.0.1:${server.port}/rpc'),
      );
      req.headers.contentType = ContentType.json;
      req.headers.set('x-device', c.deviceId);
      req.write(jsonEncode({'d': enc}));
      final res = await req.close();
      final body =
          jsonDecode(await utf8.decoder.bind(res).join())
              as Map<String, dynamic>;
      client.close();
      return jsonDecode(await SyncCrypto.decrypt(c.key, body['d'] as String))
          as Map<String, dynamic>;
    }

    expect((await send())['ok'], true);
    final second = await send();
    expect(second['ok'], false);
    expect(second['code'], 'replay');
  });
}

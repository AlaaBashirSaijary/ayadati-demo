import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'lan_sync_server.dart';
import 'sync_crypto.dart';

class SyncClientException implements Exception {
  SyncClientException(this.message, {this.code = 'error'});

  final String message;
  final String code;

  bool get isForbidden => code == 'forbidden';

  @override
  String toString() => message;
}

class FoundHost {
  const FoundHost({
    required this.address,
    required this.port,
    required this.clinic,
  });

  final String address;
  final int port;
  final String clinic;
}

/// What the secretary's tablet remembers about the doctor's device.
class SyncConnection {
  const SyncConnection({
    required this.host,
    required this.port,
    required this.deviceId,
    required this.secret,
    required this.clinic,
  });

  final String host;
  final int port;
  final String deviceId;
  final String secret;
  final String clinic;

  List<int> get key => base64Decode(secret);

  static const _prefKey = 'lan_sync.connection';

  Map<String, dynamic> toJson() => {
    'host': host,
    'port': port,
    'deviceId': deviceId,
    'secret': secret,
    'clinic': clinic,
  };

  static SyncConnection fromJson(Map<String, dynamic> j) => SyncConnection(
    host: j['host'] as String,
    port: j['port'] as int,
    deviceId: j['deviceId'] as String,
    secret: j['secret'] as String,
    clinic: j['clinic'] as String,
  );

  static Future<SyncConnection?> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_prefKey);
    return raw == null
        ? null
        : fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save() async => (await SharedPreferences.getInstance())
      .setString(_prefKey, jsonEncode(toJson()));

  static Future<void> clear() async =>
      (await SharedPreferences.getInstance()).remove(_prefKey);
}

/// The secretary/nurse tablet's side: finds the doctor's device, pairs with
/// the code, then sends encrypted operations to it.
class LanSyncClient {
  LanSyncClient(this.connection);

  final SyncConnection connection;

  static const _timeout = Duration(seconds: 8);

  /// Looks for doctor devices on the Wi-Fi for a couple of seconds.
  static Future<List<FoundHost>> discover({
    Duration wait = const Duration(seconds: 2),
  }) async {
    final found = <String, FoundHost>{};
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final d = socket?.receive();
        if (d == null) return;
        try {
          final j = jsonDecode(utf8.decode(d.data)) as Map<String, dynamic>;
          if (j['app'] == 'ayadati') {
            found[d.address.address] = FoundHost(
              address: d.address.address,
              port: j['port'] as int,
              clinic: (j['clinic'] as String?) ?? '',
            );
          }
        } catch (_) {}
      });
      socket.send(
        utf8.encode('AYADATI_DISCOVER'),
        InternetAddress('255.255.255.255'),
        LanSyncServer.discoveryPort,
      );
      await Future<void>.delayed(wait);
    } catch (_) {
      // No broadcast on this network — the user can type the address.
    } finally {
      socket?.close();
    }
    return found.values.toList();
  }

  static Future<Map<String, dynamic>> _post(
    String host,
    int port,
    String path,
    Map<String, dynamic> body, {
    Map<String, String> headers = const {},
  }) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.postUrl(
        Uri(scheme: 'http', host: host, port: port, path: path),
      );
      request.headers.contentType = ContentType.json;
      headers.forEach(request.headers.set);
      request.write(jsonEncode(body));
      final response = await request.close().timeout(_timeout);
      final text = await utf8.decoder.bind(response).join();
      return {'status': response.statusCode, 'body': jsonDecode(text)};
    } on SocketException {
      throw SyncClientException(
        'تعذّر الوصول لجهاز الطبيب. تأكد أنه على نفس شبكة الواي فاي والتطبيق مفتوح عليه.',
        code: 'unreachable',
      );
    } on TimeoutException {
      throw SyncClientException(
        'انتهت مهلة الاتصال بجهاز الطبيب.',
        code: 'unreachable',
      );
    } finally {
      client.close(force: true);
    }
  }

  /// Pairs with the doctor's device using the code shown there.
  static Future<SyncConnection> pair({
    required String host,
    required int port,
    required String code,
    required String deviceName,
  }) async {
    final r = await _post(host, port, '/pair', {
      'code': code.trim(),
      'name': deviceName,
    });
    final body = r['body'] as Map<String, dynamic>;
    if (r['status'] != 200) {
      throw SyncClientException(
        (body['error'] as String?) ?? 'تعذّر الربط.',
        code: 'pair_failed',
      );
    }
    return SyncConnection(
      host: host,
      port: port,
      deviceId: body['deviceId'] as String,
      secret: body['secret'] as String,
      clinic: (body['clinic'] as String?) ?? '',
    );
  }

  /// Runs [op] on the doctor's device and returns its result.
  Future<Object?> call(
    String op, [
    Map<String, dynamic> args = const {},
  ]) async {
    final payload = jsonEncode({
      'ts': DateTime.now().millisecondsSinceEpoch,
      'n': SyncCrypto.randomToken(12),
      'op': op,
      'args': args,
    });
    final enc = await SyncCrypto.encrypt(connection.key, payload);
    final r = await _post(
      connection.host,
      connection.port,
      '/rpc',
      {'d': enc},
      headers: {'x-device': connection.deviceId},
    );
    final body = r['body'] as Map<String, dynamic>;
    if (r['status'] == 401) {
      throw SyncClientException(
        'هذا الجهاز لم يعد مرتبطًا بجهاز الطبيب. اربطه من جديد.',
        code: 'unpaired',
      );
    }
    final reply =
        jsonDecode(
              await SyncCrypto.decrypt(connection.key, body['d'] as String),
            )
            as Map<String, dynamic>;
    if (reply['ok'] != true) {
      throw SyncClientException(
        (reply['error'] as String?) ?? 'تعذّر تنفيذ العملية.',
        code: (reply['code'] as String?) ?? 'error',
      );
    }
    return reply['data'];
  }
}

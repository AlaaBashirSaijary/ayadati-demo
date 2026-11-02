import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/paired_device.dart';
import '../domain/sync_permissions.dart';
import 'device_registry.dart';
import 'sync_crypto.dart';
import 'sync_ops.dart';

/// A one-time code the doctor reads out to the person pairing a tablet.
class PairingSession {
  PairingSession({
    required this.code,
    required this.expiresAt,
    required this.preset,
  });

  final String code;
  final DateTime expiresAt;
  final DevicePreset preset;
  int failedAttempts = 0;

  bool get isOpen => DateTime.now().isBefore(expiresAt) && failedAttempts < 5;
}

/// The doctor's device, listening on the clinic's Wi-Fi for the
/// secretary/nurse tablets: `/hello` (who are you), `/pair` (one-time code ->
/// secret) and `/rpc` (encrypted operations). It only works while the app is
/// open on this device, and everything but `/hello` needs either the pairing
/// code or a paired device's key.
class LanSyncServer {
  LanSyncServer({
    required this.ops,
    required this.clinicName,
    DeviceRegistry? registry,
  }) : registry = registry ?? DeviceRegistry.instance;

  static const defaultPort = 48721;
  static const discoveryPort = 48722;
  static const _discoverMessage = 'AYADATI_DISCOVER';

  final SyncOps ops;
  final String Function() clinicName;
  final DeviceRegistry registry;

  HttpServer? _http;
  RawDatagramSocket? _udp;
  PairingSession? _pairing;
  final _seenNonces = <String, DateTime>{};

  bool get isRunning => _http != null;
  int? get port => _http?.port;
  PairingSession? get pairing => (_pairing?.isOpen ?? false) ? _pairing : null;

  Future<void> start({int port = defaultPort, bool discovery = true}) async {
    if (_http != null) return;
    _http = await HttpServer.bind(InternetAddress.anyIPv4, port);
    unawaited(_serve(_http!));
    if (discovery) {
      try {
        _udp = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          discoveryPort,
          reuseAddress: true,
        );
        _udp!.listen((event) {
          if (event != RawSocketEvent.read) return;
          final d = _udp?.receive();
          if (d == null ||
              utf8.decode(d.data, allowMalformed: true) != _discoverMessage) {
            return;
          }
          final reply = utf8.encode(
            jsonEncode({
              'app': 'ayadati',
              'clinic': clinicName(),
              'port': _http?.port,
            }),
          );
          _udp?.send(reply, d.address, d.port);
        });
      } catch (_) {
        // Discovery is a convenience; typing the address still works.
      }
    }
  }

  Future<void> stop() async {
    await _http?.close(force: true);
    _udp?.close();
    _http = null;
    _udp = null;
    _pairing = null;
  }

  /// Opens a 5-minute window in which a tablet can pair with the returned
  /// code, getting [preset]'s permissions to start with.
  PairingSession openPairing(DevicePreset preset) {
    final code = (100000 + SyncCrypto.randomNumber(900000)).toString();
    return _pairing = PairingSession(
      code: code,
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      preset: preset,
    );
  }

  void closePairing() => _pairing = null;

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      unawaited(_handle(request));
    }
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      final path = request.uri.path;
      if (request.method == 'GET' && path == '/hello') {
        return _json(request, 200, {
          'app': 'ayadati',
          'clinic': clinicName(),
          'v': 1,
        });
      }
      if (request.method == 'POST' && path == '/pair') {
        return await _pair(request);
      }
      if (request.method == 'POST' && path == '/rpc') {
        return await _rpc(request);
      }
      return _json(request, 404, {'error': 'not_found'});
    } catch (_) {
      return _json(request, 500, {'error': 'server_error'});
    }
  }

  Future<Map<String, dynamic>> _readJson(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    if (body.length > 200000) throw const FormatException('too large');
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Future<void> _pair(HttpRequest request) async {
    final session = pairing;
    if (session == null) {
      return _json(request, 403, {
        'error': 'لا توجد جلسة ربط مفتوحة على جهاز الطبيب.',
      });
    }
    final body = await _readJson(request);
    if ((body['code'] as String?) != session.code) {
      session.failedAttempts++;
      return _json(request, 403, {'error': 'رمز الربط غير صحيح.'});
    }
    final name = ((body['name'] as String?) ?? '').trim();
    final device = PairedDevice(
      id: SyncCrypto.randomToken(),
      name: name.isEmpty ? 'جهاز مرتبط' : name,
      secret: base64Encode(SyncCrypto.randomKey()),
      permissions: {...session.preset.permissions},
      createdAt: DateTime.now(),
    );
    await registry.add(device);
    _pairing = null; // single use
    return _json(request, 200, {
      'deviceId': device.id,
      'secret': device.secret,
      'clinic': clinicName(),
      'permissions': device.permissions.map((p) => p.name).toList(),
    });
  }

  Future<void> _rpc(HttpRequest request) async {
    final deviceId = request.headers.value('x-device');
    final device = deviceId == null ? null : await registry.find(deviceId);
    if (device == null) {
      return _json(request, 401, {'error': 'unknown_device'});
    }
    Map<String, dynamic> call;
    try {
      final envelope = await _readJson(request);
      call =
          jsonDecode(
                await SyncCrypto.decrypt(device.key, envelope['d'] as String),
              )
              as Map<String, dynamic>;
    } catch (_) {
      return _json(request, 401, {'error': 'bad_request'});
    }

    // Replay protection: a recent timestamp and a nonce never seen before.
    final ts = DateTime.fromMillisecondsSinceEpoch(call['ts'] as int);
    final nonce = '${device.id}:${call['n']}';
    final now = DateTime.now();
    _seenNonces.removeWhere((_, t) => now.difference(t).inMinutes > 5);
    if (now.difference(ts).abs().inSeconds > 120 ||
        _seenNonces.containsKey(nonce)) {
      return _reply(request, device, {
        'ok': false,
        'error': 'طلب قديم أو مكرر.',
        'code': 'replay',
      });
    }
    _seenNonces[nonce] = now;

    final op = call['op'] as String;
    if (!syncOpPermissions.containsKey(op)) {
      return _reply(request, device, {
        'ok': false,
        'error': 'عملية غير معروفة.',
        'code': 'unknown_op',
      });
    }
    final needed = syncOpPermissions[op];
    if (needed != null && !device.permissions.contains(needed)) {
      return _reply(request, device, {
        'ok': false,
        'error': 'ليست لديك صلاحية: ${needed.label}.',
        'code': 'forbidden',
      });
    }
    try {
      final data = await ops.run(
        op,
        Map<String, dynamic>.from(call['args'] as Map? ?? {}),
        device,
      );
      unawaited(registry.touch(device.id));
      return _reply(request, device, {'ok': true, 'data': data});
    } on SyncOpException catch (e) {
      return _reply(request, device, {
        'ok': false,
        'error': e.message,
        'code': e.code,
      });
    } catch (_) {
      return _reply(request, device, {
        'ok': false,
        'error': 'تعذّر تنفيذ العملية على جهاز الطبيب.',
        'code': 'error',
      });
    }
  }

  Future<void> _reply(
    HttpRequest request,
    PairedDevice device,
    Map<String, dynamic> payload,
  ) async {
    final enc = await SyncCrypto.encrypt(device.key, jsonEncode(payload));
    return _json(request, 200, {'d': enc});
  }

  Future<void> _json(
    HttpRequest request,
    int status,
    Map<String, dynamic> body,
  ) async {
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await request.response.close();
  }
}

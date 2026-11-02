import 'dart:convert';

import 'sync_permissions.dart';

/// A tablet the doctor has paired. [secret] (base64) is the key both sides
/// use to encrypt requests; it never travels again after pairing.
class PairedDevice {
  PairedDevice({
    required this.id,
    required this.name,
    required this.secret,
    required this.permissions,
    required this.createdAt,
    this.lastSeen,
  });

  final String id;
  final String name;
  final String secret;
  final Set<SyncPermission> permissions;
  final DateTime createdAt;
  DateTime? lastSeen;

  List<int> get key => base64Decode(secret);

  PairedDevice copyWith({
    Set<SyncPermission>? permissions,
    DateTime? lastSeen,
  }) => PairedDevice(
    id: id,
    name: name,
    secret: secret,
    permissions: permissions ?? this.permissions,
    createdAt: createdAt,
    lastSeen: lastSeen ?? this.lastSeen,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'secret': secret,
    'permissions': permissions.map((p) => p.name).toList(),
    'createdAt': createdAt.toIso8601String(),
    'lastSeen': lastSeen?.toIso8601String(),
  };

  factory PairedDevice.fromJson(Map<String, dynamic> j) => PairedDevice(
    id: j['id'] as String,
    name: j['name'] as String,
    secret: j['secret'] as String,
    permissions: {
      for (final n in (j['permissions'] as List))
        ?SyncPermission.fromName(n as String),
    },
    createdAt: DateTime.parse(j['createdAt'] as String),
    lastSeen: j['lastSeen'] == null
        ? null
        : DateTime.parse(j['lastSeen'] as String),
  );
}

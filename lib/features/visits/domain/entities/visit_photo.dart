import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// A photo attached to a visit — an eye photo, a photocopy of an old
/// prescription, anything the doctor wants on file alongside the exam.
/// Stored as a BLOB in the same SQLite file as everything else (see
/// ClinicDataDatabase) so it travels with the clinic's regular
/// backup/restore instead of needing a separate folder kept in sync.
class VisitPhoto extends Equatable {
  const VisitPhoto({
    this.id,
    required this.visitId,
    required this.imageData,
    this.createdAt,
  });

  final int? id;
  final int visitId;
  final Uint8List imageData;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [id, visitId, createdAt];
}

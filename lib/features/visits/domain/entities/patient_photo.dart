import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// A single photo attached to one of a patient's visits, carried alongside
/// the visit date it belongs to — the flat shape [PhotoComparisonPage] needs
/// to lay out every photo across a patient's whole history in one grid and
/// let the doctor pick any two to compare, without re-fetching per visit.
class PatientPhoto extends Equatable {
  const PatientPhoto({
    required this.id,
    required this.visitId,
    required this.visitDate,
    required this.imageData,
  });

  final int id;
  final int visitId;
  final DateTime visitDate;
  final Uint8List imageData;

  @override
  List<Object?> get props => [id, visitId, visitDate];
}

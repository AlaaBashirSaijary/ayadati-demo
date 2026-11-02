import 'package:equatable/equatable.dart';

import 'prescription_item.dart';

/// A doctor's printed prescription for a patient — kept as its own record
/// (see ClinicDataDatabase's prescriptions table doc comment) so it can be
/// reprinted or reviewed later without reopening the exam visit it may
/// have come from.
class Prescription extends Equatable {
  const Prescription({
    this.id,
    required this.patientId,
    this.visitId,
    this.doctorId,
    required this.items,
    this.notes,
    this.createdAt,
  });

  final int? id;
  final int patientId;
  final int? visitId;
  final int? doctorId;
  final List<PrescriptionItem> items;
  final String? notes;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [id, patientId, visitId, doctorId, items, notes];
}

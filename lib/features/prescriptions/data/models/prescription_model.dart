import 'dart:convert';

import '../../domain/entities/prescription.dart';
import '../../domain/entities/prescription_item.dart';

class PrescriptionModel extends Prescription {
  const PrescriptionModel({
    super.id,
    required super.patientId,
    super.visitId,
    super.doctorId,
    required super.items,
    super.notes,
    super.createdAt,
  });

  factory PrescriptionModel.fromEntity(Prescription p) => PrescriptionModel(
    id: p.id,
    patientId: p.patientId,
    visitId: p.visitId,
    doctorId: p.doctorId,
    items: p.items,
    notes: p.notes,
    createdAt: p.createdAt,
  );

  factory PrescriptionModel.fromMap(Map<String, Object?> map) {
    final rawItems = jsonDecode(map['items_json']! as String) as List<dynamic>;
    return PrescriptionModel(
      id: map['id'] as int?,
      patientId: map['patient_id']! as int,
      visitId: map['visit_id'] as int?,
      doctorId: map['doctor_id'] as int?,
      items: rawItems
          .cast<Map<String, dynamic>>()
          .map(
            (item) => PrescriptionItem(
              drugName: item['drug_name']! as String,
              dosage: item['dosage'] as String?,
              frequency: item['frequency'] as String?,
              duration: item['duration'] as String?,
              notes: item['notes'] as String?,
            ),
          )
          .toList(),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at']! as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'patient_id': patientId,
      'visit_id': visitId,
      'doctor_id': doctorId,
      'items_json': jsonEncode([
        for (final item in items)
          {
            'drug_name': item.drugName,
            'dosage': item.dosage,
            'frequency': item.frequency,
            'duration': item.duration,
            'notes': item.notes,
          },
      ]),
      'notes': notes,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }
}

import 'package:clinic_manager_flutter/features/visits/domain/entities/exam_field_template.dart';
import 'package:clinic_manager_flutter/features/visits/domain/entities/specialty_preset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every preset has unique ids, labels and at least one field', () {
    expect(
      specialtyPresets.map((p) => p.id).toSet().length,
      specialtyPresets.length,
    );
    for (final p in specialtyPresets) {
      expect(p.fields, isNotEmpty, reason: p.name);
      final labels = p.fields.map((f) => f.label.trim().toLowerCase());
      expect(
        labels.toSet().length,
        labels.length,
        reason: '${p.name} has duplicate labels',
      );
    }
  });

  test(
    'missingFrom skips fields already on the form, ignoring case and spaces',
    () {
      final eyes = specialtyPresets.firstWhere((p) => p.id == 'eyes');
      final existing = [
        const ExamFieldTemplate(id: 1, label: ' auto '),
        const ExamFieldTemplate(id: 2, label: 'Lens'),
      ];
      final missing = eyes.missingFrom(existing).map((f) => f.label).toList();
      expect(missing.contains('Auto'), false);
      expect(missing.contains('Lens'), false);
      expect(missing.contains('IOP'), true);
      expect(eyes.missingFrom(const []).length, eyes.fields.length);
    },
  );
}

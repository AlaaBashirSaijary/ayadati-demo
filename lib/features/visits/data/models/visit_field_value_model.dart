import '../../domain/entities/visit_field_value.dart';

class VisitFieldValueModel extends VisitFieldValue {
  const VisitFieldValueModel({
    super.id,
    required super.visitId,
    required super.templateId,
    super.side,
    super.value,
  });

  factory VisitFieldValueModel.fromMap(Map<String, Object?> map) =>
      VisitFieldValueModel(
        id: map['id']! as int,
        visitId: map['visit_id']! as int,
        templateId: map['template_id']! as int,
        side: FieldSide.fromValue(map['side']! as String),
        value: map['value'] as String?,
      );

  Map<String, Object?> toMap() {
    return {
      'visit_id': visitId,
      'template_id': templateId,
      'side': side.name,
      'value': value,
    };
  }
}

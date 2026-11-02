import '../../domain/entities/exam_field_template.dart';

class ExamFieldTemplateModel extends ExamFieldTemplate {
  const ExamFieldTemplateModel({
    super.id,
    required super.label,
    super.hasSides,
    super.isLongText,
    super.sortOrder,
  });

  factory ExamFieldTemplateModel.fromMap(Map<String, Object?> map) =>
      ExamFieldTemplateModel(
        id: map['id']! as int,
        label: map['label']! as String,
        hasSides: (map['has_sides']! as int) == 1,
        isLongText: (map['is_long_text']! as int) == 1,
        sortOrder: map['sort_order']! as int,
      );

  Map<String, Object?> toMap() {
    return {
      'label': label,
      'has_sides': hasSides ? 1 : 0,
      'is_long_text': isLongText ? 1 : 0,
      'sort_order': sortOrder,
    };
  }
}

import 'package:equatable/equatable.dart';

/// Which reading a value represents, for a template with [ExamFieldTemplate.
/// hasSides] true — meaningless (always [single]) for an unpaired field.
enum FieldSide {
  single,
  right,
  left;

  static FieldSide fromValue(String value) => FieldSide.values.firstWhere(
    (s) => s.name == value,
    orElse: () => FieldSide.single,
  );
}

/// One entered reading for one visit against one [ExamFieldTemplate] row.
class VisitFieldValue extends Equatable {
  const VisitFieldValue({
    this.id,
    required this.visitId,
    required this.templateId,
    this.side = FieldSide.single,
    this.value,
  });

  final int? id;
  final int visitId;
  final int templateId;
  final FieldSide side;
  final String? value;

  @override
  List<Object?> get props => [id, visitId, templateId, side, value];
}

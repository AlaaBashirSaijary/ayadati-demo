import 'package:equatable/equatable.dart';

/// One row of the clinic's own exam form — e.g. "ضغط الدم" for a general
/// clinic, or "Auto" for an eye clinic. Doctors define these themselves
/// (Admin > قوالب الفحص) instead of the app assuming any one specialty.
class ExamFieldTemplate extends Equatable {
  const ExamFieldTemplate({
    this.id,
    required this.label,
    this.hasSides = false,
    this.isLongText = false,
    this.sortOrder = 0,
  });

  final int? id;
  final String label;

  /// True when this row records two readings (e.g. right/left eye, right/
  /// left ear) instead of one.
  final bool hasSides;

  /// True for a row that holds a descriptive finding rather than a short
  /// number (e.g. "Anter.S") — its input gets a multi-line box instead of
  /// the single-line field every other row uses.
  final bool isLongText;

  final int sortOrder;

  ExamFieldTemplate copyWith({
    int? id,
    String? label,
    bool? hasSides,
    bool? isLongText,
    int? sortOrder,
  }) {
    return ExamFieldTemplate(
      id: id ?? this.id,
      label: label ?? this.label,
      hasSides: hasSides ?? this.hasSides,
      isLongText: isLongText ?? this.isLongText,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  List<Object?> get props => [id, label, hasSides, isLongText, sortOrder];
}

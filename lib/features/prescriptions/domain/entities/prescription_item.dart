import 'package:equatable/equatable.dart';

/// One medication line on a prescription — drugName is the only field a
/// doctor must fill in; everything else is exactly as free-form as it
/// would be on a paper pad.
class PrescriptionItem extends Equatable {
  const PrescriptionItem({
    required this.drugName,
    this.dosage,
    this.frequency,
    this.duration,
    this.notes,
  });

  final String drugName;
  final String? dosage;
  final String? frequency;
  final String? duration;
  final String? notes;

  @override
  List<Object?> get props => [drugName, dosage, frequency, duration, notes];
}

import 'package:equatable/equatable.dart';

/// The result of running an import batch — shown as the final "تم" screen
/// so the doctor knows exactly what happened to every row, not just a bare
/// success message.
class ImportSummary extends Equatable {
  const ImportSummary({
    this.imported = 0,
    this.duplicatesSkipped = 0,
    this.failed = 0,
  });

  final int imported;
  final int duplicatesSkipped;
  final int failed;

  int get total => imported + duplicatesSkipped + failed;

  ImportSummary copyWith({int? imported, int? duplicatesSkipped, int? failed}) {
    return ImportSummary(
      imported: imported ?? this.imported,
      duplicatesSkipped: duplicatesSkipped ?? this.duplicatesSkipped,
      failed: failed ?? this.failed,
    );
  }

  @override
  List<Object?> get props => [imported, duplicatesSkipped, failed];
}

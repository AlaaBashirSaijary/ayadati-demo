import 'package:equatable/equatable.dart';

/// The raw shape of a picked spreadsheet before any column mapping is
/// applied — [headers] is the first row, [rows] is every row after it, each
/// cell already stringified so the presentation layer never touches the
/// underlying xlsx/csv types.
class ParsedSheet extends Equatable {
  const ParsedSheet({required this.headers, required this.rows});

  final List<String> headers;
  final List<List<String?>> rows;

  @override
  List<Object?> get props => [headers, rows];
}

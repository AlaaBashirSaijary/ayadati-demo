import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xls;

import '../domain/entities/parsed_sheet.dart';

/// Turns a picked .xlsx or .csv file's bytes into a plain [ParsedSheet] —
/// the presentation layer never touches the excel/csv package types
/// directly, so swapping either library later stays a one-file change.
class SpreadsheetParser {
  const SpreadsheetParser._();

  static ParsedSheet parse(Uint8List bytes, String fileName) {
    final isCsv = fileName.toLowerCase().endsWith('.csv');
    return isCsv ? _parseCsv(bytes) : _parseXlsx(bytes);
  }

  static ParsedSheet _parseXlsx(Uint8List bytes) {
    final workbook = xls.Excel.decodeBytes(bytes);
    if (workbook.tables.isEmpty) {
      return const ParsedSheet(headers: [], rows: []);
    }
    final sheet = workbook.tables[workbook.tables.keys.first]!;
    final rows = sheet.rows
        .map((row) => row.map((cell) => cell?.value?.toString()).toList())
        .where((row) => row.any((cell) => (cell ?? '').trim().isNotEmpty))
        .toList();

    if (rows.isEmpty) return const ParsedSheet(headers: [], rows: []);

    final headers = rows.first.map((h) => (h ?? '').trim()).toList();
    return ParsedSheet(headers: headers, rows: rows.skip(1).toList());
  }

  static ParsedSheet _parseCsv(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final rawRows =
        const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
            .convert(text)
            .map((row) => row.map((cell) => cell?.toString()).toList())
            .where((row) => row.any((cell) => (cell ?? '').trim().isNotEmpty))
            .toList();

    if (rawRows.isEmpty) return const ParsedSheet(headers: [], rows: []);

    final headers = rawRows.first.map((h) => (h ?? '').trim()).toList();
    return ParsedSheet(headers: headers, rows: rawRows.skip(1).toList());
  }
}

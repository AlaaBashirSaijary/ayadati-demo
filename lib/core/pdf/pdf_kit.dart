import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart' hide TextDirection;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Same brand palette as AppColors (core/theme/app_theme.dart), reexpressed
/// as PdfColor — the `pdf` package can't consume Flutter's Color directly.
class PdfBrand {
  const PdfBrand._();

  static const ink = PdfColor.fromInt(0xFF0A2540);
  static const inkSoft = PdfColor.fromInt(0xFF3D5A73);
  static const sky = PdfColor.fromInt(0xFFE7F3F8);
  static const aqua = PdfColor.fromInt(0xFF1287A0);
  static const aquaDeep = PdfColor.fromInt(0xFF0B6073);
}

/// Loads the same IBM Plex Sans Arabic family the app itself uses (see
/// pubspec.yaml) so an exported PDF reads as the same product instead of
/// falling back to the `pdf` package's default Latin-only font, which
/// can't render Arabic glyphs at all.
class PdfKit {
  PdfKit._();

  static pw.Font? _regular;
  static pw.Font? _bold;

  static Future<void> _ensureFonts() async {
    if (_regular != null && _bold != null) return;
    final regularData = await rootBundle.load(
      'assets/fonts/ibm-plex-sans-arabic-arabic-400.ttf',
    );
    final boldData = await rootBundle.load(
      'assets/fonts/ibm-plex-sans-arabic-arabic-700.ttf',
    );
    _regular = pw.Font.ttf(regularData);
    _bold = pw.Font.ttf(boldData);
  }

  /// A ready-to-use RTL, Arabic-font pw.Document — every export builds on
  /// this instead of configuring theme/fonts/text direction by hand.
  static Future<pw.Document> newDocument() async {
    await _ensureFonts();
    return pw.Document(
      theme: pw.ThemeData.withFont(
        base: _regular!,
        bold: _bold!,
        // The bundled IBM Plex Sans Arabic file is an Arabic-only subset —
        // it has no glyphs for plain ASCII punctuation (":", ".", "%", "(",
        // ")", ...), which are common in this app's exported text (times,
        // amounts, percentages). Flutter's own text rendering falls back to
        // another font automatically for a missing glyph; the `pdf`
        // package doesn't, so without an explicit fallback those
        // characters render as tofu boxes instead of just being skipped.
        fontFallback: [pw.Font.helvetica(), pw.Font.helveticaBold()],
      ),
    );
  }

  /// Adds one RTL multi-page section to [document] — every export in the
  /// app is right-to-left, so this is the only way pages get added.
  static void addPage(pw.Document document, {required List<pw.Widget> build}) {
    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(28),
          textDirection: pw.TextDirection.rtl,
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.bottomCenter,
          child: pw.Text(
            'صفحة ${context.pageNumber} من ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 9, color: PdfBrand.inkSoft),
          ),
        ),
        build: (context) => build,
      ),
    );
  }

  static final _generatedAtFormat = DateFormat('yyyy/MM/dd - h:mm a', 'ar');

  /// The header block every export page starts with: clinic name, the
  /// document's own title, and when it was generated — so a printed page
  /// is self-identifying even once separated from the app.
  static pw.Widget header({
    required String clinicName,
    required String title,
    String? subtitle,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      margin: const pw.EdgeInsets.only(bottom: 16),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfBrand.aqua, width: 2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfBrand.ink,
                ),
              ),
              if (subtitle != null) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  subtitle,
                  style: pw.TextStyle(fontSize: 11, color: PdfBrand.inkSoft),
                ),
              ],
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                clinicName,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfBrand.aquaDeep,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'أُنشئ في ${_generatedAtFormat.format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 9, color: PdfBrand.inkSoft),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// A section title used to break up a document — e.g. "بيانات المريض"
  /// ahead of that section's fields.
  static pw.Widget sectionTitle(String text) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 14, bottom: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: PdfBrand.aquaDeep,
        ),
      ),
    );
  }

  /// A label/value row — the PDF equivalent of `_InfoCard`'s rows on the
  /// patient detail page.
  static pw.Widget labelValueRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfBrand.inkSoft,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 10.5)),
          ),
        ],
      ),
    );
  }

  /// Opens the platform print/export sheet (print, save as PDF, or share)
  /// for [document] — the one place every export in the app hands its
  /// finished document to the user, so behaviour stays consistent.
  static Future<void> present(pw.Document document, {required String name}) {
    return Printing.layoutPdf(
      name: name,
      onLayout: (format) => document.save(),
    );
  }
}

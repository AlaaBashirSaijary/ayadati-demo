import 'package:intl/intl.dart' hide TextDirection;
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/pdf/pdf_kit.dart';

/// Builds and presents (print/save/share) a one-page PDF of the monthly
/// report already shown on screen — same figures as MonthlyReportPage,
/// just handed over as a document instead of read off the app.
class MonthlyReportPdfExport {
  const MonthlyReportPdfExport._();

  static final _monthFormat = DateFormat('MMMM yyyy', 'ar');

  static Future<void> export({
    required String clinicName,
    required DateTime month,
    required int consultations,
    required int halfConsultations,
    required int followUps,
    required int newPatients,
  }) async {
    final document = await PdfKit.newDocument();

    PdfKit.addPage(
      document,
      build: [
        PdfKit.header(
          clinicName: clinicName,
          title: 'التقرير الشهري',
          subtitle: _monthFormat.format(month),
        ),
        pw.Table(
          border: pw.TableBorder.all(color: PdfBrand.sky, width: 1),
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FlexColumnWidth(1.2),
          },
          children: [
            _row('معاينات مدفوعة', consultations),
            _row('مراجعات بنصف السعر', halfConsultations),
            _row('مراجعات مجانية', followUps),
            _row('مرضى جدد', newPatients),
            _row(
              'إجمالي المواعيد',
              consultations + halfConsultations + followUps,
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          'لا تشمل هذه الأرقام المواعيد الملغاة. الكشفيات والمتابعات '
          'محسوبة حسب نوع الموعد وقت الحجز.',
          style: pw.TextStyle(fontSize: 9.5, color: PdfBrand.inkSoft),
        ),
      ],
    );

    await PdfKit.present(
      document,
      name: 'التقرير الشهري - ${_monthFormat.format(month)}',
    );
  }

  static pw.TableRow _row(String label, int value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 11,
              color: PdfBrand.ink,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: pw.Text(
            '$value',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 11,
              color: PdfBrand.aquaDeep,
            ),
          ),
        ),
      ],
    );
  }
}

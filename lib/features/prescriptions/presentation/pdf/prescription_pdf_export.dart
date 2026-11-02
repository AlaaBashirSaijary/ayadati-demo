import 'package:intl/intl.dart' hide TextDirection;
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/pdf/pdf_kit.dart';
import '../../domain/entities/prescription.dart';

/// A doctor's printed prescription — clinic letterhead, patient info, a
/// numbered medication list, and a signature line, ready to hand to the
/// patient the same way a paper Rx pad would.
class PrescriptionPdfExport {
  const PrescriptionPdfExport._();

  static final _dateFormat = DateFormat('yyyy/MM/dd');

  static Future<void> export({
    required String clinicName,
    required String doctorName,
    required String patientName,
    required int? patientAge,
    required Prescription prescription,
  }) async {
    final document = await PdfKit.newDocument();

    PdfKit.addPage(
      document,
      build: [
        PdfKit.header(
          clinicName: clinicName,
          title: 'وصفة طبية',
          subtitle: _dateFormat.format(
            prescription.createdAt ?? DateTime.now(),
          ),
        ),
        pw.Row(
          children: [
            pw.Expanded(child: PdfKit.labelValueRow('المريض', patientName)),
            if (patientAge != null)
              pw.Expanded(
                child: PdfKit.labelValueRow('العمر', '$patientAge سنة'),
              ),
          ],
        ),
        PdfKit.labelValueRow('الطبيب المعالج', doctorName),
        pw.SizedBox(height: 18),
        pw.Table(
          border: pw.TableBorder.all(color: PdfBrand.sky, width: 1),
          columnWidths: const {
            0: pw.FlexColumnWidth(0.6),
            1: pw.FlexColumnWidth(2.4),
            2: pw.FlexColumnWidth(1.4),
            3: pw.FlexColumnWidth(1.4),
            4: pw.FlexColumnWidth(1.2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfBrand.sky),
              children: [
                _headerCell('#'),
                _headerCell('الدواء'),
                _headerCell('الجرعة'),
                _headerCell('عدد المرات'),
                _headerCell('المدة'),
              ],
            ),
            for (final (index, item) in prescription.items.indexed)
              pw.TableRow(
                children: [
                  _cell('${index + 1}'),
                  _cell(item.drugName),
                  _cell(item.dosage ?? '—'),
                  _cell(item.frequency ?? '—'),
                  _cell(item.duration ?? '—'),
                ],
              ),
          ],
        ),
        if (prescription.items.any((i) => (i.notes ?? '').isNotEmpty)) ...[
          pw.SizedBox(height: 10),
          for (final item in prescription.items)
            if ((item.notes ?? '').isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(
                  '${item.drugName}: ${item.notes}',
                  style: pw.TextStyle(fontSize: 9.5, color: PdfBrand.inkSoft),
                ),
              ),
        ],
        if ((prescription.notes ?? '').isNotEmpty) ...[
          pw.SizedBox(height: 14),
          PdfKit.sectionTitle('ملاحظات'),
          pw.Text(
            prescription.notes!,
            style: const pw.TextStyle(fontSize: 10.5),
          ),
        ],
        pw.SizedBox(height: 50),
        pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(width: 140, height: 1, color: PdfBrand.inkSoft),
              pw.SizedBox(height: 4),
              pw.Text(
                'توقيع الطبيب',
                style: pw.TextStyle(fontSize: 9.5, color: PdfBrand.inkSoft),
              ),
            ],
          ),
        ),
      ],
    );

    await PdfKit.present(
      document,
      name:
          'وصفة طبية - $patientName - ${_dateFormat.format(prescription.createdAt ?? DateTime.now())}',
    );
  }

  static pw.Widget _headerCell(String text) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 10,
        color: PdfBrand.ink,
      ),
    ),
  );

  static pw.Widget _cell(String text) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 9.5)),
  );
}

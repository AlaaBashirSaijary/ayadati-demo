import 'package:intl/intl.dart' hide TextDirection;
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/pdf/pdf_kit.dart';
import '../../domain/entities/medical_certificate.dart';

/// A sick-leave note or general medical report — clinic letterhead,
/// patient info, the body text (or the fixed sick-leave sentence with the
/// number of rest days filled in), and a signature line.
class MedicalCertificatePdfExport {
  const MedicalCertificatePdfExport._();

  static final _dateFormat = DateFormat('yyyy/MM/dd');

  static Future<void> export({
    required String clinicName,
    required String doctorName,
    required String patientName,
    required int? patientAge,
    required MedicalCertificate certificate,
  }) async {
    final document = await PdfKit.newDocument();
    final date = certificate.createdAt ?? DateTime.now();

    PdfKit.addPage(
      document,
      build: [
        PdfKit.header(
          clinicName: clinicName,
          title: certificate.type.label,
          subtitle: _dateFormat.format(date),
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
        pw.SizedBox(height: 20),
        if (certificate.type == MedicalCertificateType.sickLeave &&
            certificate.restDays != null) ...[
          pw.Text(
            'يُرجى العلم أن المريض(ة) "$patientName" بحاجة لإجازة مرضية '
            'لمدة ${certificate.restDays} يوم اعتبارًا من '
            '${_dateFormat.format(date)}.',
            style: const pw.TextStyle(fontSize: 12, lineSpacing: 3),
          ),
          if (certificate.body.trim().isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text(certificate.body, style: const pw.TextStyle(fontSize: 11)),
          ],
        ] else
          pw.Text(
            certificate.body,
            style: const pw.TextStyle(fontSize: 12, lineSpacing: 3),
          ),
        pw.SizedBox(height: 60),
        pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(width: 140, height: 1, color: PdfBrand.inkSoft),
              pw.SizedBox(height: 4),
              pw.Text(
                'توقيع الطبيب وختم العيادة',
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
          '${certificate.type.label} - $patientName - ${_dateFormat.format(date)}',
    );
  }
}

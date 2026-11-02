import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/di/injection.dart';
import '../../../../core/pdf/pdf_kit.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../visits/domain/entities/exam_field_template.dart';
import '../../../visits/domain/entities/visit.dart';
import '../../../visits/domain/entities/visit_field_value.dart';
import '../../../visits/domain/usecases/get_exam_templates.dart';
import '../../../visits/domain/usecases/get_visit_field_values_for_visits.dart';
import '../../../visits/domain/usecases/get_visits.dart';
import '../../domain/entities/patient.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/error/error_messages.dart';

/// Builds and presents (print/save/share) a full printout of one patient's
/// إضبارة — their own fields plus every recorded exam visit — the offline
/// equivalent of handing over a photocopy of the paper chart.
class PatientPdfExport {
  const PatientPdfExport._();

  static final _dateFormat = DateFormat('yyyy/MM/dd');

  static Future<void> export({
    required Patient patient,
    required String clinicName,
  }) async {
    final visitsResult = await sl<GetVisits>().call(patient.id!);
    final visits = visitsResult.fold((_) => <Visit>[], (v) => v);

    final templatesResult = await sl<GetExamTemplates>().call(const NoParams());
    final templates = templatesResult.fold(
      (_) => <ExamFieldTemplate>[],
      (t) => t,
    );
    final templatesById = {
      for (final template in templates) template.id!: template,
    };

    final valuesResult = await sl<GetVisitFieldValuesForVisits>().call([
      for (final visit in visits) visit.id!,
    ]);
    final visitValues = valuesResult.fold(
      (_) => <int, List<VisitFieldValue>>{},
      (v) => v,
    );

    final document = await PdfKit.newDocument();

    PdfKit.addPage(
      document,
      build: [
        PdfKit.header(
          clinicName: clinicName,
          title: 'إضبارة المريض',
          subtitle: patient.fullName,
        ),
        PdfKit.sectionTitle('بيانات المريض'),
        PdfKit.labelValueRow('رقم المريض', patient.patientNumber ?? '—'),
        PdfKit.labelValueRow('الحالة', patient.statusLabel),
        PdfKit.labelValueRow('الجنس', patient.gender?.label ?? '—'),
        PdfKit.labelValueRow('الهاتف', patient.phone ?? '—'),
        PdfKit.labelValueRow('العنوان', patient.address ?? '—'),
        PdfKit.labelValueRow(
          'العمر',
          patient.displayAge != null ? '${patient.displayAge} سنة' : '—',
        ),
        PdfKit.labelValueRow(
          'تاريخ الميلاد',
          patient.birthDate == null
              ? '—'
              : _dateFormat.format(patient.birthDate!),
        ),
        PdfKit.sectionTitle('الشكاية'),
        pw.Text(
          patient.diagnosis?.isNotEmpty == true
              ? patient.diagnosis!
              : 'غير محدد',
        ),
        for (final (title, value) in [
          ('الأدوية السابقة', patient.previousMedications),
          ('الأدوية الحالية', patient.currentMedications),
          ('الحساسية', patient.allergies),
          ('التاريخ المرضي', patient.medicalHistory),
          ('عمليات سابقة', patient.surgeriesHistory),
          ('ملاحظات إضافية', patient.notes),
        ])
          if (value != null && value.isNotEmpty) ...[
            PdfKit.sectionTitle(title),
            pw.Text(value),
          ],
        PdfKit.sectionTitle('زيارات الفحص'),
        if (visits.isEmpty)
          pw.Text(
            'لا توجد زيارات مسجّلة.',
            style: const pw.TextStyle(fontSize: 10.5),
          )
        else
          for (final visit in visits)
            _visitBlock(visit, templatesById, visitValues[visit.id!] ?? []),
      ],
    );

    await PdfKit.present(document, name: 'إضبارة ${patient.fullName}');
  }

  static pw.Widget _visitBlock(
    Visit visit,
    Map<int, ExamFieldTemplate> templatesById,
    List<VisitFieldValue> values,
  ) {
    final byTemplate = <int, Map<FieldSide, String>>{};
    for (final value in values) {
      if (value.value == null || value.value!.isEmpty) continue;
      byTemplate.putIfAbsent(value.templateId, () => {})[value.side] =
          value.value!;
    }

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8, bottom: 4),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfBrand.sky, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            _dateFormat.format(visit.visitDate),
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfBrand.aquaDeep,
              fontSize: 11,
            ),
          ),
          if (byTemplate.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(
                'لا توجد قياسات مسجّلة لهذه الزيارة.',
                style: pw.TextStyle(fontSize: 9.5, color: PdfBrand.inkSoft),
              ),
            )
          else
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  for (final entry in byTemplate.entries)
                    if (templatesById[entry.key] != null)
                      pw.Text(
                        _readingText(templatesById[entry.key]!, entry.value),
                        style: const pw.TextStyle(fontSize: 9.5),
                      ),
                ],
              ),
            ),
          if (visit.notes != null && visit.notes!.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'ملاحظات: ${visit.notes}',
              style: pw.TextStyle(fontSize: 9.5, color: PdfBrand.inkSoft),
            ),
          ],
        ],
      ),
    );
  }

  static String _readingText(
    ExamFieldTemplate template,
    Map<FieldSide, String> readings,
  ) {
    if (template.hasSides) {
      final right = readings[FieldSide.right] ?? '—';
      final left = readings[FieldSide.left] ?? '—';
      return '${template.label}: يمين $right / يسار $left';
    }
    return '${template.label}: ${readings[FieldSide.single] ?? '—'}';
  }
}

/// Convenience button used by pages that want a one-tap "طباعة/تصدير PDF"
/// action for a patient's file — wraps [PatientPdfExport.export] with a
/// loading state and error surface so callers don't repeat that wiring.
class PatientPdfExportButton extends StatefulWidget {
  const PatientPdfExportButton({
    super.key,
    required this.patient,
    required this.clinicName,
  });

  final Patient patient;
  final String clinicName;

  @override
  State<PatientPdfExportButton> createState() => _PatientPdfExportButtonState();
}

class _PatientPdfExportButtonState extends State<PatientPdfExportButton> {
  bool _exporting = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await PatientPdfExport.export(
        patient: widget.patient,
        clinicName: widget.clinicName,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnack.error(context, friendlyMessage('تعذّر تصدير الملف', e));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'طباعة / تصدير PDF',
      onPressed: _exporting ? null : _export,
      icon: _exporting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.picture_as_pdf_rounded),
    );
  }
}

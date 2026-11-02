import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../patients/domain/entities/patient.dart';
import '../../data/spreadsheet_parser.dart';
import '../../domain/entities/import_field.dart';
import '../../domain/entities/import_summary.dart';
import '../../domain/entities/parsed_sheet.dart';
import '../../domain/usecases/import_patients.dart';

enum _ImportStep { pickFile, mapping, preview, done }

/// A four-step wizard: pick a .xlsx/.csv file → map its columns onto
/// patient fields (auto-guessed, editable) → preview what will be created
/// → import. Built as one page with local step state rather than a
/// provider, since nothing here needs to survive navigating away.
class PatientImportPage extends StatefulWidget {
  const PatientImportPage({super.key});

  @override
  State<PatientImportPage> createState() => _PatientImportPageState();
}

class _PatientImportPageState extends State<PatientImportPage> {
  _ImportStep _step = _ImportStep.pickFile;
  bool _busy = false;
  String? _error;

  String? _fileName;
  ParsedSheet? _sheet;
  final Map<ImportField, String?> _mapping = {};

  List<Patient> _drafts = const [];
  int _skippedEmptyRows = 0;
  ImportSummary? _summary;

  Future<void> _pickFile() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _busy = false);
        return;
      }
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() {
          _busy = false;
          _error = 'تعذّرت قراءة الملف.';
        });
        return;
      }

      final sheet = SpreadsheetParser.parse(bytes, file.name);
      if (sheet.headers.isEmpty) {
        setState(() {
          _busy = false;
          _error = 'الملف فارغ أو غير مقروء.';
        });
        return;
      }

      _mapping.clear();
      for (final field in ImportField.values) {
        _mapping[field] = _guessHeader(sheet.headers, field);
      }

      setState(() {
        _fileName = file.name;
        _sheet = sheet;
        _busy = false;
        _step = _ImportStep.mapping;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'تعذّر تحليل الملف: $e';
      });
    }
  }

  String? _guessHeader(List<String> headers, ImportField field) {
    for (final header in headers) {
      final normalized = header.trim().toLowerCase();
      for (final hint in field.headerHints) {
        if (normalized.contains(hint.toLowerCase())) return header;
      }
    }
    return null;
  }

  void _buildDrafts() {
    final sheet = _sheet!;
    String cell(List<String?> row, ImportField field) {
      final header = _mapping[field];
      if (header == null) return '';
      final index = sheet.headers.indexOf(header);
      if (index == -1 || index >= row.length) return '';
      return (row[index] ?? '').trim();
    }

    String? nullable(List<String?> row, ImportField field) {
      final value = cell(row, field);
      return value.isEmpty ? null : value;
    }

    final drafts = <Patient>[];
    var skipped = 0;

    for (final row in sheet.rows) {
      final fullName = cell(row, ImportField.fullName);
      if (fullName.isEmpty) {
        skipped++;
        continue;
      }

      Gender? gender;
      final genderText = cell(row, ImportField.gender);
      if (genderText.contains('ذكر') || genderText.toLowerCase() == 'm') {
        gender = Gender.male;
      } else if (genderText.contains('أنث') ||
          genderText.toLowerCase() == 'f') {
        gender = Gender.female;
      }

      final ageText = cell(row, ImportField.age);
      final age = ageText.isEmpty
          ? null
          : int.tryParse(ageText.replaceAll(RegExp(r'[^0-9]'), ''));

      drafts.add(
        Patient(
          fullName: fullName,
          patientNumber: nullable(row, ImportField.patientNumber),
          phone: nullable(row, ImportField.phone),
          gender: gender,
          address: nullable(row, ImportField.address),
          age: age,
          diagnosis: nullable(row, ImportField.diagnosis),
          previousMedications: nullable(row, ImportField.previousMedications),
          currentMedications: nullable(row, ImportField.currentMedications),
          allergies: nullable(row, ImportField.allergies),
          medicalHistory: nullable(row, ImportField.medicalHistory),
          surgeriesHistory: nullable(row, ImportField.surgeriesHistory),
          notes: nullable(row, ImportField.notes),
        ),
      );
    }

    setState(() {
      _drafts = drafts;
      _skippedEmptyRows = skipped;
      _step = _ImportStep.preview;
    });
  }

  Future<void> _runImport() async {
    setState(() => _busy = true);
    final result = await sl<ImportPatients>().call(_drafts);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _busy = false;
        _error = failure.message;
      }),
      (summary) => setState(() {
        _busy = false;
        _summary = summary;
        _step = _ImportStep.done;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استيراد المرضى')),
      body: ResponsiveBody(
        child: switch (_step) {
          _ImportStep.pickFile => _PickFileStep(
            busy: _busy,
            error: _error,
            onPick: _pickFile,
          ),
          _ImportStep.mapping => _MappingStep(
            fileName: _fileName!,
            sheet: _sheet!,
            mapping: _mapping,
            onChanged: (field, header) =>
                setState(() => _mapping[field] = header),
            onNext: _buildDrafts,
          ),
          _ImportStep.preview => _PreviewStep(
            drafts: _drafts,
            skippedEmptyRows: _skippedEmptyRows,
            busy: _busy,
            error: _error,
            onBack: () => setState(() => _step = _ImportStep.mapping),
            onConfirm: _runImport,
          ),
          _ImportStep.done => _DoneStep(summary: _summary!),
        },
      ),
    );
  }
}

class _PickFileStep extends StatelessWidget {
  const _PickFileStep({
    required this.busy,
    required this.error,
    required this.onPick,
  });

  final bool busy;
  final String? error;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.sky,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.upload_file_rounded,
                color: AppColors.aqua,
                size: 32,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'استيراد قائمة مرضى من ملف Excel أو CSV',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 6),
            const Text(
              'الصف الأول يجب أن يحتوي أسماء الأعمدة (الاسم، الهاتف...). '
              'يمكن مطابقة الأعمدة يدويًا في الخطوة التالية.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (error != null) ...[
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger, fontSize: 12),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            FilledButton.icon(
              onPressed: busy ? null : onPick,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.folder_open_rounded, size: 18),
              label: Text(busy ? 'جارٍ التحليل...' : 'اختيار ملف'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MappingStep extends StatelessWidget {
  const _MappingStep({
    required this.fileName,
    required this.sheet,
    required this.mapping,
    required this.onChanged,
    required this.onNext,
  });

  final String fileName;
  final ParsedSheet sheet;
  final Map<ImportField, String?> mapping;
  final void Function(ImportField field, String? header) onChanged;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final canProceed = (mapping[ImportField.fullName] ?? '').isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.sky,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.description_outlined,
                  color: AppColors.aqua,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '$fileName — ${sheet.rows.length} صف، '
                    '${sheet.headers.length} عمود',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            children: [
              for (final field in ImportField.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: DropdownButtonFormField<String>(
                    initialValue: mapping[field],
                    decoration: InputDecoration(
                      labelText: field.label,
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('— لا يوجد —'),
                      ),
                      for (final header in sheet.headers)
                        DropdownMenuItem(value: header, child: Text(header)),
                    ],
                    onChanged: (value) => onChanged(field, value),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: FilledButton(
              onPressed: canProceed ? onNext : null,
              child: const Text('معاينة الاستيراد'),
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewStep extends StatelessWidget {
  const _PreviewStep({
    required this.drafts,
    required this.skippedEmptyRows,
    required this.busy,
    required this.error,
    required this.onBack,
    required this.onConfirm,
  });

  final List<Patient> drafts;
  final int skippedEmptyRows;
  final bool busy;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.sky,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'سيتم إنشاء ${drafts.length} مريض جديد.',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (skippedEmptyRows > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'سيُتجاهل $skippedEmptyRows صف بلا اسم.',
                      style: const TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'أي اسم مطابق لمريض موجود مسبقًا (أو مكرر داخل الملف) '
                    'سيُتجاوز تلقائيًا لتفادي التكرار.',
                    style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: drafts.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final patient = drafts[index];
              return ListTile(
                dense: true,
                title: Text(patient.fullName),
                subtitle: Text(
                  [
                    if (patient.phone != null) patient.phone!,
                    if (patient.patientNumber != null)
                      'رقم ${patient.patientNumber}',
                  ].join(' — '),
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onBack,
                    child: const Text('رجوع'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: (busy || drafts.isEmpty) ? null : onConfirm,
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('بدء الاستيراد'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DoneStep extends StatelessWidget {
  const _DoneStep({required this.summary});

  final ImportSummary summary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.ok.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.ok,
                size: 32,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'تم استيراد ${summary.imported} مريض بنجاح',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (summary.duplicatesSkipped > 0)
              Text(
                'تم تجاوز ${summary.duplicatesSkipped} (مكررون).',
                style: const TextStyle(
                  color: AppColors.inkSoft,
                  fontSize: 12.5,
                ),
              ),
            if (summary.failed > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'تعذّر استيراد ${summary.failed} صف.',
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 12.5,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('تم'),
            ),
          ],
        ),
      ),
    );
  }
}

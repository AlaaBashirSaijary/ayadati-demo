import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ai/gemini_service.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../clinic_assistant/domain/patient_ai_prompts.dart';
import '../../../clinic_assistant/presentation/widgets/patient_instructions_sheet.dart';
import '../../../clinics/presentation/providers/active_clinic_provider.dart';
import '../../domain/entities/prescription.dart';
import '../../domain/entities/prescription_item.dart';
import '../../domain/usecases/save_prescription.dart';
import '../pdf/prescription_pdf_export.dart';

/// One medication line's own set of controllers — drug name is the only
/// required field, matching how little a paper Rx pad actually forces a
/// doctor to fill in.
class _ItemControllers {
  _ItemControllers()
    : drugName = TextEditingController(),
      dosage = TextEditingController(),
      frequency = TextEditingController(),
      duration = TextEditingController(),
      notes = TextEditingController();

  final TextEditingController drugName;
  final TextEditingController dosage;
  final TextEditingController frequency;
  final TextEditingController duration;
  final TextEditingController notes;

  /// Not persisted anywhere — just drives this row's own suggest-button
  /// spinner while a Gemini call is in flight.
  bool suggesting = false;

  void dispose() {
    drugName.dispose();
    dosage.dispose();
    frequency.dispose();
    duration.dispose();
    notes.dispose();
  }
}

class PrescriptionFormPage extends ConsumerStatefulWidget {
  const PrescriptionFormPage({
    super.key,
    required this.patientId,
    required this.patientName,
    this.patientAge,
    this.patientPhone,
    this.visitId,
  });

  final int patientId;
  final String patientName;
  final int? patientAge;
  final String? patientPhone;
  final int? visitId;

  @override
  ConsumerState<PrescriptionFormPage> createState() =>
      _PrescriptionFormPageState();
}

class _PrescriptionFormPageState extends ConsumerState<PrescriptionFormPage> {
  final _notesController = TextEditingController();
  final _items = <_ItemControllers>[_ItemControllers()];
  bool _saving = false;
  bool _writingInstructions = false;
  String? _error;

  @override
  void dispose() {
    _notesController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItem() => setState(() => _items.add(_ItemControllers()));

  void _removeItem(int index) => setState(() {
    _items[index].dispose();
    _items.removeAt(index);
  });

  /// A general-reference suggestion only — never patient-specific medical
  /// advice, and always left in editable fields the doctor must review
  /// before saving. Fills whichever of dosage/frequency/duration the model
  /// returns; leaves the rest alone if it isn't sure.
  Future<void> _suggestDosage(int index) async {
    final controllers = _items[index];
    final drugName = controllers.drugName.text.trim();
    if (drugName.isEmpty) {
      setState(() => _error = 'اكتبي اسم الدواء أولًا.');
      return;
    }

    setState(() {
      controllers.suggesting = true;
      _error = null;
    });

    final ageSuffix = widget.patientAge != null
        ? ' لمريض بالغ العمر ${widget.patientAge} سنة'
        : ' لمريض بالغ';
    final prompt =
        'أنتِ مرجع معلومات دوائية عامة. لدواء اسمه "$drugName"$ageSuffix، '
        'اقترحي جرعة اعتيادية وعدد مرات ومدة استخدام شائعة. أجيبي بصيغة '
        'JSON فقط بدون أي نص إضافي وبهذا الشكل بالضبط: '
        '{"dosage": "...", "frequency": "...", "duration": "..."}. '
        'إن لم تكوني متأكدة من الدواء أو معلوماته، أعيدي قيمًا فارغة "".';

    final result = await GeminiService.instance.generateText(prompt);
    if (!mounted) return;

    setState(() {
      controllers.suggesting = false;
      if (result == null) {
        _error =
            'تعذّر الاتصال بالمساعد الذكي — تأكدي من الإنترنت.\n'
            '(${GeminiService.instance.lastError})';
        return;
      }
      try {
        final cleaned = result
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        final json = jsonDecode(cleaned) as Map<String, dynamic>;
        final dosage = (json['dosage'] as String? ?? '').trim();
        final frequency = (json['frequency'] as String? ?? '').trim();
        final duration = (json['duration'] as String? ?? '').trim();
        if (dosage.isEmpty && frequency.isEmpty && duration.isEmpty) {
          _error =
              'المساعد الذكي غير متأكد من هذا الدواء — أدخلي الجرعة يدويًا.';
          return;
        }
        if (dosage.isNotEmpty) controllers.dosage.text = dosage;
        if (frequency.isNotEmpty) controllers.frequency.text = frequency;
        if (duration.isNotEmpty) controllers.duration.text = duration;
      } catch (_) {
        _error = 'تعذّر فهم اقتراح المساعد الذكي — أدخلي الجرعة يدويًا.';
      }
    });
  }

  /// Plain-Arabic instructions for the patient, written from the drug lines
  /// the doctor has entered (doses and durations are used exactly as typed).
  Future<void> _writeInstructions() async {
    final lines = [
      for (final c in _items)
        if (c.drugName.text.trim().isNotEmpty)
          RxLine(
            drug: c.drugName.text.trim(),
            dosage: c.dosage.text,
            frequency: c.frequency.text,
            duration: c.duration.text,
            notes: c.notes.text,
          ),
    ];
    if (lines.isEmpty) {
      setState(() => _error = 'أضيفي دواءً واحدًا على الأقل أولًا.');
      return;
    }
    setState(() {
      _writingInstructions = true;
      _error = null;
    });
    final text = await GeminiService.instance.generateText(
      patientInstructionsPrompt(
        items: lines,
        prescriptionNotes: _notesController.text,
        age: widget.patientAge,
      ),
    );
    if (!mounted) return;
    setState(() => _writingInstructions = false);
    if (text == null) {
      setState(
        () => _error =
            'تعذّر الاتصال بالمساعد الذكي — تأكدي من الإنترنت.\n'
            '(${GeminiService.instance.lastError})',
      );
      return;
    }
    await showPatientInstructionsSheet(
      context,
      text: text.trim(),
      phone: widget.patientPhone,
    );
  }

  Future<void> _save() async {
    final items = [
      for (final controllers in _items)
        if (controllers.drugName.text.trim().isNotEmpty)
          PrescriptionItem(
            drugName: controllers.drugName.text.trim(),
            dosage: controllers.dosage.text.trim().isEmpty
                ? null
                : controllers.dosage.text.trim(),
            frequency: controllers.frequency.text.trim().isEmpty
                ? null
                : controllers.frequency.text.trim(),
            duration: controllers.duration.text.trim().isEmpty
                ? null
                : controllers.duration.text.trim(),
            notes: controllers.notes.text.trim().isEmpty
                ? null
                : controllers.notes.text.trim(),
          ),
    ];

    if (items.isEmpty) {
      setState(() => _error = 'أضيفي دواءً واحدًا على الأقل.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final prescription = Prescription(
      patientId: widget.patientId,
      visitId: widget.visitId,
      items: items,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdAt: DateTime.now(),
    );

    final result = await sl<SavePrescription>().call(prescription);
    if (!mounted) return;

    await result.fold(
      (failure) async => setState(() {
        _saving = false;
        _error = failure.message;
      }),
      (saved) async {
        await PrescriptionPdfExport.export(
          clinicName: ref.read(activeClinicProvider).active?.name ?? '',
          doctorName: ref.read(authProvider).user?.name ?? '',
          patientName: widget.patientName,
          patientAge: widget.patientAge,
          prescription: saved,
        );
        if (!mounted) return;
        Navigator.of(context).pop(true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('وصفة طبية جديدة')),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              widget.patientName,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final (index, controllers) in _items.indexed) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppShadows.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'دواء ${index + 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ),
                        if (_items.length > 1)
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: AppColors.danger,
                            ),
                            onPressed: () => _removeItem(index),
                          ),
                      ],
                    ),
                    TextField(
                      controller: controllers.drugName,
                      decoration: const InputDecoration(
                        labelText: 'اسم الدواء',
                      ),
                    ),
                    if (GeminiService.instance.isAvailable) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          onPressed: controllers.suggesting
                              ? null
                              : () => _suggestDosage(index),
                          icon: controllers.suggesting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 16,
                                ),
                          label: const Text(
                            'اقتراح الجرعة',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text(
                          'اقتراح عام مرجعي فقط — تحققي دائمًا قبل الوصف.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controllers.dosage,
                            decoration: const InputDecoration(
                              labelText: 'الجرعة',
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: TextField(
                            controller: controllers.frequency,
                            decoration: const InputDecoration(
                              labelText: 'عدد المرات',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controllers.duration,
                            decoration: const InputDecoration(
                              labelText: 'المدة',
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: TextField(
                            controller: controllers.notes,
                            decoration: const InputDecoration(
                              labelText: 'ملاحظات (اختياري)',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            OutlinedButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('إضافة دواء آخر'),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'ملاحظات عامة (اختياري)',
              ),
            ),
            if (GeminiService.instance.isAvailable) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: _writingInstructions ? null : _writeInstructions,
                icon: _writingInstructions
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 18),
                label: const Text('تعليمات للمريض بلغة بسيطة (واتساب)'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 13),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            _saving
                ? const Center(child: CircularProgressIndicator())
                : FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text('حفظ وطباعة'),
                  ),
          ],
        ),
      ),
    );
  }
}

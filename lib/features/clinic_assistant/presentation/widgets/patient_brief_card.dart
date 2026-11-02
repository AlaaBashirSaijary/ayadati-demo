import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/ai/gemini_service.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../patients/domain/entities/patient.dart';
import '../../../visits/domain/entities/visit.dart';
import '../../../visits/domain/usecases/get_visits.dart';
import '../../domain/patient_ai_prompts.dart';

/// Builds the [VisitBrief] list the prompts use from a patient's visits
/// (newest first, as the visits list is already ordered).
List<VisitBrief> visitBriefs(List<Visit> visits, {int count = 2}) {
  final date = DateFormat('yyyy/MM/dd');
  return [
    for (final v in visits.take(count))
      VisitBrief(
        date: date.format(v.visitDate),
        type: v.visitType.label,
        summary: v.examSummary,
        notes: v.notes,
        outcome: v.followUpOutcome,
      ),
  ];
}

/// "ملخص قبل الدخول": five short lines from the patient's record and last two
/// visits, written by the AI for the doctor to glance at. Only clinical facts
/// are sent (never name, phone or address) and it is clearly a draft.
class PatientBriefCard extends StatefulWidget {
  const PatientBriefCard({super.key, required this.patient});

  final Patient patient;

  @override
  State<PatientBriefCard> createState() => _PatientBriefCardState();
}

class _PatientBriefCardState extends State<PatientBriefCard> {
  bool _loading = false;
  String? _text;

  Future<void> _generate() async {
    setState(() => _loading = true);
    final p = widget.patient;
    final visits = await sl<GetVisits>().call(p.id!);
    final briefs = visits.fold((_) => <VisitBrief>[], (v) => visitBriefs(v));
    final text = await GeminiService.instance.generateText(
      patientBriefPrompt(
        age: p.displayAge,
        gender: p.gender?.label,
        allergies: p.allergies,
        history: p.medicalHistory,
        currentMedications: p.currentMedications,
        complaint: p.diagnosis,
        lastVisits: briefs,
      ),
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _text = text;
    });
    if (text == null) {
      AppSnack.error(
        context,
        'تعذّر الاتصال بالمساعد الذكي. تأكد من الإنترنت.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!GeminiService.instance.isAvailable || widget.patient.id == null) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.sky.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: AppColors.aqua,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'ملخص سريع قبل الدخول',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (_text != null)
                IconButton(
                  tooltip: 'نسخ',
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _text!));
                    if (context.mounted) AppSnack.success(context, 'تم النسخ.');
                  },
                ),
            ],
          ),
          if (_text != null) ...[
            const SizedBox(height: 6),
            Text(_text!, style: const TextStyle(height: 1.7, fontSize: 13.5)),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonalIcon(
              onPressed: _loading ? null : _generate,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.summarize_outlined, size: 18),
              label: Text(_text == null ? 'اكتب الملخص' : 'تحديث'),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'مسودة من الذكاء الاصطناعي من بيانات الملف دون اسم المريض — راجعها '
            'دائمًا، فهي لا تُغني عن قراءة الملف.',
            style: TextStyle(fontSize: 11, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

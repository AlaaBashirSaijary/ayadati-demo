import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ai/gemini_service.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../clinic_assistant/domain/patient_ai_prompts.dart';
import '../../../clinic_assistant/presentation/widgets/patient_brief_card.dart';
import '../../../clinics/presentation/providers/active_clinic_provider.dart';
import '../../../visits/domain/usecases/get_visits.dart';
import '../../domain/entities/medical_certificate.dart';
import '../../domain/usecases/save_medical_certificate.dart';
import '../pdf/medical_certificate_pdf_export.dart';

class MedicalCertificateFormPage extends ConsumerStatefulWidget {
  const MedicalCertificateFormPage({
    super.key,
    required this.patientId,
    required this.patientName,
    this.patientAge,
  });

  final int patientId;
  final String patientName;
  final int? patientAge;

  @override
  ConsumerState<MedicalCertificateFormPage> createState() =>
      _MedicalCertificateFormPageState();
}

class _MedicalCertificateFormPageState
    extends ConsumerState<MedicalCertificateFormPage> {
  final _restDaysController = TextEditingController(text: '3');
  final _bodyController = TextEditingController();
  final _targetController = TextEditingController();
  MedicalCertificateType _type = MedicalCertificateType.sickLeave;
  bool _saving = false;
  bool _drafting = false;
  String? _error;

  @override
  void dispose() {
    _restDaysController.dispose();
    _bodyController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  /// Turns whatever shorthand the doctor already typed into the body field
  /// into formal wording — the doctor's own note is the only source of the
  /// medical content; the AI only rephrases it, and the result still sits
  /// in an editable field before anything is saved or printed.
  Future<void> _draftWithAI() async {
    final shorthand = _bodyController.text.trim();
    final isReferral = _type == MedicalCertificateType.referral;
    if (shorthand.isEmpty && !isReferral) {
      setState(
        () => _error = 'اكتبي ملاحظة مختصرة أولًا (مثلًا: التهاب حلق، ٣ أيام).',
      );
      return;
    }

    setState(() {
      _drafting = true;
      _error = null;
    });

    final isSickLeave = _type == MedicalCertificateType.sickLeave;
    final ageSuffix = widget.patientAge != null
        ? '، العمر ${widget.patientAge} سنة'
        : '';
    String? referralDraft;
    if (isReferral) {
      final visits = await sl<GetVisits>().call(widget.patientId);
      referralDraft = referralPrompt(
        age: widget.patientAge,
        doctorNote: shorthand,
        target: _targetController.text,
        lastVisits: visits.fold((_) => <VisitBrief>[], (v) => visitBriefs(v)),
      );
    }
    final prompt =
        referralDraft ??
        (isSickLeave
            ? 'أنتِ مساعدة كتابة لعيادة طبية سورية. اكتبي نص إجازة مرضية رسمي '
                  'مختصر بالعربية الفصحى لمريض اسمه "${widget.patientName}"'
                  '$ageSuffix، مدة الإجازة ${_restDaysController.text} يوم، '
                  'بناءً على ملاحظة الطبيب التالية: "$shorthand". اكتبي فقرة '
                  'واحدة رسمية فقط، بدون عنوان أو تحية أو توقيع، جاهزة للطباعة '
                  'مباشرة.'
            : 'أنتِ مساعدة كتابة لعيادة طبية سورية. حوّلي ملاحظة الطبيب '
                  'المختصرة التالية إلى تقرير طبي رسمي بالعربية الفصحى لمريض '
                  'اسمه "${widget.patientName}"$ageSuffix: "$shorthand". اكتبي '
                  'التقرير كفقرة أو فقرتين رسميتين فقط، بدون عنوان أو تحية أو '
                  'توقيع، جاهز للطباعة مباشرة.');

    final draft = await GeminiService.instance.generateText(prompt);
    if (!mounted) return;
    setState(() {
      _drafting = false;
      if (draft != null) {
        _bodyController.text = draft;
      } else {
        _error =
            'تعذّر الاتصال بالمساعد الذكي — تأكدي من الإنترنت، أو '
            'أكملي النص يدويًا.\n(${GeminiService.instance.lastError})';
      }
    });
  }

  Future<void> _save() async {
    final isSickLeave = _type == MedicalCertificateType.sickLeave;
    if (!isSickLeave && _bodyController.text.trim().isEmpty) {
      setState(() => _error = 'أدخلي نص التقرير.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final certificate = MedicalCertificate(
      patientId: widget.patientId,
      type: _type,
      restDays: isSickLeave ? int.tryParse(_restDaysController.text) : null,
      body: _bodyController.text.trim(),
      createdAt: DateTime.now(),
    );

    final result = await sl<SaveMedicalCertificate>().call(certificate);
    if (!mounted) return;

    await result.fold(
      (failure) async => setState(() {
        _saving = false;
        _error = failure.message;
      }),
      (saved) async {
        await MedicalCertificatePdfExport.export(
          clinicName: ref.read(activeClinicProvider).active?.name ?? '',
          doctorName: ref.read(authProvider).user?.name ?? '',
          patientName: widget.patientName,
          patientAge: widget.patientAge,
          certificate: saved,
        );
        if (!mounted) return;
        Navigator.of(context).pop(true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSickLeave = _type == MedicalCertificateType.sickLeave;

    return Scaffold(
      appBar: AppBar(title: const Text('تقرير طبي / إجازة مرضية')),
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
            Wrap(
              spacing: 8,
              children: [
                for (final type in MedicalCertificateType.values)
                  ChoiceChip(
                    label: Text(type.label),
                    selected: _type == type,
                    onSelected: (_) => setState(() => _type = type),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (isSickLeave) ...[
              TextField(
                controller: _restDaysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'عدد أيام الإجازة',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _bodyController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'سبب الإجازة / ملاحظات إضافية (اختياري)',
                ),
              ),
            ] else ...[
              if (_type == MedicalCertificateType.referral) ...[
                TextField(
                  controller: _targetController,
                  decoration: const InputDecoration(
                    labelText: 'محوّل إلى (اختصاص أو اسم الزميل)',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              TextField(
                controller: _bodyController,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: _type == MedicalCertificateType.referral
                      ? 'سبب التحويل / نص الرسالة'
                      : 'نص التقرير الطبي',
                  alignLabelWithHint: true,
                ),
              ),
            ],
            if (GeminiService.instance.isAvailable) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _drafting ? null : _draftWithAI,
                icon: _drafting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(
                  _type == MedicalCertificateType.referral
                      ? 'اقتراح رسالة التحويل بالذكاء الاصطناعي'
                      : 'صياغة رسمية بالذكاء الاصطناعي',
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'يعيد صياغة ملاحظتك أعلاه بشكل رسمي (وللتحويل يستعين بآخر '
                  'زيارتين دون اسم المريض) — راجعي النص دائمًا قبل الحفظ.',
                  style: TextStyle(fontSize: 11, color: AppColors.inkSoft),
                ),
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

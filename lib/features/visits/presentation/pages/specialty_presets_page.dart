import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../domain/entities/exam_field_template.dart';
import '../../domain/entities/specialty_preset.dart';
import '../../domain/usecases/delete_exam_template.dart';
import '../../domain/usecases/get_exam_templates.dart';
import '../../domain/usecases/save_exam_template.dart';

const _icons = <String, IconData>{
  'eye': Icons.remove_red_eye_outlined,
  'dental': Icons.cleaning_services_outlined,
  'child': Icons.child_care_rounded,
  'pregnant': Icons.pregnant_woman_rounded,
  'steth': Icons.medical_services_outlined,
  'heart': Icons.favorite_border_rounded,
  'ear': Icons.hearing_rounded,
  'skin': Icons.healing_rounded,
  'bone': Icons.accessibility_new_rounded,
  'brain': Icons.psychology_outlined,
  'surgery': Icons.local_hospital_outlined,
};

/// Ready-made exam forms per specialty. The doctor picks theirs and gets a
/// sensible form in one tap (added to what they already have, or replacing
/// it), then edits anything from "نموذج الفحص".
class SpecialtyPresetsPage extends StatefulWidget {
  const SpecialtyPresetsPage({super.key});

  @override
  State<SpecialtyPresetsPage> createState() => _SpecialtyPresetsPageState();
}

class _SpecialtyPresetsPageState extends State<SpecialtyPresetsPage> {
  Future<List<ExamFieldTemplate>> _existing() async {
    final result = await sl<GetExamTemplates>().call(const NoParams());
    return result.fold((_) => <ExamFieldTemplate>[], (t) => t);
  }

  Future<void> _open(SpecialtyPreset preset) async {
    final existing = await _existing();
    if (!mounted) return;
    final choice = await showModalBottomSheet<_Apply>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PresetSheet(preset: preset, existing: existing),
    );
    if (choice == null || !mounted) return;
    await _apply(preset, existing, choice);
  }

  Future<void> _apply(
    SpecialtyPreset preset,
    List<ExamFieldTemplate> existing,
    _Apply mode,
  ) async {
    if (mode == _Apply.replace) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('استبدال النموذج الحالي؟'),
          content: const Text(
            'ستُحذف حقول الفحص الحالية وكل القيم المسجّلة لها في الزيارات '
            'السابقة. لا يمكن التراجع. إن كانت لديك زيارات مسجّلة فاختر '
            '"إضافة إلى النموذج الحالي" بدلًا من ذلك.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text(
                'استبدال',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          ],
        ),
      );
      if (ok != true) return;
      for (final t in existing) {
        await sl<DeleteExamTemplate>().call(t.id!);
      }
    }

    final toAdd = mode == _Apply.replace
        ? preset.fields
        : preset.missingFrom(existing);
    for (final f in toAdd) {
      await sl<SaveExamTemplate>().call(
        ExamFieldTemplate(
          label: f.label,
          hasSides: f.sides,
          isLongText: f.long,
        ),
      );
    }
    if (!mounted) return;
    AppSnack.success(
      context,
      toAdd.isEmpty
          ? 'نموذجك يحتوي هذه الحقول مسبقًا.'
          : 'تم تجهيز نموذج ${preset.name} (${toAdd.length} حقل).',
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('قوالب الاختصاصات')),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const Text(
              'اختر اختصاصك فيجهَّز لك نموذج الفحص بحقول مناسبة. يمكنك '
              'تعديل أي حقل أو حذفه أو إضافة غيره بعد ذلك.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.inkSoft,
                height: 1.6,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final p in specialtyPresets)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  onTap: () => _open(p),
                  child: SurfaceCard(
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.sky,
                          child: Icon(
                            _icons[p.iconKey] ??
                                Icons.medical_services_outlined,
                            color: AppColors.aqua,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                '${p.summary} — ${p.fields.length} حقل',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_left_rounded),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _Apply { add, replace }

class _PresetSheet extends StatelessWidget {
  const _PresetSheet({required this.preset, required this.existing});

  final SpecialtyPreset preset;
  final List<ExamFieldTemplate> existing;

  @override
  Widget build(BuildContext context) {
    final missing = preset.missingFrom(existing).length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              preset.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in preset.fields)
                      Chip(
                        label: Text(
                          f.sides ? '${f.label}  (يمين/يسار)' : f.label,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_Apply.add),
              child: Text(
                missing == 0
                    ? 'الحقول موجودة مسبقًا'
                    : 'إضافة $missing حقل إلى نموذجي الحالي',
              ),
            ),
            if (existing.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(_Apply.replace),
                child: const Text('استبدال النموذج الحالي بالكامل'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

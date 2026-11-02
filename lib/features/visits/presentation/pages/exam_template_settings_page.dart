import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/exam_field_template.dart';
import 'specialty_presets_page.dart';
import '../../domain/usecases/delete_exam_template.dart';
import '../../domain/usecases/get_exam_templates.dart';
import '../../domain/usecases/reorder_exam_templates.dart';
import '../../domain/usecases/save_exam_template.dart';
import '../../../../core/widgets/app_snack.dart';

/// Lets a clinic build its own exam form — add/edit/remove/reorder the
/// rows a visit records, instead of the app assuming any one specialty's
/// chart. Reachable from the visit form's tune icon, and from Admin.
class ExamTemplateSettingsPage extends StatefulWidget {
  const ExamTemplateSettingsPage({super.key});

  @override
  State<ExamTemplateSettingsPage> createState() =>
      _ExamTemplateSettingsPageState();
}

class _ExamTemplateSettingsPageState extends State<ExamTemplateSettingsPage> {
  bool _loading = true;
  List<ExamFieldTemplate> _templates = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await sl<GetExamTemplates>().call(const NoParams());
    if (!mounted) return;
    setState(() {
      _loading = false;
      result.fold((_) {}, (templates) => _templates = templates);
    });
  }

  Future<void> _addOrEdit({ExamFieldTemplate? existing}) async {
    final saved = await showDialog<ExamFieldTemplate>(
      context: context,
      builder: (_) => _FieldTemplateDialog(existing: existing),
    );
    if (saved == null) return;

    final result = await sl<SaveExamTemplate>().call(saved);
    if (!mounted) return;
    result.fold(
      (failure) => AppSnack.error(context, failure.message),
      (_) => _load(),
    );
  }

  Future<void> _delete(ExamFieldTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الحقل؟'),
        content: Text(
          'سيُحذف حقل "${template.label}" وكل القيم المسجّلة له في '
          'الزيارات السابقة. لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حذف', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await sl<DeleteExamTemplate>().call(template.id!);
    if (!mounted) return;
    result.fold(
      (failure) => AppSnack.error(context, failure.message),
      (_) => _load(),
    );
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final reordered = List<ExamFieldTemplate>.from(_templates);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    setState(() => _templates = reordered);

    await sl<ReorderExamTemplates>().call([
      for (final template in reordered) template.id!,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نموذج الفحص'),
        actions: [
          IconButton(
            tooltip: 'قوالب الاختصاصات',
            icon: const Icon(Icons.auto_awesome_motion_rounded),
            onPressed: () async {
              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const SpecialtyPresetsPage()),
              );
              if (changed == true) _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  color: AppColors.sky.withValues(alpha: 0.5),
                  child: const Text(
                    'هذه الحقول تظهر في نموذج كل زيارة فحص لهذه العيادة. '
                    'أضيفي حقلاً لكل قياس تسجّلينه، واختاري "له جانبان" إن '
                    'كان يُقاس لكل جهة على حدة (كعينين أو أذنين).',
                    style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
                  ),
                ),
                Expanded(
                  child: _templates.isEmpty
                      ? const Center(
                          child: Text(
                            'لا توجد حقول بعد — أضيفي أول حقل بالزر أدناه.',
                            style: TextStyle(color: AppColors.inkSoft),
                          ),
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          itemCount: _templates.length,
                          onReorder: _onReorder,
                          itemBuilder: (context, index) {
                            final template = _templates[index];
                            return Container(
                              key: ValueKey(template.id),
                              margin: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: AppShadows.card,
                              ),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.drag_handle_rounded,
                                  color: AppColors.inkSoft,
                                ),
                                title: Text(
                                  template.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  [
                                    template.hasSides
                                        ? 'له جانبان (يمين/يسار)'
                                        : 'قيمة واحدة',
                                    if (template.isLongText) 'نص طويل',
                                  ].join(' — '),
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 20,
                                      ),
                                      onPressed: () =>
                                          _addOrEdit(existing: template),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 20,
                                        color: AppColors.danger,
                                      ),
                                      onPressed: () => _delete(template),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة حقل'),
      ),
    );
  }
}

class _FieldTemplateDialog extends StatefulWidget {
  const _FieldTemplateDialog({this.existing});

  final ExamFieldTemplate? existing;

  @override
  State<_FieldTemplateDialog> createState() => _FieldTemplateDialogState();
}

class _FieldTemplateDialogState extends State<_FieldTemplateDialog> {
  late final _labelController = TextEditingController(
    text: widget.existing?.label ?? '',
  );
  late bool _hasSides = widget.existing?.hasSides ?? false;
  late bool _isLongText = widget.existing?.isLongText ?? false;

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void _submit() {
    final label = _labelController.text.trim();
    if (label.isEmpty) return;

    Navigator.of(context).pop(
      ExamFieldTemplate(
        id: widget.existing?.id,
        label: label,
        hasSides: _hasSides,
        isLongText: _isLongText,
        sortOrder: widget.existing?.sortOrder ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'إضافة حقل' : 'تعديل حقل'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _labelController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'اسم الحقل'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.sm),
          CheckboxListTile(
            value: _hasSides,
            onChanged: (v) => setState(() => _hasSides = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'له جانبان (يمين/يسار)',
              style: TextStyle(fontSize: 13),
            ),
          ),
          CheckboxListTile(
            value: _isLongText,
            onChanged: (v) => setState(() => _isLongText = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'نص طويل (يحتاج مساحة أكبر للكتابة)',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        TextButton(onPressed: _submit, child: const Text('حفظ')),
      ],
    );
  }
}

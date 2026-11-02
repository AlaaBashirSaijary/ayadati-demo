import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/whatsapp/whatsapp_service.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../clinics/presentation/providers/active_clinic_provider.dart';
import '../../data/recall_local_datasource.dart';
import '../../domain/recall.dart';

/// "استدعاء المراجعين": a ready send-list of patients to bring back — those
/// flagged for follow-up and those who haven't visited for 3/6/12 months with
/// nothing booked. One tap opens WhatsApp with the message written; a patient
/// already messaged in the last two weeks is marked and skipped, so the doctor
/// can work down the list over several days without repeating anyone.
class RecallPage extends ConsumerStatefulWidget {
  const RecallPage({super.key});

  @override
  ConsumerState<RecallPage> createState() => _RecallPageState();
}

class _RecallPageState extends ConsumerState<RecallPage> {
  static final _date = DateFormat('yyyy/MM/dd');

  RecallKind _kind = RecallKind.overdueFollowUp;
  List<RecallCandidate> _items = [];
  final Map<int, DateTime> _lastSent = {};
  String _template = '';
  bool _loading = true;

  String get _prefix => 'recall.${ref.read(activeClinicProvider).active?.id}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    _template =
        prefs.getString('$_prefix.template.${_kind.name}') ??
        _kind.defaultMessage;
    final items = await sl<RecallLocalDataSource>().candidates(_kind);
    _lastSent.clear();
    for (final c in items) {
      final raw = prefs.getString('$_prefix.sent.${c.patientId}');
      if (raw != null) _lastSent[c.patientId] = DateTime.parse(raw);
    }
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  bool _cooling(RecallCandidate c) =>
      isCoolingDown(_lastSent[c.patientId], DateTime.now());

  bool _hasPhone(RecallCandidate c) =>
      WhatsAppService.normalize(c.phone) != null;

  List<RecallCandidate> get _todo =>
      _items.where((c) => _hasPhone(c) && !_cooling(c)).toList();

  Future<void> _send(RecallCandidate c) async {
    final clinic = ref.read(activeClinicProvider).active?.name ?? '';
    final message = fillRecallTemplate(_template, name: c.name, clinic: clinic);
    final opened = await WhatsAppService.open(c.phone ?? '', message);
    if (!mounted) return;
    if (!opened) {
      AppSnack.error(context, 'تعذّر فتح واتساب على هذا الجهاز.');
      return;
    }
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_prefix.sent.${c.patientId}',
      now.toIso8601String(),
    );
    setState(() => _lastSent[c.patientId] = now);
  }

  Future<void> _editTemplate() async {
    final controller = TextEditingController(text: _template);
    final saved = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('نص الرسالة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: controller, maxLines: 6, autofocus: true),
            const SizedBox(height: 8),
            const Text(
              'استخدم {name} لاسم المريض و{clinic} لاسم العيادة.',
              style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_kind.defaultMessage),
            child: const Text('الافتراضي'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (saved == null || saved.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix.template.${_kind.name}', saved.trim());
    setState(() => _template = saved.trim());
  }

  @override
  Widget build(BuildContext context) {
    final todo = _todo;
    return Scaffold(
      appBar: AppBar(
        title: const Text('استدعاء المراجعين'),
        actions: [
          IconButton(
            tooltip: 'تعديل نص الرسالة',
            icon: const Icon(Icons.edit_note_rounded),
            onPressed: _editTemplate,
          ),
        ],
      ),
      floatingActionButton: todo.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _send(todo.first),
              icon: const Icon(Icons.chat_rounded),
              label: Text('التالي (${todo.length})'),
            ),
      body: ResponsiveBody(
        child: Column(
          children: [
            SizedBox(
              height: 54,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                children: [
                  for (final k in RecallKind.values)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(
                        label: Text(k.label),
                        selected: _kind == k,
                        onSelected: (_) {
                          setState(() => _kind = k);
                          _load();
                        },
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          'لا يوجد مرضى في هذه القائمة الآن.',
                          style: TextStyle(color: AppColors.inkSoft),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        96,
                      ),
                      children: [
                        Text(
                          todo.isEmpty
                              ? 'تمت مراسلة الجميع ✓'
                              : 'جاهز للإرسال: ${todo.length} من ${_items.length}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: todo.isEmpty ? AppColors.ok : AppColors.ink,
                          ),
                        ),
                        const Text(
                          'واتساب لا يسمح بالإرسال التلقائي — اضغط إرسال في كل '
                          'محادثة تُفتح. من تمت مراسلته خلال ١٤ يومًا يُتخطّى.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.inkSoft,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        for (final c in _items) _tile(c),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(RecallCandidate c) {
    final cooling = _cooling(c);
    final hasPhone = _hasPhone(c);
    final sentAt = _lastSent[c.patientId];
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'آخر زيارة ${_date.format(c.lastVisit)}'
                  '${c.followUpBy == null ? '' : ' · المتابعة ${_date.format(c.followUpBy!)}'}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.inkSoft,
                  ),
                ),
                if (sentAt != null)
                  Text(
                    'راسلناه قبل ${DateTime.now().difference(sentAt).inDays} يومًا',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.ok),
                  ),
                if (!hasPhone)
                  const Text(
                    'لا يوجد رقم هاتف',
                    style: TextStyle(fontSize: 11.5, color: AppColors.danger),
                  ),
              ],
            ),
          ),
          if (hasPhone)
            cooling
                ? const Icon(Icons.check_circle_rounded, color: AppColors.ok)
                : FilledButton.tonalIcon(
                    onPressed: () => _send(c),
                    icon: const Icon(Icons.chat_rounded, size: 18),
                    label: const Text('إرسال'),
                  ),
        ],
      ),
    );
  }
}

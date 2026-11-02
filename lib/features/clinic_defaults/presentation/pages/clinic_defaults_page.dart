import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/money/currency.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../domain/entities/fee_defaults.dart';
import '../../domain/entities/phrase_kind.dart';
import '../../domain/usecases/fee_defaults_usecases.dart';
import '../../domain/usecases/phrase_usecases.dart';

/// Where the doctor sets the things the visit form fills in by itself: the
/// usual fee per visit type, and the quick phrases offered under the free-
/// text fields. Everything here exists to save typing, so every field is
/// optional and leaving it empty just means "no default".
class ClinicDefaultsPage extends StatefulWidget {
  const ClinicDefaultsPage({super.key});

  @override
  State<ClinicDefaultsPage> createState() => _ClinicDefaultsPageState();
}

class _ClinicDefaultsPageState extends State<ClinicDefaultsPage> {
  final _consultationController = TextEditingController();
  final _checkupController = TextEditingController();
  final _rateController = TextEditingController();
  Currency _currency = Currency.syp;
  final _newPhraseController = TextEditingController();
  PhraseKind _kind = PhraseKind.summary;
  List<String> _phrases = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _consultationController.dispose();
    _checkupController.dispose();
    _rateController.dispose();
    _newPhraseController.dispose();
    super.dispose();
  }

  static String _fmt(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  static double? _parse(String text) {
    final t = text.trim().replaceAll(',', '.');
    return t.isEmpty ? null : double.tryParse(t);
  }

  Future<void> _load() async {
    final fees = await sl<GetFeeDefaults>().call(const NoParams());
    fees.fold((_) {}, (f) {
      _consultationController.text = _fmt(f.consultationFee);
      _checkupController.text = _fmt(f.checkupFee);
      _rateController.text = _fmt(f.usdRate);
      _currency = f.currency;
    });
    await _loadPhrases();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadPhrases() async {
    final result = await sl<GetPhrases>().call(_kind);
    result.fold((_) {}, (list) => _phrases = list);
    if (mounted) setState(() {});
  }

  Future<void> _saveFees() async {
    setState(() => _saving = true);
    final result = await sl<SaveFeeDefaults>().call(
      FeeDefaults(
        consultationFee: _parse(_consultationController.text),
        checkupFee: _parse(_checkupController.text),
        currency: _currency,
        usdRate: _parse(_rateController.text),
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    result.fold(
      (f) => AppSnack.error(context, f.message),
      (_) => AppSnack.success(context, 'تم حفظ الأسعار الافتراضية.'),
    );
  }

  Future<void> _addPhrase() async {
    final text = _newPhraseController.text.trim();
    if (text.isEmpty) return;
    await sl<RecordPhrase>().call(PhraseParams(_kind, text));
    _newPhraseController.clear();
    await _loadPhrases();
  }

  Future<void> _deletePhrase(String text) async {
    await sl<DeletePhrase>().call(PhraseParams(_kind, text));
    await _loadPhrases();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأسعار والعبارات السريعة')),
      body: ResponsiveBody(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  SurfaceCard(
                    title: 'الكشفية الافتراضية',
                    icon: Icons.payments_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'تُعبَّأ تلقائيًا في نموذج الزيارة حسب نوعها، ويبقى '
                          'بإمكانك تعديلها لأي زيارة.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.inkSoft,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          controller: _consultationController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'معاينة (كشفية كاملة)',
                            suffixText: _currency.symbol,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          controller: _checkupController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'مراجعة (نصف السعر أو مجانية)',
                            hintText: 'اتركه فارغًا إن كانت مجانية',
                            suffixText: _currency.symbol,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Text(
                          'عملة الكشفية',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.inkSoft,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        SegmentedButton<Currency>(
                          segments: const [
                            ButtonSegment(
                              value: Currency.syp,
                              label: Text('ليرة سورية'),
                            ),
                            ButtonSegment(
                              value: Currency.usd,
                              label: Text('دولار'),
                            ),
                          ],
                          selected: {_currency},
                          onSelectionChanged: (s) =>
                              setState(() => _currency = s.first),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          controller: _rateController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'سعر الدولار بالليرة (اختياري)',
                            helperText:
                                'يُستخدم فقط لعرض مجموع واحد تقديري في التقارير',
                            suffixText: 'ل.س',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _saving
                            ? const Center(child: CircularProgressIndicator())
                            : GradientButton(
                                label: 'حفظ الأسعار',
                                icon: Icons.save_rounded,
                                onPressed: _saveFees,
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SurfaceCard(
                    title: 'العبارات السريعة',
                    icon: Icons.bolt_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'تظهر كأزرار تحت حقل الخلاصة ونتيجة المتابعة. '
                          'وكل نص تحفظه بزيارة يُضاف هنا تلقائيًا ويتقدّم '
                          'ترتيبه كلما استخدمته أكثر.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.inkSoft,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SegmentedButton<PhraseKind>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: PhraseKind.summary,
                              label: Text('خلاصة الفحص'),
                            ),
                            ButtonSegment(
                              value: PhraseKind.outcome,
                              label: Text('نتيجة المتابعة'),
                            ),
                          ],
                          selected: {_kind},
                          onSelectionChanged: (s) {
                            setState(() => _kind = s.first);
                            _loadPhrases();
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _newPhraseController,
                                onSubmitted: (_) => _addPhrase(),
                                decoration: const InputDecoration(
                                  labelText: 'عبارة جديدة',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            IconButton.filled(
                              onPressed: _addPhrase,
                              icon: const Icon(Icons.add_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (_phrases.isEmpty)
                          const Text(
                            'لا توجد عبارات بعد — أضف واحدة أو احفظ زيارة '
                            'وستظهر هنا.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.inkSoft,
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final phrase in _phrases)
                                InputChip(
                                  label: Text(phrase),
                                  onDeleted: () => _deletePhrase(phrase),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

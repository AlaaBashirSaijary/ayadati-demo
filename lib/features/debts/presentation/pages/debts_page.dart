import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/di/injection.dart';
import '../../../../core/money/currency.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/whatsapp/whatsapp_service.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../clinics/presentation/providers/active_clinic_provider.dart';
import '../../../patients/presentation/pages/patient_detail_page.dart';
import '../../data/debts_local_datasource.dart';
import '../../domain/patient_debt.dart';

/// "الذمم": who still owes the clinic money, how much (per currency), since
/// when — with one-tap payment recording and a polite WhatsApp reminder.
class DebtsPage extends ConsumerStatefulWidget {
  const DebtsPage({super.key});

  @override
  ConsumerState<DebtsPage> createState() => _DebtsPageState();
}

class _DebtsPageState extends ConsumerState<DebtsPage> {
  static final _date = DateFormat('yyyy/MM/dd');
  List<PatientDebt> _debts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final debts = await sl<DebtsLocalDataSource>().list();
    if (!mounted) return;
    setState(() {
      _debts = debts;
      _loading = false;
    });
  }

  MoneyTotals get _grand {
    final t = MoneyTotals();
    for (final d in _debts) {
      for (final v in d.visits) {
        t.add(v.currency, v.remaining);
      }
    }
    return t;
  }

  Future<void> _pay(PatientDebt debt) async {
    final currencies = debt.owed.currencies;
    var currency = currencies.first;
    final controller = TextEditingController();
    final noteController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('دفعة من ${debt.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (currencies.length > 1)
                SegmentedButton<Currency>(
                  segments: [
                    for (final c in currencies)
                      ButtonSegment(value: c, label: Text(c.symbol)),
                  ],
                  selected: {currency},
                  onSelectionChanged: (s) => setLocal(() => currency = s.first),
                ),
              if (currencies.length > 1) const SizedBox(height: 12),
              Text(
                'المتبقي: ${currency.format(debt.owed.of(currency))}',
                style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'المبلغ المدفوع',
                  suffixText: currency.symbol,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظة (اختياري)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('تسجيل'),
            ),
          ],
        ),
      ),
    );
    final amount = double.tryParse(controller.text.trim().replaceAll(',', '.'));
    if (ok != true || amount == null || amount <= 0) return;
    final applied = await sl<DebtsLocalDataSource>().recordPayment(
      patientId: debt.patientId,
      currency: currency,
      amount: amount,
      note: noteController.text.trim().isEmpty
          ? null
          : noteController.text.trim(),
    );
    if (!mounted) return;
    AppSnack.success(
      context,
      applied < amount
          ? 'سُجّل ${currency.format(applied)} (كامل المتبقي).'
          : 'سُجّلت الدفعة ${currency.format(applied)}.',
    );
    _load();
  }

  Future<void> _remind(PatientDebt debt) async {
    final clinic = ref.read(activeClinicProvider).active?.name ?? 'العيادة';
    final message =
        'السلام عليكم ${debt.name}،\n'
        'نذكّركم بلطف بوجود مبلغ متبقٍّ لدى $clinic قدره '
        '${debt.owed.describe()}.\n'
        'نشكر تعاونكم، وبإمكانكم التواصل معنا لترتيب السداد.';
    final phone = debt.phone;
    final opened = phone == null || phone.trim().isEmpty
        ? await WhatsAppService.openUri(
            Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}'),
          )
        : await WhatsAppService.open(phone, message);
    if (!opened && mounted) AppSnack.error(context, 'تعذّر فتح واتساب.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الذمم والمبالغ المتبقية')),
      body: ResponsiveBody(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _debts.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    'لا توجد مبالغ متبقية. كل الكشفيات مدفوعة بالكامل.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.inkSoft),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'إجمالي المبالغ المتبقية',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _grand.describe(),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.danger,
                          ),
                        ),
                        Text(
                          '${_debts.length} مريض',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final d in _debts)
                    Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: AppShadows.card,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () => Navigator.of(context)
                                .push(
                                  MaterialPageRoute(
                                    builder: (_) => PatientDetailPage(
                                      patientId: d.patientId,
                                    ),
                                  ),
                                )
                                .then((_) => _load()),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        d.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        'منذ ${_date.format(d.oldest)} · '
                                        '${d.visits.length} زيارة',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.inkSoft,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  d.owed.describe(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.danger,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: () => _pay(d),
                                icon: const Icon(
                                  Icons.add_card_rounded,
                                  size: 18,
                                ),
                                label: const Text('تسجيل دفعة'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () => _remind(d),
                                icon: const Icon(Icons.chat_outlined, size: 18),
                                label: const Text('تذكير'),
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

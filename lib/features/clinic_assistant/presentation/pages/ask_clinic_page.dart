import 'package:flutter/material.dart';

import '../../../../core/ai/gemini_service.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../appointments/domain/usecases/get_monthly_appointment_counts.dart';
import '../../../patients/domain/usecases/get_new_patients_count.dart';
import '../../../patients/domain/usecases/get_patient_stats.dart';
import '../../../visits/domain/usecases/get_financial_report.dart';
import '../../../visits/domain/usecases/get_follow_ups_due.dart';

/// A natural-language Q&A page over the clinic's own local data — the
/// doctor asks in plain Arabic ("كم مريض جديد هالشهر؟"), and the AI answers
/// using ONLY a snapshot of real numbers gathered here, never anything it
/// invents. Still a suggestion, not a record: nothing here is saved or
/// printed, and the answer can be wrong if the AI misreads the snapshot.
class AskClinicPage extends StatefulWidget {
  const AskClinicPage({super.key});

  @override
  State<AskClinicPage> createState() => _AskClinicPageState();
}

class _AskClinicPageState extends State<AskClinicPage> {
  final _questionController = TextEditingController();
  bool _asking = false;
  String? _answer;
  String? _error;

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  /// Gathers this month's real numbers via the same use cases the reports
  /// pages already use, as a compact text block — never raw patient names
  /// beyond what follow-ups-due already surfaces elsewhere in the app.
  Future<String> _buildSnapshot() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final monthEnd = DateTime(now.year, now.month + 1);

    final statsResult = await sl<GetPatientStats>().call(const NoParams());
    final newPatientsResult = await sl<GetNewPatientsCount>().call(
      DateRangeParams(start: monthStart, end: monthEnd),
    );
    final followUpsResult = await sl<GetFollowUpsDue>().call(const NoParams());
    final financialResult = await sl<GetFinancialReport>().call(
      DateRangeParams(start: monthStart, end: monthEnd),
    );
    final appointmentsResult = await sl<GetMonthlyAppointmentCounts>().call(
      MonthRangeParams(start: monthStart, end: monthEnd),
    );

    final buffer = StringBuffer();

    statsResult.fold((_) {}, (stats) {
      buffer.writeln(
        'المرضى: الإجمالي ${stats.total}، نشط ${stats.active}، '
        'غير نشط ${stats.inactive}.',
      );
    });
    newPatientsResult.fold((_) {}, (count) {
      buffer.writeln('مرضى جدد هذا الشهر: $count.');
    });
    followUpsResult.fold((_) {}, (followUps) {
      final overdue = followUps.where((f) => f.isOverdue).length;
      buffer.writeln(
        'متابعات مستحقة حاليًا: ${followUps.length} (منها متأخرة: $overdue).',
      );
    });
    financialResult.fold((_) {}, (report) {
      buffer.writeln(
        'التقرير المالي لهذا الشهر: عدد الكشفيات المُسعّرة '
        '${report.pricedVisitCount}، إجمالي الرسوم ${report.fees.describe()}، '
        'المُحصَّل ${report.collected.describe()}، المتبقي ${report.remaining.describe()}.',
      );
    });
    appointmentsResult.fold((_) {}, (counts) {
      final parts = counts.entries
          .map((e) => '${e.key.label}: ${e.value}')
          .join('، ');
      buffer.writeln('عدد المواعيد هذا الشهر حسب النوع: $parts.');
    });

    return buffer.toString();
  }

  Future<void> _ask() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      setState(() => _error = 'اكتبي سؤالك أولًا.');
      return;
    }

    setState(() {
      _asking = true;
      _error = null;
      _answer = null;
    });

    final snapshot = await _buildSnapshot();
    if (!mounted) return;

    final prompt =
        'أنتِ مساعدة تحليل بيانات لعيادة طبية سورية. لديكِ البيانات '
        'التالية عن العيادة فقط، وممنوع عليكِ إضافة أي رقم أو معلومة غير '
        'موجودة فيها:\n\n$snapshot\n\nسؤال الطبيب: "$question"\n\n'
        'أجيبي بجملة أو جملتين بالعربية بالاعتماد على هذه البيانات حصرًا. '
        'إذا كان السؤال لا يمكن الإجابة عليه من هذه البيانات، قولي ذلك '
        'بصراحة بدل تخمين رقم.';

    final result = await GeminiService.instance.generateText(prompt);
    if (!mounted) return;

    setState(() {
      _asking = false;
      if (result == null) {
        _error =
            'تعذّر الاتصال بالمساعد الذكي — تأكدي من الإنترنت.\n'
            '(${GeminiService.instance.lastError})';
      } else {
        _answer = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اسأل عن عيادتك')),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const Text(
              'اطرحي سؤالًا عن أرقام هذا الشهر (المرضى، المتابعات، '
              'المواعيد، أو التقرير المالي) وسيجيب المساعد الذكي بالاعتماد '
              'على بيانات عيادتك المحلية فقط.',
              style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _questionController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'سؤالك',
                hintText: 'مثال: كم مريض جديد سجّلنا هالشهر؟',
              ),
              onSubmitted: (_) => _asking ? null : _ask(),
            ),
            const SizedBox(height: AppSpacing.md),
            _asking
                ? const Center(child: CircularProgressIndicator())
                : FilledButton.icon(
                    onPressed: _ask,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text('اسأل'),
                  ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 13),
              ),
            ],
            if (_answer != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppShadows.card,
                ),
                child: Text(_answer!, style: const TextStyle(fontSize: 14)),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'اقتراح مبني على أرقام العيادة — راجعي البيانات الأصلية '
                'قبل اتخاذ أي قرار مهم.',
                style: TextStyle(fontSize: 11, color: AppColors.inkSoft),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

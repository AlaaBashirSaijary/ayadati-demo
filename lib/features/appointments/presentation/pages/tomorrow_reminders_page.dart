import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/whatsapp/whatsapp_service.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../clinics/presentation/providers/active_clinic_provider.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/usecases/get_appointments_for_day.dart';
import '../util/appointment_messages.dart';

/// Tomorrow's appointments as a send-list: one tap per patient opens
/// WhatsApp with the reminder already written, and a sent patient is marked
/// so the doctor can work down the list without losing their place. The
/// marks are remembered per appointment and day.
class TomorrowRemindersPage extends ConsumerStatefulWidget {
  const TomorrowRemindersPage({super.key});

  @override
  ConsumerState<TomorrowRemindersPage> createState() =>
      _TomorrowRemindersPageState();
}

class _TomorrowRemindersPageState extends ConsumerState<TomorrowRemindersPage> {
  List<Appointment> _appointments = [];
  final Set<int> _sent = {};
  bool _loading = true;

  late final DateTime _day = () {
    final t = DateTime.now().add(const Duration(days: 1));
    return DateTime(t.year, t.month, t.day);
  }();

  String _key(int id) =>
      'reminder_sent_${id}_${_day.year}-${_day.month}-${_day.day}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await sl<GetAppointmentsForDay>().call(_day);
    final prefs = await SharedPreferences.getInstance();
    final list = result.fold(
      (_) => <Appointment>[],
      (a) => a.where((x) => x.status == AppointmentStatus.scheduled).toList(),
    );
    for (final a in list) {
      if (a.id != null && (prefs.getBool(_key(a.id!)) ?? false)) {
        _sent.add(a.id!);
      }
    }
    if (!mounted) return;
    setState(() {
      _appointments = list;
      _loading = false;
    });
  }

  Future<void> _send(Appointment appointment) async {
    final phone = appointment.patientPhone;
    if (phone == null || WhatsAppService.normalize(phone) == null) {
      AppSnack.info(context, 'لا يوجد رقم هاتف لهذا المريض.');
      return;
    }
    final message = AppointmentMessages.build(
      kind: AppointmentMessageKind.reminder,
      appointment: appointment,
      clinicName: ref.read(activeClinicProvider).active?.name ?? '',
    );
    final opened = await WhatsAppService.open(phone, message);
    if (!mounted) return;
    if (!opened) {
      AppSnack.error(context, 'تعذّر فتح واتساب على هذا الجهاز.');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(appointment.id!), true);
    if (mounted) setState(() => _sent.add(appointment.id!));
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _appointments.where((a) => !_sent.contains(a.id)).length;

    return Scaffold(
      appBar: AppBar(title: const Text('تذكيرات الغد')),
      body: ResponsiveBody(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _appointments.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    'لا توجد مواعيد مجدولة غدًا.',
                    style: TextStyle(color: AppColors.inkSoft),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Text(
                    remaining == 0
                        ? 'تم إرسال كل التذكيرات ✓'
                        : 'متبقٍ $remaining من ${_appointments.length} تذكير',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: remaining == 0 ? AppColors.ok : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'واتساب لا يسمح بالإرسال التلقائي — اضغط إرسال في كل محادثة تُفتح.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final a in _appointments)
                    _ReminderTile(
                      appointment: a,
                      sent: _sent.contains(a.id),
                      onSend: () => _send(a),
                    ),
                ],
              ),
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.appointment,
    required this.sent,
    required this.onSend,
  });

  final Appointment appointment;
  final bool sent;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final hasPhone =
        WhatsAppService.normalize(appointment.patientPhone) != null;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.field + 2),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.06)),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.aqua.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              AppointmentMessages.timeLabel(appointment.scheduledAt),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: AppColors.aquaDeep,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment.patientName ?? 'مريض',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  hasPhone ? appointment.patientPhone! : 'لا يوجد رقم هاتف',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: hasPhone ? AppColors.inkSoft : AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
          if (sent)
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.ok, size: 18),
                SizedBox(width: 4),
                Text(
                  'أُرسل',
                  style: TextStyle(
                    color: AppColors.ok,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            )
          else
            FilledButton.icon(
              onPressed: hasPhone ? onSend : null,
              icon: const Icon(Icons.chat_rounded, size: 16),
              label: const Text('تذكير'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                backgroundColor: const Color(0xFF1FA855),
              ),
            ),
        ],
      ),
    );
  }
}

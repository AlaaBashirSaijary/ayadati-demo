import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/whatsapp/whatsapp_service.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../../../clinics/presentation/providers/active_clinic_provider.dart';
import '../util/appointment_messages.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../doctors/presentation/providers/doctors_provider.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/usecases/get_follow_up_days.dart';
import '../../domain/usecases/get_half_price_days.dart';
import '../../domain/usecases/set_follow_up_days.dart';
import '../../domain/usecases/set_half_price_days.dart';
import '../../../visits/presentation/pages/visit_form_page.dart';
import '../../../visits/presentation/providers/follow_ups_provider.dart';
import '../providers/appointments_provider.dart';
import '../widgets/appointment_type_style.dart';
import 'appointment_form_page.dart';
import 'booking_from_message_page.dart';
import 'queue_display_page.dart';
import 'tomorrow_reminders_page.dart';

/// Day-by-day view of scheduled appointments — the future-looking
/// counterpart to the patients dashboard, which only shows history.
class AppointmentsPage extends ConsumerWidget {
  const AppointmentsPage({super.key});

  static final _dayFormat = DateFormat('EEEE، d MMMM', 'ar');
  static final _timeFormat = DateFormat('h:mm a', 'ar');

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }

  /// One dialog for both booking windows: how long a re-check stays free,
  /// and how much further after that it stays half price before counting
  /// as a fresh, full-price consultation again — both fully doctor-set, no
  /// fixed defaults baked into the flow itself.
  Future<void> _editBookingWindows(BuildContext context) async {
    final followUpResult = await sl<GetFollowUpDays>().call(const NoParams());
    final halfPriceResult = await sl<GetHalfPriceDays>().call(const NoParams());
    if (!context.mounted) return;

    final followUpController = TextEditingController(
      text: followUpResult.fold((_) => '30', (days) => '$days'),
    );
    final halfPriceController = TextEditingController(
      text: halfPriceResult.fold((_) => '60', (days) => '$days'),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('فترات حجز المواعيد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'عدد الأيام بعد المعاينة التي تُعتبر خلالها مواعيد المراجعة '
              'مجانية تلقائيًا.',
              style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: followUpController,
              autofocus: true,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'مراجعة مجانية (يوم)',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'عدد الأيام الإضافية بعدها — حتى هذا الحد تُعتبر المواعيد '
              '"مراجعة بنصف السعر"، وبعده تعود معاينة كاملة.',
              style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: halfPriceController,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'مراجعة بنصف السعر حتى (يوم)',
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
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final followUpDays = int.tryParse(followUpController.text.trim());
    final halfPriceDays = int.tryParse(halfPriceController.text.trim());

    if (followUpDays != null && followUpDays > 0) {
      await sl<SetFollowUpDays>().call(followUpDays);
    }
    if (halfPriceDays != null && halfPriceDays > 0) {
      await sl<SetHalfPriceDays>().call(halfPriceDays);
    }
  }

  Future<void> _sendWhatsApp(
    BuildContext context,
    WidgetRef ref,
    Appointment appointment,
    AppointmentMessageKind kind,
  ) async {
    final phone = appointment.patientPhone;
    if (WhatsAppService.normalize(phone) == null) {
      AppSnack.info(context, 'لا يوجد رقم هاتف مسجَّل لهذا المريض.');
      return;
    }
    final message = AppointmentMessages.build(
      kind: kind,
      appointment: appointment,
      clinicName: ref.read(activeClinicProvider).active?.name ?? '',
    );
    final opened = await WhatsAppService.open(phone!, message);
    if (!opened && context.mounted) {
      AppSnack.error(context, 'تعذّر فتح واتساب على هذا الجهاز.');
    }
  }

  /// Confirms, then deletes and reports whether it actually happened — used
  /// directly as [Dismissible.confirmDismiss] so the swipe-away animation
  /// only plays through once the delete is real, instead of firing the
  /// dialog and snapping back regardless of the answer.
  Future<bool> _confirmAndDelete(
    BuildContext context,
    WidgetRef ref,
    Appointment appointment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الموعد؟'),
        content: const Text('لا يمكن التراجع عن هذا الإجراء.'),
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
    if (confirmed != true) return false;

    await ref.read(appointmentsProvider.notifier).delete(appointment.id!);
    return true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appointmentsProvider);
    final notifier = ref.read(appointmentsProvider.notifier);
    final day = state.day ?? DateTime.now();
    final doctors = ref
        .watch(doctorsProvider)
        .items
        .where((d) => d.isActive)
        .toList();
    final visible = state.visibleAppointments;

    final fullCount = visible
        .where((a) => a.type == AppointmentType.consultation)
        .length;
    final halfCount = visible
        .where((a) => a.type == AppointmentType.halfConsultation)
        .length;
    final freeCount = visible
        .where((a) => a.type == AppointmentType.followUp)
        .length;

    return Scaffold(
      body: Column(
        children: [
          _AppointmentsHeader(
            onSettings: () => _editBookingWindows(context),
            onQueueDisplay: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const QueueDisplayPage())),
            onFromMessage: () async {
              final saved = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => const BookingFromMessagePage(),
                ),
              );
              if (saved == true) notifier.loadDay(day);
            },
            onReminders: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TomorrowRemindersPage()),
            ),
            total: visible.length,
            full: fullCount,
            half: halfCount,
            free: freeCount,
          ),
          Transform.translate(
            offset: const Offset(0, -20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _DayNavigator(
                day: day,
                dayFormat: _dayFormat,
                isToday: _isToday(day),
                onPrevious: () =>
                    notifier.loadDay(day.subtract(const Duration(days: 1))),
                onNext: () =>
                    notifier.loadDay(day.add(const Duration(days: 1))),
                onToday: () {
                  final now = DateTime.now();
                  notifier.loadDay(DateTime(now.year, now.month, now.day));
                },
              ),
            ),
          ),
          if (doctors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ChoiceChip(
                      label: const Text('كل الأطباء'),
                      selected: state.selectedDoctorId == null,
                      onSelected: (_) => notifier.filterByDoctor(null),
                    ),
                    for (final doctor in doctors) ...[
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: Text(doctor.name),
                        selected: state.selectedDoctorId == doctor.id,
                        onSelected: (_) => notifier.filterByDoctor(doctor.id),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                ? const _EmptyDay()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.xl,
                    ),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final appointment = visible[index];
                      return FadeSlideIn(
                        delay: Duration(milliseconds: 40 * index),
                        child: _AppointmentCard(
                          appointment: appointment,
                          timeFormat: _timeFormat,
                          onTap: () async {
                            final saved = await Navigator.of(context)
                                .push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => AppointmentFormPage(
                                      appointment: appointment,
                                    ),
                                  ),
                                );
                            if (saved == true) notifier.loadDay(day);
                          },
                          onWhatsApp: (kind) =>
                              _sendWhatsApp(context, ref, appointment, kind),
                          onConfirmDelete: () =>
                              _confirmAndDelete(context, ref, appointment),
                          onQuickComplete: () => notifier.save(
                            appointment.copyWith(
                              status: AppointmentStatus.completed,
                            ),
                          ),
                          onStartVisit: () async {
                            final saved = await Navigator.of(context)
                                .push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => VisitFormPage(
                                      patientId: appointment.patientId,
                                    ),
                                  ),
                                );
                            if (saved == true) {
                              await notifier.save(
                                appointment.copyWith(
                                  status: AppointmentStatus.completed,
                                ),
                              );
                              ref.read(followUpsProvider.notifier).refresh();
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: GradientButton(
        label: 'موعد جديد',
        icon: Icons.add_rounded,
        onPressed: () async {
          final saved = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => AppointmentFormPage(initialDay: day),
            ),
          );
          if (saved == true) notifier.loadDay(day);
        },
      ),
    );
  }
}

class _AppointmentsHeader extends StatelessWidget {
  const _AppointmentsHeader({
    required this.onSettings,
    required this.onQueueDisplay,
    required this.onFromMessage,
    required this.onReminders,
    required this.total,
    required this.full,
    required this.half,
    required this.free,
  });

  final VoidCallback onSettings;
  final VoidCallback onQueueDisplay;
  final VoidCallback onFromMessage;
  final VoidCallback onReminders;
  final int total;
  final int full;
  final int half;
  final int free;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.aquaGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xl + 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const BrandMark(size: 34),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Text(
                      'المواعيد',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'حجز من رسالة واتساب',
                    icon: const Icon(Icons.chat_rounded, color: Colors.white),
                    onPressed: onFromMessage,
                  ),
                  IconButton(
                    tooltip: 'تذكيرات الغد',
                    icon: const Icon(
                      Icons.notifications_active_rounded,
                      color: Colors.white,
                    ),
                    onPressed: onReminders,
                  ),
                  IconButton(
                    tooltip: 'شاشة الانتظار',
                    icon: const Icon(Icons.tv_rounded, color: Colors.white),
                    onPressed: onQueueDisplay,
                  ),
                  IconButton(
                    tooltip: 'فترات حجز المواعيد',
                    icon: const Icon(Icons.timer_outlined, color: Colors.white),
                    onPressed: onSettings,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _HeaderStat(
                      icon: Icons.event_note_rounded,
                      value: '$total',
                      label: 'مواعيد اليوم',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _HeaderStat(
                      icon: AppointmentType.consultation.icon,
                      value: '$full',
                      label: 'معاينة',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _HeaderStat(
                      icon: AppointmentType.halfConsultation.icon,
                      value: '$half',
                      label: 'مراجعة ½',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _HeaderStat(
                      icon: AppointmentType.followUp.icon,
                      value: '$free',
                      label: 'مراجعة مجانية',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Floats over the header's bottom edge, matching the dashboard's
/// overlapping search-card treatment instead of a flat bar stuck under
/// the app bar.
class _DayNavigator extends StatelessWidget {
  const _DayNavigator({
    required this.day,
    required this.dayFormat,
    required this.isToday,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final DateTime day;
  final DateFormat dayFormat;
  final bool isToday;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: onPrevious,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dayFormat.format(day),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (!isToday)
                  GestureDetector(
                    onTap: onToday,
                    child: const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text(
                        'العودة لليوم',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.aqua,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.sky,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_available_rounded,
              color: AppColors.aqua,
              size: 32,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'لا توجد مواعيد في هذا اليوم',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
          const SizedBox(height: 4),
          const Text(
            'اضغطي "موعد جديد" لإضافة أول موعد',
            style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.timeFormat,
    required this.onTap,
    required this.onWhatsApp,
    required this.onConfirmDelete,
    required this.onQuickComplete,
    required this.onStartVisit,
  });

  final Appointment appointment;
  final DateFormat timeFormat;
  final VoidCallback onTap;

  /// Opens WhatsApp with a ready message (confirm / remind / reschedule) —
  /// patients mostly book and talk over WhatsApp, so this lives on the card.
  final void Function(AppointmentMessageKind kind) onWhatsApp;

  /// Shows the confirm dialog and, if accepted, deletes — returns whether
  /// it actually happened, so the swipe-away animation only completes on
  /// a real delete instead of snapping back after the fact.
  final Future<bool> Function() onConfirmDelete;

  /// Marks the appointment "تمت الزيارة" directly from the card — the
  /// common case (patient was seen, nothing else about the booking
  /// changed) shouldn't cost a screen transition through the full edit
  /// form just to flip one status.
  final VoidCallback onQuickComplete;

  /// Jumps straight into recording this patient's exam instead of making
  /// staff re-search for a patient they were just looking at on this very
  /// card.
  final VoidCallback onStartVisit;

  Color get _statusColor => switch (appointment.status) {
    AppointmentStatus.scheduled => AppColors.focus,
    AppointmentStatus.completed => AppColors.ok,
    AppointmentStatus.cancelled => AppColors.danger,
  };

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(appointment.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => onConfirmDelete(),
      // The delete already completes (and the provider's list already
      // shrinks) before confirmDismiss resolves, so there's nothing left
      // to do here — this just satisfies Dismissible's expectation that a
      // dismissed key's widget is gone by the next frame.
      onDismissed: (_) {},
      background: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        alignment: AlignmentDirectional.centerEnd,
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppColors.danger,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppShadows.card,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    timeFormat.format(appointment.scheduledAt),
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _statusColor,
                      fontSize: 12,
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
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            appointment.status.label,
                            style: TextStyle(fontSize: 11, color: _statusColor),
                          ),
                          const Text(
                            ' · ',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.inkSoft,
                            ),
                          ),
                          Icon(
                            appointment.type.icon,
                            size: 12,
                            color: appointment.type.color,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            appointment.type.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: appointment.type.color,
                            ),
                          ),
                          if (appointment.doctorName != null) ...[
                            const Text(
                              ' · ',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.inkSoft,
                              ),
                            ),
                            Text(
                              appointment.doctorName!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.inkSoft,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (appointment.notes != null &&
                          appointment.notes!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            appointment.notes!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (appointment.status == AppointmentStatus.scheduled) ...[
                  PopupMenuButton<AppointmentMessageKind>(
                    tooltip: 'رسالة واتساب',
                    onSelected: onWhatsApp,
                    icon: const Icon(
                      Icons.chat_rounded,
                      color: Color(0xFF1FA855),
                      size: 20,
                    ),
                    itemBuilder: (_) => [
                      for (final kind in AppointmentMessageKind.values)
                        PopupMenuItem(value: kind, child: Text(kind.label)),
                    ],
                  ),
                  _QuickActionButton(
                    tooltip: 'ابدئي الفحص',
                    icon: Icons.medical_information_outlined,
                    color: AppColors.focus,
                    onTap: onStartVisit,
                  ),
                  const SizedBox(width: 4),
                  _QuickActionButton(
                    tooltip: 'تمت الزيارة',
                    icon: Icons.check_circle_outline_rounded,
                    color: AppColors.ok,
                    onTap: onQuickComplete,
                  ),
                ] else
                  const Icon(
                    Icons.chevron_left_rounded,
                    color: AppColors.lens,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small round icon affordance for the two one-tap actions on a scheduled
/// appointment card — deliberately tiny (not a labeled button) so both fit
/// beside each other without crowding the card's existing content.
class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.1),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}

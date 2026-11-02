import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../../../clinics/presentation/providers/active_clinic_provider.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/usecases/get_appointments_for_day.dart';

/// A read-only, kiosk-style board meant to be left open facing the waiting
/// room — propped on a second iPad, or handed to the reception desk — so
/// patients can see where they are in line without asking staff directly.
/// Deliberately shows nothing but a name, a time, and a queue position: no
/// medical details, no editing. Refreshes itself on a timer instead of
/// needing someone to pull it down, since nobody is expected to be
/// interacting with the device it's shown on.
class QueueDisplayPage extends ConsumerStatefulWidget {
  const QueueDisplayPage({super.key});

  @override
  ConsumerState<QueueDisplayPage> createState() => _QueueDisplayPageState();
}

class _QueueDisplayPageState extends ConsumerState<QueueDisplayPage> {
  static const _refreshInterval = Duration(seconds: 20);
  static final _timeFormat = DateFormat('h:mm a', 'ar');

  List<Appointment> _appointments = [];
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(_refreshInterval, (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final today = DateTime.now();
    final result = await sl<GetAppointmentsForDay>().call(
      DateTime(today.year, today.month, today.day),
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      result.fold((_) {}, (appointments) {
        final active =
            appointments
                .where((a) => a.status != AppointmentStatus.cancelled)
                .toList()
              ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
        _appointments = active;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final clinicName = ref.watch(activeClinicProvider).active?.name ?? '';

    // The first not-yet-completed appointment in time order reads as
    // "who's up now" — everyone after it is still waiting, everyone before
    // it (necessarily completed, since the list is in order) has been seen.
    final currentIndex = _appointments.indexWhere(
      (a) => a.status != AppointmentStatus.completed,
    );

    return Scaffold(
      backgroundColor: AppColors.mist,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            const BrandMark(size: 28),
            const SizedBox(width: AppSpacing.sm),
            Text(clinicName.isEmpty ? 'شاشة الانتظار' : clinicName),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _appointments.isEmpty
            ? const _EmptyQueue()
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: _appointments.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final appointment = _appointments[index];
                  return _QueueRow(
                    position: index + 1,
                    appointment: appointment,
                    timeFormat: _timeFormat,
                    isCurrent: index == currentIndex,
                  );
                },
              ),
      ),
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.sky,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_available_rounded,
              color: AppColors.aqua,
              size: 44,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'لا توجد مواعيد اليوم',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.position,
    required this.appointment,
    required this.timeFormat,
    required this.isCurrent,
  });

  final int position;
  final Appointment appointment;
  final DateFormat timeFormat;
  final bool isCurrent;

  bool get _done => appointment.status == AppointmentStatus.completed;

  @override
  Widget build(BuildContext context) {
    final color = _done
        ? AppColors.inkSoft
        : (isCurrent ? AppColors.aquaDeep : AppColors.ink);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _done ? 0.55 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isCurrent
              ? Border.all(color: AppColors.aqua, width: 2)
              : null,
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isCurrent
                    ? AppColors.aqua
                    : AppColors.sky.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$position',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: isCurrent ? Colors.white : AppColors.aquaDeep,
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
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: color,
                      decoration: _done
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeFormat.format(appointment.scheduledAt),
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            _StatusPill(done: _done, isCurrent: isCurrent),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.done, required this.isCurrent});

  final bool done;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final (label, color) = done
        ? ('تم', AppColors.ok)
        : isCurrent
        ? ('قيد الفحص الآن', AppColors.aqua)
        : ('بالانتظار', AppColors.inkSoft);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

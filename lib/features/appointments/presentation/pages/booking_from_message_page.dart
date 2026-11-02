import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../patients/domain/entities/patient.dart';
import '../../../patients/domain/usecases/get_patients.dart';
import '../../../patients/presentation/pages/patient_form_page.dart';
import '../../domain/services/booking_request_parser.dart';
import '../util/appointment_messages.dart';
import 'appointment_form_page.dart';

/// Turns a patient's WhatsApp message into a booking: the doctor copies the
/// message, pastes it here, and the booking form opens already filled in
/// (patient, day, time, reason). Reading is local and rule-based (see
/// BookingRequestParser), so it works offline and never guesses silently —
/// everything it found is shown first and stays editable in the form.
class BookingFromMessagePage extends StatefulWidget {
  const BookingFromMessagePage({super.key});

  @override
  State<BookingFromMessagePage> createState() => _BookingFromMessagePageState();
}

class _BookingFromMessagePageState extends State<BookingFromMessagePage> {
  final _controller = TextEditingController();
  BookingRequest? _request;
  List<Patient> _matches = [];
  Patient? _selected;
  bool _searching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      if (mounted) {
        AppSnack.info(context, 'الحافظة فارغة — انسخ رسالة المريض أولًا.');
      }
      return;
    }
    _controller.text = text;
    await _analyze();
  }

  Future<void> _analyze() async {
    final request = BookingRequestParser.parse(_controller.text);
    setState(() {
      _request = request;
      _matches = [];
      _selected = null;
      _searching = true;
    });

    final found = <Patient>[];
    Future<void> search(String query) async {
      final result = await sl<GetPatients>().call(
        GetPatientsParams(
          query: query,
          status: PatientStatusFilter.active,
          perPage: 5,
        ),
      );
      result.fold((_) {}, (page) {
        for (final p in page.items) {
          if (!found.any((f) => f.id == p.id)) found.add(p);
        }
      });
    }

    // Phone is the reliable key (a stored number may have spaces or a
    // different prefix, so match on its last nine digits); name is the
    // fallback for a patient who writes from a relative's phone.
    if (request.phone != null) {
      await search(request.phone!.substring(request.phone!.length - 9));
    }
    if (request.name != null) await search(request.name!);

    if (!mounted) return;
    setState(() {
      _matches = found;
      _selected = found.length == 1 ? found.first : null;
      _searching = false;
    });
  }

  Future<void> _continue(Patient patient) async {
    final request = _request!;
    final time = request.time;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AppointmentFormPage(
          preselectedPatient: patient,
          initialDay: request.day,
          initialTime: time == null
              ? null
              : TimeOfDay(hour: time.hour, minute: time.minute),
          initialNotes: [
            'طلب عبر واتساب',
            if (request.reason != null) request.reason!,
          ].join(' — '),
        ),
      ),
    );
    if (saved == true && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _createPatient() async {
    final request = _request!;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PatientFormPage(
          initialName: request.name,
          initialPhone: request.phone,
          onCreated: (patient) async {
            // Close the patient form first, then continue the booking with
            // the patient it just created.
            Navigator.of(context).pop(true);
            await _continue(patient);
          },
        ),
      ),
    );
  }

  String _dayText(DateTime day) => AppointmentMessages.dayLabel(day);

  @override
  Widget build(BuildContext context) {
    final request = _request;
    return Scaffold(
      appBar: AppBar(title: const Text('حجز من رسالة واتساب')),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            SurfaceCard(
              title: 'رسالة المريض',
              icon: Icons.chat_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _controller,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: 'الصق رسالة المريض هنا…',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _paste,
                          icon: const Icon(
                            Icons.content_paste_rounded,
                            size: 18,
                          ),
                          label: const Text('لصق من الحافظة'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _analyze,
                          icon: const Icon(
                            Icons.auto_fix_high_rounded,
                            size: 18,
                          ),
                          label: const Text('تحليل'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (request != null) ...[
              const SizedBox(height: AppSpacing.md),
              SurfaceCard(
                title: 'ما فهمناه من الرسالة',
                icon: Icons.fact_check_rounded,
                child: request.isEmpty
                    ? const Text(
                        'لم نجد اسمًا أو رقمًا أو موعدًا في هذه الرسالة. '
                        'يمكنك الحجز يدويًا من "موعد جديد".',
                        style: TextStyle(color: AppColors.inkSoft, height: 1.5),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (request.name != null)
                            _Found(Icons.person_rounded, request.name!),
                          if (request.phone != null)
                            _Found(Icons.phone_rounded, request.phone!),
                          if (request.day != null)
                            _Found(Icons.event_rounded, _dayText(request.day!)),
                          if (request.time != null)
                            _Found(
                              Icons.schedule_rounded,
                              request.hour != null
                                  ? AppointmentMessages.timeLabel(
                                      DateTime(
                                        2000,
                                        1,
                                        1,
                                        request.time!.hour,
                                        request.time!.minute,
                                      ),
                                    )
                                  : (request.period == 'morning'
                                        ? 'فترة صباحية'
                                        : 'فترة مسائية'),
                            ),
                          if (request.reason != null)
                            _Found(Icons.notes_rounded, request.reason!),
                        ],
                      ),
              ),
              const SizedBox(height: AppSpacing.md),
              SurfaceCard(
                title: 'المريض',
                icon: Icons.badge_rounded,
                child: _searching
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_matches.isEmpty)
                            const Text(
                              'لا يوجد مريض مطابق بالملفات الحالية.',
                              style: TextStyle(color: AppColors.inkSoft),
                            ),
                          RadioGroup<int>(
                            groupValue: _selected?.id,
                            onChanged: (id) => setState(
                              () => _selected = _matches.firstWhere(
                                (p) => p.id == id,
                              ),
                            ),
                            child: Column(
                              children: [
                                for (final patient in _matches)
                                  RadioListTile<int>(
                                    value: patient.id!,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      patient.fullName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: patient.phone == null
                                        ? null
                                        : Text(
                                            patient.phone!,
                                            textDirection: TextDirection.ltr,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          if (_selected != null)
                            GradientButton(
                              label: 'متابعة إلى الحجز',
                              icon: Icons.arrow_back_rounded,
                              onPressed: () => _continue(_selected!),
                            ),
                          const SizedBox(height: AppSpacing.sm),
                          OutlinedButton.icon(
                            onPressed: _createPatient,
                            icon: const Icon(
                              Icons.person_add_alt_1_rounded,
                              size: 18,
                            ),
                            label: const Text('مريض جديد بهذه البيانات'),
                          ),
                        ],
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Found extends StatelessWidget {
  const _Found(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.aqua.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.aquaDeep),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

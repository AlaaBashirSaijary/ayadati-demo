import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../doctors/presentation/providers/doctors_provider.dart';
import '../../../patients/domain/entities/patient.dart';
import '../../../patients/domain/usecases/get_patients.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/usecases/find_appointment_conflict.dart';
import '../../domain/usecases/get_follow_up_suggestion.dart';
import '../providers/appointments_provider.dart';
import '../widgets/appointment_type_style.dart';

/// Books a new appointment, or edits an existing one when [appointment] is
/// passed — the same "one form, id decides create vs. update" convention
/// VisitFormPage uses.
class AppointmentFormPage extends ConsumerStatefulWidget {
  const AppointmentFormPage({
    super.key,
    this.appointment,
    this.initialDay,
    this.preselectedPatient,
    this.initialTime,
    this.initialNotes,
  });

  final Appointment? appointment;

  /// Pre-fills the date when opened from a specific day's list, so booking
  /// doesn't default to today when the doctor is already looking at a
  /// future date.
  final DateTime? initialDay;

  /// Skips the patient search step — used when this form is opened right
  /// after creating that patient (see PatientFormPage's "book now?" prompt).
  final Patient? preselectedPatient;

  /// Pre-fill from a pasted WhatsApp booking request (see
  /// BookingFromMessagePage) — only used for a brand-new booking.
  final TimeOfDay? initialTime;
  final String? initialNotes;

  @override
  ConsumerState<AppointmentFormPage> createState() =>
      _AppointmentFormPageState();
}

class _AppointmentFormPageState extends ConsumerState<AppointmentFormPage> {
  final _notesController = TextEditingController();
  final _patientSearchController = TextEditingController();

  Patient? _selectedPatient;
  List<Patient> _patientResults = [];
  bool _searching = false;
  late DateTime _date;
  late TimeOfDay _time;
  AppointmentStatus _status = AppointmentStatus.scheduled;
  AppointmentType _type = AppointmentType.consultation;
  int? _doctorId;
  bool _saving = false;
  String? _error;

  bool _loadingSuggestion = false;
  FollowUpSuggestion? _suggestion;

  bool get _isEditing => widget.appointment != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.appointment;
    if (existing != null) {
      _date = DateTime(
        existing.scheduledAt.year,
        existing.scheduledAt.month,
        existing.scheduledAt.day,
      );
      _time = TimeOfDay.fromDateTime(existing.scheduledAt);
      _status = existing.status;
      _type = existing.type;
      _doctorId = existing.doctorId;
      _notesController.text = existing.notes ?? '';
      _selectedPatient = Patient(
        id: existing.patientId,
        fullName: existing.patientName ?? 'مريض',
        phone: existing.patientPhone,
      );
      _patientSearchController.text = existing.patientName ?? '';
    } else {
      final day = widget.initialDay ?? DateTime.now();
      _date = DateTime(day.year, day.month, day.day);
      _time = widget.initialTime ?? TimeOfDay.now();
      _notesController.text = widget.initialNotes ?? '';

      final preselected = widget.preselectedPatient;
      if (preselected != null) {
        _selectedPatient = preselected;
        _patientSearchController.text = preselected.fullName;
        _loadSuggestion(preselected.id!);
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _patientSearchController.dispose();
    super.dispose();
  }

  Future<void> _searchPatients(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _patientResults = []);
      return;
    }
    setState(() => _searching = true);
    final result = await sl<GetPatients>().call(
      GetPatientsParams(
        query: query.trim(),
        status: PatientStatusFilter.active,
        perPage: 8,
      ),
    );
    if (!mounted) return;
    setState(() {
      _searching = false;
      _patientResults = result.fold((failure) => [], (page) => page.items);
    });
  }

  /// Only relevant for new bookings — an existing appointment's type stays
  /// whatever was saved unless the nurse explicitly changes it.
  Future<void> _loadSuggestion(int patientId) async {
    setState(() => _loadingSuggestion = true);
    final result = await sl<GetFollowUpSuggestion>().call(patientId);
    if (!mounted) return;
    result.fold((failure) => setState(() => _loadingSuggestion = false), (
      suggestion,
    ) {
      setState(() {
        _loadingSuggestion = false;
        _suggestion = suggestion;
        _type = suggestion.suggestedType;
      });
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    final patient = _selectedPatient;
    if (patient?.id == null) {
      setState(() => _error = 'اختاري مريضًا أولًا.');
      return;
    }

    final scheduledAt = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );

    final conflictResult = await sl<FindAppointmentConflict>().call(
      FindAppointmentConflictParams(
        scheduledAt: scheduledAt,
        excludeId: widget.appointment?.id,
      ),
    );
    final conflict = conflictResult.fold((_) => null, (a) => a);
    if (conflict != null) {
      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('تعارض في الموعد'),
          content: Text(
            'يوجد موعد آخر محجوز لـ"${conflict.patientName ?? 'مريض آخر'}" '
            'في نفس هذا التوقيت. هل تريدين الحجز رغم ذلك؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'حجز رغم التعارض',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    if (!mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final appointment = Appointment(
      id: widget.appointment?.id,
      patientId: patient!.id!,
      scheduledAt: scheduledAt,
      status: _status,
      type: _type,
      doctorId: _doctorId,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    final error = await ref
        .read(appointmentsProvider.notifier)
        .save(appointment);

    if (!mounted) return;

    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  String _priceLabel(AppointmentType type) => switch (type) {
    AppointmentType.consultation => 'بدفع كامل',
    AppointmentType.halfConsultation => 'نصف الأجرة',
    AppointmentType.followUp => 'مجانية',
  };

  String? _suggestionHint() {
    final suggestion = _suggestion;
    if (suggestion == null) return null;
    if (suggestion.lastConsultationDate == null) {
      return 'لا توجد معاينة سابقة — مقترحة كـ"معاينة".';
    }
    final daysSince = DateTime.now()
        .difference(suggestion.lastConsultationDate!)
        .inDays;
    switch (suggestion.suggestedType) {
      case AppointmentType.followUp:
        final remaining = suggestion.followUpDays - daysSince;
        return 'ضمن فترة المراجعة المجانية (متبقّي ${remaining < 0 ? 0 : remaining} يوم).';
      case AppointmentType.halfConsultation:
        final remaining = suggestion.halfPriceDays - daysSince;
        return 'انتهت فترة المراجعة المجانية — ضمن فترة المراجعة بنصف السعر '
            '(متبقّي ${remaining < 0 ? 0 : remaining} يوم).';
      case AppointmentType.consultation:
        return 'انتهت فترة المراجعة بنصف السعر (${suggestion.halfPriceDays} يوم) منذ آخر معاينة.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd');
    final doctors = ref
        .watch(doctorsProvider)
        .items
        .where((d) => d.isActive)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'تعديل الموعد' : 'موعد جديد')),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const Text(
              'المريض',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(height: 6),
            if (_selectedPatient != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.sky,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_rounded, color: AppColors.aqua),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedPatient!.fullName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (_selectedPatient!.phone != null)
                            Text(
                              _selectedPatient!.phone!,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.inkSoft,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!_isEditing)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(() {
                          _selectedPatient = null;
                          _patientSearchController.clear();
                          _suggestion = null;
                        }),
                      ),
                  ],
                ),
              ),
            ] else ...[
              TextField(
                controller: _patientSearchController,
                onChanged: _searchPatients,
                decoration: InputDecoration(
                  hintText: 'ابحث باسم المريض أو رقم الهاتف...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
              if (_patientResults.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: AppShadows.card,
                  ),
                  child: Column(
                    children: [
                      for (final patient in _patientResults)
                        ListTile(
                          title: Text(patient.fullName),
                          subtitle: patient.phone == null
                              ? null
                              : Text(
                                  patient.phone!,
                                  textDirection: TextDirection.ltr,
                                ),
                          onTap: () {
                            setState(() {
                              _selectedPatient = patient;
                              _patientResults = [];
                              _patientSearchController.text = patient.fullName;
                            });
                            _loadSuggestion(patient.id!);
                          },
                        ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _PickerField(
                    label: 'التاريخ',
                    value: dateFormat.format(_date),
                    icon: Icons.calendar_today_rounded,
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _PickerField(
                    label: 'الوقت',
                    value: _time.format(context),
                    icon: Icons.access_time_rounded,
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'نوع الموعد',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final type in AppointmentType.values)
                  ChoiceChip(
                    avatar: Icon(type.icon, size: 16, color: type.color),
                    label: Text('${type.label} (${_priceLabel(type)})'),
                    selected: _type == type,
                    onSelected: (_) => setState(() => _type = type),
                  ),
                if (_loadingSuggestion)
                  const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            if (_suggestionHint() != null) ...[
              const SizedBox(height: 6),
              Text(
                _suggestionHint()!,
                style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
              ),
            ],
            // Hidden entirely for a single-doctor clinic — there's nothing
            // to disambiguate yet (see Admin > الأطباء).
            if (doctors.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'الطبيب',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('بلا تحديد'),
                    selected: _doctorId == null,
                    onSelected: (_) => setState(() => _doctorId = null),
                  ),
                  for (final doctor in doctors)
                    ChoiceChip(
                      label: Text(doctor.name),
                      selected: _doctorId == doctor.id,
                      onSelected: (_) => setState(() => _doctorId = doctor.id),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (_isEditing) ...[
              const Text(
                'الحالة',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final status in AppointmentStatus.values)
                    ChoiceChip(
                      label: Text(status.label),
                      selected: _status == status,
                      onSelected: (_) => setState(() => _status = status),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 13),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            _saving
                ? const Center(child: CircularProgressIndicator())
                : GradientButton(
                    label: _isEditing ? 'حفظ التعديلات' : 'حجز الموعد',
                    icon: Icons.check_rounded,
                    onPressed: _save,
                  ),
          ],
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.sky,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.aqua),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.inkSoft,
                    ),
                  ),
                  Text(
                    value,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontWeight: FontWeight.w700),
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

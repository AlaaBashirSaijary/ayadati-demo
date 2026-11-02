import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../appointments/presentation/pages/appointment_form_page.dart';
import '../../domain/entities/patient.dart';
import '../../domain/usecases/create_patient.dart';
import '../../domain/usecases/update_patient.dart';
import '../../../../core/widgets/app_snack.dart';

/// One form for both "مريض جديد" and "تعديل إضبارة" — mirrors how the
/// Laravel side already shares patients._form.blade.php between
/// create.blade.php and edit.blade.php. [patient] is null in create mode.
class PatientFormPage extends ConsumerStatefulWidget {
  const PatientFormPage({
    super.key,
    this.patient,
    this.initialName,
    this.initialPhone,
    this.onCreated,
  });

  final Patient? patient;

  /// Pre-fills a brand-new patient — used when the record is being created
  /// from a pasted WhatsApp booking request (see BookingFromMessagePage).
  final String? initialName;
  final String? initialPhone;

  /// Runs right after a new patient is saved, in place of the default "book
  /// an appointment now?" prompt — lets a caller that is already in the
  /// middle of a booking continue it with the patient it just created.
  final Future<void> Function(Patient patient)? onCreated;

  @override
  ConsumerState<PatientFormPage> createState() => _PatientFormPageState();
}

class _PatientFormPageState extends ConsumerState<PatientFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final _patientNumberController = TextEditingController(
    text: widget.patient?.patientNumber ?? '',
  );
  late final _fullNameController = TextEditingController(
    text: widget.patient?.fullName ?? widget.initialName ?? '',
  );
  late final _phoneController = TextEditingController(
    text: widget.patient?.phone ?? widget.initialPhone ?? '',
  );
  late final _addressController = TextEditingController(
    text: widget.patient?.address ?? '',
  );
  late final _ageController = TextEditingController(
    text: widget.patient?.age?.toString() ?? '',
  );
  late final _diagnosisController = TextEditingController(
    text: widget.patient?.diagnosis ?? '',
  );
  late final _previousMedicationsController = TextEditingController(
    text: widget.patient?.previousMedications ?? '',
  );
  late final _currentMedicationsController = TextEditingController(
    text: widget.patient?.currentMedications ?? '',
  );
  late final _allergiesController = TextEditingController(
    text: widget.patient?.allergies ?? '',
  );
  late final _medicalHistoryController = TextEditingController(
    text: widget.patient?.medicalHistory ?? '',
  );
  late final _surgeriesHistoryController = TextEditingController(
    text: widget.patient?.surgeriesHistory ?? '',
  );
  late final _notesController = TextEditingController(
    text: widget.patient?.notes ?? '',
  );

  Gender? _gender;
  DateTime? _birthDate;
  Map<String, String> _fieldErrors = {};
  bool _saving = false;

  /// Collapsed by default when adding a new patient — front-desk staff
  /// asked for a quicker "just the essentials" add flow, with the detailed
  /// medical fields available but not demanding attention up front. Open
  /// by default in edit mode, since that data is presumably already worth
  /// looking at.
  late bool _showMoreFields = _isEdit;

  bool get _isEdit => widget.patient != null;

  @override
  void initState() {
    super.initState();
    _gender = widget.patient?.gender;
    _birthDate = widget.patient?.birthDate;
  }

  @override
  void dispose() {
    for (final c in [
      _patientNumberController,
      _fullNameController,
      _phoneController,
      _addressController,
      _ageController,
      _diagnosisController,
      _previousMedicationsController,
      _currentMedicationsController,
      _allergiesController,
      _medicalHistoryController,
      _surgeriesHistoryController,
      _notesController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(DateTime.now().year - 30),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _fieldErrors = {};
    });

    final patient = Patient(
      id: widget.patient?.id,
      patientNumber: _patientNumberController.text.trim().isEmpty
          ? null
          : _patientNumberController.text.trim(),
      fullName: _fullNameController.text.trim(),
      gender: _gender,
      phone: _emptyToNull(_phoneController.text),
      address: _emptyToNull(_addressController.text),
      birthDate: _birthDate,
      age: int.tryParse(_ageController.text.trim()),
      diagnosis: _emptyToNull(_diagnosisController.text),
      previousMedications: _emptyToNull(_previousMedicationsController.text),
      currentMedications: _emptyToNull(_currentMedicationsController.text),
      allergies: _emptyToNull(_allergiesController.text),
      medicalHistory: _emptyToNull(_medicalHistoryController.text),
      surgeriesHistory: _emptyToNull(_surgeriesHistoryController.text),
      notes: _emptyToNull(_notesController.text),
      isActive: widget.patient?.isActive ?? true,
      createdAt: widget.patient?.createdAt,
    );

    final result = _isEdit
        ? await sl<UpdatePatient>().call(patient)
        : await sl<CreatePatient>().call(patient);

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _saving = false;
          if (failure is ValidationFailure) _fieldErrors = failure.fieldErrors;
        });
        AppSnack.error(context, failure.message);
      },
      (saved) async {
        if (!_isEdit) {
          if (widget.onCreated != null) {
            await widget.onCreated!(saved);
          } else {
            await _offerBooking(saved);
          }
        }
        if (!mounted) return;
        Navigator.of(context).pop(true);
      },
    );
  }

  /// Right after a new patient is saved — not on edits — offers a shortcut
  /// straight into booking their appointment, so front-desk staff don't
  /// have to re-find the patient they just typed in on a second screen.
  Future<void> _offerBooking(Patient patient) async {
    final bookNow = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تم حفظ المريض'),
        content: const Text('هل تريدين حجز موعد له الآن؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('لاحقًا'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حجز موعد'),
          ),
        ],
      ),
    );

    if (bookNow != true || !mounted) return;

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AppointmentFormPage(preselectedPatient: patient),
      ),
    );
  }

  String? _emptyToNull(String value) =>
      value.trim().isEmpty ? null : value.trim();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'تعديل إضبارة' : 'مريض جديد')),
      body: ResponsiveBody(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              StaggeredFadeSlideIn(
                spacing: AppSpacing.md,
                children: [
                  _FormSection(
                    highlighted: true,
                    children: [
                      TextFormField(
                        controller: _patientNumberController,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: 'رقم المريض (للسجلات السابقة)',
                          errorText: _fieldErrors['patient_number'],
                        ),
                      ),
                    ],
                  ),
                  _FormSection(
                    children: [
                      TextFormField(
                        controller: _fullNameController,
                        decoration: InputDecoration(
                          labelText: 'اسم المريض الكامل',
                          errorText: _fieldErrors['full_name'],
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'أدخل اسم المريض.'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _phoneController,
                        textDirection: TextDirection.ltr,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'رقم الهاتف (اختياري)',
                          errorText: _fieldErrors['phone'],
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () =>
                        setState(() => _showMoreFields = !_showMoreFields),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.sky.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.tune_rounded,
                            size: 16,
                            color: AppColors.aqua,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'معلومات إضافية (اختياري)',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          AnimatedRotation(
                            turns: _showMoreFields ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(
                              Icons.expand_more_rounded,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    alignment: Alignment.topCenter,
                    child: !_showMoreFields
                        ? const SizedBox(width: double.infinity)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: AppSpacing.md),
                              _FormSection(
                                children: [
                                  DropdownButtonFormField<Gender?>(
                                    initialValue: _gender,
                                    decoration: const InputDecoration(
                                      labelText: 'الجنس (اختياري)',
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: null,
                                        child: Text('—'),
                                      ),
                                      DropdownMenuItem(
                                        value: Gender.male,
                                        child: Text('ذكر'),
                                      ),
                                      DropdownMenuItem(
                                        value: Gender.female,
                                        child: Text('أنثى'),
                                      ),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _gender = v),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  TextFormField(
                                    controller: _addressController,
                                    decoration: const InputDecoration(
                                      labelText: 'العنوان (اختياري)',
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _ageController,
                                          textDirection: TextDirection.ltr,
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            labelText: 'العمر (اختياري)',
                                            errorText: _fieldErrors['age'],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Expanded(
                                        child: InkWell(
                                          onTap: _pickBirthDate,
                                          child: InputDecorator(
                                            decoration: InputDecoration(
                                              labelText:
                                                  'تاريخ الميلاد (اختياري)',
                                              errorText:
                                                  _fieldErrors['birth_date'],
                                            ),
                                            child: Text(
                                              _birthDate == null
                                                  ? '—'
                                                  : '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}',
                                              textDirection: TextDirection.ltr,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _FormSection(
                                highlighted: true,
                                children: [
                                  TextFormField(
                                    controller: _diagnosisController,
                                    maxLines: 3,
                                    decoration: const InputDecoration(
                                      labelText: 'الشكاية (ماذا يعاني؟)',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _FormSection(
                                children: [
                                  TextFormField(
                                    controller: _previousMedicationsController,
                                    maxLines: 3,
                                    decoration: const InputDecoration(
                                      labelText: 'الأدوية السابقة',
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  TextFormField(
                                    controller: _currentMedicationsController,
                                    maxLines: 3,
                                    decoration: const InputDecoration(
                                      labelText: 'الأدوية الحالية',
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  TextFormField(
                                    controller: _allergiesController,
                                    maxLines: 3,
                                    decoration: const InputDecoration(
                                      labelText: 'الحساسية من الأدوية أو غيرها',
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  TextFormField(
                                    controller: _medicalHistoryController,
                                    maxLines: 3,
                                    decoration: const InputDecoration(
                                      labelText:
                                          'التاريخ المرضي / الأمراض المزمنة',
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  TextFormField(
                                    controller: _surgeriesHistoryController,
                                    maxLines: 3,
                                    decoration: const InputDecoration(
                                      labelText: 'عمليات سابقة (إن وجدت)',
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  TextFormField(
                                    controller: _notesController,
                                    maxLines: 3,
                                    decoration: const InputDecoration(
                                      labelText: 'ملاحظات إضافية',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                  _saving
                      ? const Center(
                          child: SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        )
                      : GradientButton(
                          label: _isEdit ? 'حفظ التعديلات' : 'حفظ الإضبارة',
                          icon: Icons.save_rounded,
                          onPressed: _submit,
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

/// Groups related fields into a card — [highlighted] mirrors the tinted
/// `.surface-soft` boxes app.css uses for the patient-number and diagnosis
/// fields, so the same visual emphasis carries over from the web form.
class _FormSection extends StatelessWidget {
  const _FormSection({required this.children, this.highlighted = false});

  final List<Widget> children;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.sky.withValues(alpha: 0.6)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: highlighted
            ? Border.all(color: AppColors.aqua.withValues(alpha: 0.2))
            : null,
        boxShadow: highlighted ? null : AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

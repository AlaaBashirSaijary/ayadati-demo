import 'package:equatable/equatable.dart';

/// A future-dated booking — distinct from `Visit`, which is the historical
/// exam record filled in *after* the patient is actually seen. This is what
/// lets the doctor plan "من قادم بكرا؟" instead of only looking backward.
enum AppointmentStatus {
  scheduled,
  completed,
  cancelled;

  String get label => switch (this) {
    AppointmentStatus.scheduled => 'مجدول',
    AppointmentStatus.completed => 'تمت الزيارة',
    AppointmentStatus.cancelled => 'ملغى',
  };

  static AppointmentStatus fromValue(String value) =>
      AppointmentStatus.values.firstWhere(
        (s) => s.name == value,
        orElse: () => AppointmentStatus.scheduled,
      );
}

/// Consultations are the full-price, first-look appointment; follow-ups are
/// the free re-checks within the clinic's follow-up window afterward; a
/// half consultation sits between the two — a discounted re-check once the
/// free window has passed but the visit is still soon enough after the
/// original consultation to not count as a fresh one (see
/// AppointmentRepository.getFollowUpDays / getHalfPriceDays). Staff can
/// always override the suggested type when booking.
enum AppointmentType {
  consultation,
  halfConsultation,
  followUp;

  String get label => switch (this) {
    AppointmentType.consultation => 'معاينة',
    AppointmentType.halfConsultation => 'مراجعة بنصف السعر',
    AppointmentType.followUp => 'مراجعة مجانية',
  };

  /// True for both full and half-price consultations — only a free
  /// follow-up owes nothing. No fee amount is tracked, just whether one is
  /// owed; call sites that need to tell full and half payment apart should
  /// switch on the type itself instead of relying on this alone.
  bool get requiresPayment => this != AppointmentType.followUp;

  static AppointmentType fromValue(String value) =>
      AppointmentType.values.firstWhere(
        (t) => t.name == value,
        orElse: () => AppointmentType.consultation,
      );
}

class Appointment extends Equatable {
  const Appointment({
    this.id,
    required this.patientId,
    required this.scheduledAt,
    this.status = AppointmentStatus.scheduled,
    this.type = AppointmentType.consultation,
    this.notes,
    this.doctorId,
    this.createdAt,
    this.patientName,
    this.patientPhone,
    this.doctorName,
  });

  final int? id;
  final int patientId;
  final DateTime scheduledAt;
  final AppointmentStatus status;
  final AppointmentType type;
  final String? notes;

  /// Which doctor this booking is for — null means "unassigned", the only
  /// state a single-doctor clinic ever needs (see Doctor).
  final int? doctorId;

  final DateTime? createdAt;

  /// Populated only by list/lookup queries that join against
  /// `patients`/`doctors` — never sent back to storage (see
  /// AppointmentModel.toMap).
  final String? patientName;
  final String? patientPhone;
  final String? doctorName;

  Appointment copyWith({
    int? id,
    int? patientId,
    DateTime? scheduledAt,
    AppointmentStatus? status,
    AppointmentType? type,
    String? notes,
    int? doctorId,
    bool clearDoctorId = false,
    DateTime? createdAt,
    String? patientName,
    String? patientPhone,
    String? doctorName,
  }) {
    return Appointment(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      status: status ?? this.status,
      type: type ?? this.type,
      notes: notes ?? this.notes,
      doctorId: clearDoctorId ? null : (doctorId ?? this.doctorId),
      createdAt: createdAt ?? this.createdAt,
      patientName: patientName ?? this.patientName,
      patientPhone: patientPhone ?? this.patientPhone,
      doctorName: doctorName ?? this.doctorName,
    );
  }

  @override
  List<Object?> get props => [
    id,
    patientId,
    scheduledAt,
    status,
    type,
    notes,
    doctorId,
    patientName,
    patientPhone,
    doctorName,
  ];
}

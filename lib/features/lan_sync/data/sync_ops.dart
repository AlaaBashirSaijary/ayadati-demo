import 'package:dartz/dartz.dart';

import '../../../core/database/clinic_data_database.dart';
import '../../../core/di/injection.dart';
import '../../../core/error/failures.dart';
import '../../../core/money/currency.dart';
import '../../../core/security/current_actor.dart';
import '../../appointments/domain/entities/appointment.dart';
import '../../appointments/domain/repositories/appointment_repository.dart';
import '../../appointments/data/datasources/appointment_local_datasource.dart';
import '../../debts/data/debts_local_datasource.dart';
import '../../patients/domain/entities/patient.dart';
import '../../patients/domain/repositories/patient_repository.dart';
import '../../patients/domain/usecases/create_patient.dart';
import '../domain/paired_device.dart';

/// Raised for anything the doctor's device refuses or can't do; the message
/// is what the secretary's screen shows, so it's always a plain sentence.
class SyncOpException implements Exception {
  SyncOpException(this.message, {this.code = 'error'});

  final String message;
  final String code;

  @override
  String toString() => message;
}

String _failureText(Failure f) =>
    f is ValidationFailure ? f.fieldErrors.values.join('، ') : f.message;

T _unwrap<T>(Either<Failure, T> result) =>
    result.fold((f) => throw SyncOpException(_failureText(f)), (v) => v);

/// What a secretary/nurse tablet can ask the doctor's device to do. Each
/// operation reuses the app's normal repositories, so validation, patient
/// numbering and the activity log behave exactly as if the doctor had done
/// it by hand — and the log names the tablet that did it.
class SyncOps {
  const SyncOps({required this.clinicName});

  final String Function() clinicName;

  Future<Object?> run(
    String op,
    Map<String, dynamic> args,
    PairedDevice device,
  ) async {
    if (ClinicDataDatabase.instance.activeDbFileName == null) {
      throw SyncOpException(
        'جهاز الطبيب لم يفتح العيادة بعد. سجّل الدخول عليه أولًا.',
        code: 'not_ready',
      );
    }
    // Writes are attributed to the tablet by name in the activity log.
    final previousId = CurrentActor.instance.userId;
    final previousName = CurrentActor.instance.userName;
    CurrentActor.instance.set(userId: null, userName: device.name);
    try {
      return await _dispatch(op, args, device);
    } finally {
      CurrentActor.instance.set(userId: previousId, userName: previousName);
    }
  }

  Future<Object?> _dispatch(
    String op,
    Map<String, dynamic> a,
    PairedDevice device,
  ) async {
    switch (op) {
      case 'session.info':
        return {
          'clinic': clinicName(),
          'device': device.name,
          'permissions': device.permissions.map((p) => p.name).toList(),
        };

      case 'patients.search':
        final page = _unwrap(
          await sl<PatientRepository>().list(
            query: (a['q'] as String?) ?? '',
            status: PatientStatusFilter.all,
            page: 1,
            perPage: 30,
          ),
        );
        return [for (final p in page.items) _patientJson(p)];

      case 'patients.create':
        final patient = _unwrap(
          await sl<CreatePatient>().call(
            Patient(
              fullName: ((a['name'] as String?) ?? '').trim(),
              phone: _blankToNull(a['phone']),
              address: _blankToNull(a['address']),
              age: a['age'] as int?,
              gender: _gender(a['gender']),
            ),
          ),
        );
        return _patientJson(patient);

      case 'patients.update':
        final repo = sl<PatientRepository>();
        final existing = _unwrap(await repo.find(a['id'] as int));
        final updated = _unwrap(
          await repo.update(
            existing.copyWith(
              fullName: a['name'] == null ? null : (a['name'] as String).trim(),
              phone: _blankToNull(a['phone']) ?? existing.phone,
              address: _blankToNull(a['address']) ?? existing.address,
              age: a['age'] as int?,
            ),
          ),
        );
        return _patientJson(updated);

      case 'appointments.list':
        final day = DateTime.parse(a['day'] as String);
        final start = DateTime(day.year, day.month, day.day);
        final list = _unwrap(
          await sl<AppointmentRepository>().listBetween(
            start,
            start.add(const Duration(days: 1)),
          ),
        );
        return [for (final x in list) _appointmentJson(x)];

      case 'appointments.create':
        final at = DateTime.parse(a['at'] as String);
        final repo = sl<AppointmentRepository>();
        final conflict = _unwrap(await repo.findConflict(at));
        if (conflict != null && a['force'] != true) {
          throw SyncOpException(
            'يوجد موعد آخر في نفس الوقت (${conflict.patientName ?? ''}).',
            code: 'conflict',
          );
        }
        final created = _unwrap(
          await repo.create(
            Appointment(
              patientId: a['patientId'] as int,
              scheduledAt: at,
              type: AppointmentType.fromValue(
                (a['type'] as String?) ?? 'consultation',
              ),
              notes: _blankToNull(a['notes']),
            ),
          ),
        );
        return _appointmentJson(created);

      case 'appointments.setStatus':
        final local = sl<AppointmentLocalDataSource>();
        final existing = await local.find(a['id'] as int);
        if (existing == null) {
          throw SyncOpException('الموعد غير موجود.', code: 'not_found');
        }
        final updated = _unwrap(
          await sl<AppointmentRepository>().update(
            existing.copyWith(
              status: AppointmentStatus.fromValue(a['status'] as String),
            ),
          ),
        );
        return _appointmentJson(updated);

      case 'payments.debts':
        final debts = await sl<DebtsLocalDataSource>().list();
        return [
          for (final d in debts)
            {
              'patientId': d.patientId,
              'name': d.name,
              'phone': d.phone,
              'since': d.oldest.toIso8601String(),
              'owed': {for (final c in d.owed.currencies) c.code: d.owed.of(c)},
            },
        ];

      case 'payments.record':
        final applied = await sl<DebtsLocalDataSource>().recordPayment(
          patientId: a['patientId'] as int,
          currency: Currency.fromCode(a['currency'] as String?),
          amount: (a['amount'] as num).toDouble(),
          note: _blankToNull(a['note']),
        );
        return {'applied': applied};
    }
    throw SyncOpException('عملية غير معروفة.', code: 'unknown_op');
  }

  static String? _blankToNull(Object? v) {
    final s = (v as String?)?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static Gender? _gender(Object? v) => switch (v) {
    'male' => Gender.male,
    'female' => Gender.female,
    _ => null,
  };

  /// Only what reception needs — never the medical record.
  static Map<String, Object?> _patientJson(Patient p) => {
    'id': p.id,
    'number': p.patientNumber,
    'name': p.fullName,
    'phone': p.phone,
    'address': p.address,
    'age': p.displayAge,
    'gender': p.gender?.name,
    'active': p.isActive,
  };

  static Map<String, Object?> _appointmentJson(Appointment x) => {
    'id': x.id,
    'patientId': x.patientId,
    'name': x.patientName,
    'phone': x.patientPhone,
    'at': x.scheduledAt.toIso8601String(),
    'status': x.status.name,
    'type': x.type.name,
    'notes': x.notes,
  };
}

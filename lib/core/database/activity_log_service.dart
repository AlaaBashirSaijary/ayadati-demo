import '../security/current_actor.dart';
import 'clinic_data_database.dart';

/// One thing a staff member did to this clinic's data — who, what, and
/// (when relevant) which record, e.g. a patient's name or an appointment's
/// time. Read-only trail; nothing here is ever edited, only appended to.
enum ActivityAction {
  patientCreated,
  patientUpdated,
  patientActivated,
  patientDeactivated,
  visitCreated,
  visitUpdated,
  visitDeleted,
  appointmentCreated,
  appointmentUpdated,
  appointmentDeleted,
  userCreated,
  userDeleted,
  userPasswordReset,
  backupCreated,
  backupRestored;

  String get label => switch (this) {
    ActivityAction.patientCreated => 'أضاف مريضًا جديدًا',
    ActivityAction.patientUpdated => 'عدّل بيانات مريض',
    ActivityAction.patientActivated => 'فعّل حساب مريض',
    ActivityAction.patientDeactivated => 'ألغى تفعيل مريض',
    ActivityAction.visitCreated => 'أضاف زيارة فحص',
    ActivityAction.visitUpdated => 'عدّل زيارة فحص',
    ActivityAction.visitDeleted => 'حذف زيارة فحص',
    ActivityAction.appointmentCreated => 'حجز موعدًا',
    ActivityAction.appointmentUpdated => 'عدّل موعدًا',
    ActivityAction.appointmentDeleted => 'حذف موعدًا',
    ActivityAction.userCreated => 'أضاف مستخدمًا جديدًا',
    ActivityAction.userDeleted => 'حذف مستخدمًا',
    ActivityAction.userPasswordReset => 'غيّر كلمة مرور مستخدم',
    ActivityAction.backupCreated => 'أنشأ نسخة احتياطية',
    ActivityAction.backupRestored => 'استعاد نسخة احتياطية',
  };

  static ActivityAction fromValue(String value) =>
      ActivityAction.values.firstWhere(
        (a) => a.name == value,
        orElse: () => ActivityAction.patientUpdated,
      );
}

class ActivityLogEntry {
  const ActivityLogEntry({
    required this.actorName,
    required this.action,
    required this.createdAt,
    this.entityLabel,
  });

  factory ActivityLogEntry.fromMap(Map<String, Object?> map) =>
      ActivityLogEntry(
        actorName: map['actor_name']! as String,
        action: ActivityAction.fromValue(map['action']! as String),
        entityLabel: map['entity_label'] as String?,
        createdAt: DateTime.parse(map['created_at']! as String),
      );

  final String actorName;
  final ActivityAction action;
  final String? entityLabel;
  final DateTime createdAt;
}

/// Appends to and reads the active clinic's `activity_log` table. A plain
/// singleton service (like ClinicBackupService), not a repository — it's
/// called from inside other features' repositories as a side effect of
/// their own writes, not through its own use-case layer.
class ActivityLogService {
  ActivityLogService._();

  static final ActivityLogService instance = ActivityLogService._();

  /// How many entries to keep before pruning the oldest — an audit trail
  /// that grows forever would eventually slow down the one screen that
  /// reads it, for value nobody looks at past the last few months.
  static const int retentionCount = 2000;

  /// Silently does nothing if the log fails to write — an audit trail is
  /// a courtesy on top of the real action, not something that should ever
  /// block or fail the action it's describing.
  Future<void> log(ActivityAction action, {String? entityLabel}) async {
    try {
      final db = await ClinicDataDatabase.instance.database;
      await db.insert('activity_log', {
        'actor_user_id': CurrentActor.instance.userId,
        'actor_name': CurrentActor.instance.userName ?? 'غير معروف',
        'action': action.name,
        'entity_label': entityLabel,
        'created_at': DateTime.now().toIso8601String(),
      });
      await db.execute('''
        DELETE FROM activity_log WHERE id NOT IN (
          SELECT id FROM activity_log ORDER BY created_at DESC LIMIT $retentionCount
        )
      ''');
    } catch (_) {
      // See doc comment — logging failures are swallowed on purpose.
    }
  }

  Future<List<ActivityLogEntry>> recent({int limit = 200}) async {
    final db = await ClinicDataDatabase.instance.database;
    final rows = await db.query(
      'activity_log',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(ActivityLogEntry.fromMap).toList();
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/database/activity_log_service.dart';
import '../../../../core/theme/app_theme.dart';

/// Read-only trail of who did what and when across this clinic — every
/// entry is written by ActivityLogService as a side effect of the action
/// it describes, so this page only ever reads, never writes.
class ActivityLogPage extends StatefulWidget {
  const ActivityLogPage({super.key});

  @override
  State<ActivityLogPage> createState() => _ActivityLogPageState();
}

class _ActivityLogPageState extends State<ActivityLogPage> {
  List<ActivityLogEntry> _entries = [];
  bool _loading = true;

  static final _dateFormat = DateFormat('yyyy/MM/dd - h:mm a', 'ar');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await ActivityLogService.instance.recent();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  IconData _iconFor(ActivityAction action) {
    switch (action) {
      case ActivityAction.patientCreated:
      case ActivityAction.patientUpdated:
      case ActivityAction.patientActivated:
      case ActivityAction.patientDeactivated:
        return Icons.person_rounded;
      case ActivityAction.visitCreated:
      case ActivityAction.visitUpdated:
      case ActivityAction.visitDeleted:
        return Icons.medical_information_rounded;
      case ActivityAction.appointmentCreated:
      case ActivityAction.appointmentUpdated:
      case ActivityAction.appointmentDeleted:
        return Icons.event_rounded;
      case ActivityAction.userCreated:
      case ActivityAction.userDeleted:
      case ActivityAction.userPasswordReset:
        return Icons.group_rounded;
      case ActivityAction.backupCreated:
      case ActivityAction.backupRestored:
        return Icons.backup_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سجل النشاط')),
      body: ResponsiveBody(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _entries.isEmpty
            ? const Center(
                child: Text(
                  'لا يوجد نشاط مسجّل بعد.',
                  style: TextStyle(color: AppColors.inkSoft),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: _entries.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  return Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppShadows.card,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.aqua.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _iconFor(entry.action),
                            color: AppColors.aqua,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: entry.actorName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    TextSpan(
                                      text: ' ${entry.action.label}',
                                      style: const TextStyle(fontSize: 13.5),
                                    ),
                                  ],
                                ),
                              ),
                              if (entry.entityLabel != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  entry.entityLabel!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          _dateFormat.format(entry.createdAt),
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

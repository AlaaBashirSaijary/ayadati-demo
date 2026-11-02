import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/database/backup_reminder_service.dart';
import '../../../../core/database/clinic_backup_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/update/update_check_service.dart';
import '../../../../core/update/update_provider.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/pressable_scale.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../clinics/presentation/providers/active_clinic_provider.dart';
import '../../../clinics/presentation/widgets/clinic_switcher.dart';
import '../../../help/presentation/pages/help_guide_page.dart';
import '../../../visits/presentation/pages/follow_ups_due_page.dart';
import '../../../visits/presentation/providers/follow_ups_provider.dart';
import '../../domain/entities/patient.dart';
import 'patient_detail_page.dart';
import 'patient_form_page.dart';
import '../providers/dashboard_stats_provider.dart';
import '../providers/patients_provider.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/error/error_messages.dart';

/// Mirrors resources/views/home.blade.php: search + status filter + list,
/// scoped to the signed-in user's clinic — plus a real dashboard header
/// (stat cards, distinctive branding) instead of a plain AppBar title, and
/// a paginated table instead of an ever-growing scroll list once there are
/// more than a page's worth of patients.
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  BackupReminder? _backupReminder;

  @override
  void initState() {
    super.initState();
    _checkBackupReminder();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkBackupReminder() async {
    final reminder = await BackupReminderService.instance.checkIfDue();
    if (!mounted) return;
    setState(() => _backupReminder = reminder);
  }

  Future<void> _backupNow() async {
    setState(() => _backupReminder = null);
    try {
      await ClinicBackupService.instance.createBackup();
      if (!mounted) return;
      AppSnack.success(context, 'تم إنشاء نسخة احتياطية.');
    } catch (e) {
      if (!mounted) return;
      AppSnack.error(context, friendlyMessage('تعذّر إنشاء نسخة احتياطية', e));
    }
  }

  Future<void> _snoozeBackupReminder() async {
    setState(() => _backupReminder = null);
    await BackupReminderService.instance.snooze();
  }

  /// Live search as you type, same as the web app — debounced so a fast
  /// typist doesn't fire a database query per keystroke.
  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => ref.read(patientsListProvider.notifier).search(query),
    );
  }

  Future<void> _addPatient() async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const PatientFormPage()));
    if (saved == true) {
      ref.read(patientsListProvider.notifier).refresh();
      ref.read(dashboardStatsProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Each clinic has its own backup history, so re-check whenever the
    // active clinic changes instead of showing a stale (or wrongly absent)
    // reminder for whichever clinic was active on the previous check.
    ref.listen(activeClinicProvider, (previous, next) {
      if (next.active != null && previous?.active?.id != next.active?.id) {
        _checkBackupReminder();
      }
    });

    final list = ref.watch(patientsListProvider);
    final notifier = ref.read(patientsListProvider.notifier);
    final stats = ref.watch(dashboardStatsProvider);
    final userName = ref.watch(authProvider).user?.name;
    final followUps = ref.watch(followUpsProvider);
    final updateInfo = ref.watch(updateAvailableProvider);

    return Scaffold(
      body: Column(
        children: [
          _DashboardHeader(
            userName: userName,
            stats: stats,
            followUpsDue: followUps.items.length,
            onAddPatient: _addPatient,
          ),
          Expanded(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.9, -1),
                  radius: 1.4,
                  colors: [Color(0x2E1287A0), Colors.transparent],
                ),
              ),
              child: RefreshIndicator(
                onRefresh: () => Future.wait([
                  notifier.refresh(),
                  ref.read(dashboardStatsProvider.notifier).refresh(),
                ]),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  children: [
                    if (updateInfo != null) ...[
                      FadeSlideIn(
                        child: _UpdateAvailableBanner(
                          info: updateInfo,
                          onDismiss: () => ref
                              .read(updateAvailableProvider.notifier)
                              .dismiss(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    if (_backupReminder != null) ...[
                      FadeSlideIn(
                        child: _BackupReminderBanner(
                          reminder: _backupReminder!,
                          onBackupNow: _backupNow,
                          onSnooze: _snoozeBackupReminder,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    if (!followUps.isLoading && followUps.items.isNotEmpty) ...[
                      FadeSlideIn(
                        child: _FollowUpsReminderBanner(
                          count: followUps.items.length,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const FollowUpsDuePage(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    FadeSlideIn(
                      child: _SearchCard(
                        controller: _searchController,
                        status: list.status,
                        searched: list.searched,
                        onSearchChanged: _onSearchChanged,
                        onStatus: notifier.setStatus,
                        onClear: () {
                          _searchDebounce?.cancel();
                          _searchController.clear();
                          notifier.clearFilters();
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (list.isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                        ),
                      )
                    else if (list.items.isEmpty)
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 80),
                        child: _EmptyState(searched: list.searched),
                      )
                    else
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 60),
                        child: _PatientsTable(
                          patients: list.items,
                          onToggleStatus: (id) async {
                            await notifier.toggleStatus(id);
                            ref.read(dashboardStatsProvider.notifier).refresh();
                          },
                          onOpen: (id) async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    PatientDetailPage(patientId: id),
                              ),
                            );
                            notifier.refresh();
                            ref.read(dashboardStatsProvider.notifier).refresh();
                          },
                        ),
                      ),
                    if (!list.isLoading && list.items.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      _PaginationBar(
                        page: list.page,
                        lastPage: list.lastPage,
                        total: list.total,
                        onPrevious: list.page > 1
                            ? () => notifier.goToPage(list.page - 1)
                            : null,
                        onNext: list.page < list.lastPage
                            ? () => notifier.goToPage(list.page + 1)
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A real header instead of a plain AppBar title: brand mark, a greeting
/// with the active clinic named right underneath it (so it reads as "whose
/// data this is" instead of an unlabeled switcher floating on its own),
/// sign-out, and the stat cards row — "إضافة مريض جديد" sits immediately
/// beside the patients-total tile rather than floating separately.
class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.userName,
    required this.stats,
    required this.followUpsDue,
    required this.onAddPatient,
  });

  final String? userName;
  final DashboardStats stats;
  final int followUpsDue;
  final VoidCallback onAddPatient;

  /// "صباح الخير"/"مساء الخير"، اعتمادًا على وقت اليوم الحالي.
  String get _timeGreeting {
    final hour = DateTime.now().hour;
    return hour < 12 ? 'صباح الخير' : 'مساء الخير';
  }

  /// جملة سردية بدل الأرقام الجافة: عدد مواعيد اليوم، المتابعات المستحقة،
  /// والمرضى الجدد هالأسبوع — تُبنى بشكل تراكمي حسب المتوفر منها فقط.
  String get _summarySentence {
    final parts = <String>[];
    if (stats.appointmentsToday > 0) {
      parts.add('لديك ${stats.appointmentsToday} موعد اليوم');
    }
    if (followUpsDue > 0) {
      parts.add('$followUpsDue متابعة مستحقة');
    }
    if (stats.newPatientsThisWeek > 0) {
      parts.add('${stats.newPatientsThisWeek} مريض جديد هالأسبوع');
    }
    if (parts.isEmpty) {
      return 'لا مواعيد ولا متابعات مستحقة اليوم — يوم هادئ!';
    }
    return '${parts.join('، ')}.';
  }

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
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const BrandMark(size: 34),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName == null || userName!.isEmpty
                              ? _timeGreeting
                              : '$_timeGreeting د. $userName',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        // The clinic switcher, placed right under the name
                        // so it reads as "this is whose data you're seeing
                        // and where to switch it" instead of an unlabeled
                        // control floating on its own elsewhere.
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: ClinicSwitcher(compact: true, onDark: true),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'دليل الاستخدام',
                    icon: const Icon(
                      Icons.help_outline_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HelpGuidePage()),
                    ),
                  ),
                  Consumer(
                    builder: (context, ref, _) => IconButton(
                      tooltip: 'خروج',
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () =>
                          ref.read(authProvider.notifier).signOut(),
                    ),
                  ),
                ],
              ),
              if (!stats.isLoading) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _summarySentence,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      icon: Icons.groups_rounded,
                      value: '${stats.patients.total}',
                      label: 'إجمالي المرضى',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: _AddPatientTile(onTap: onAddPatient)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.favorite_rounded,
                      value: '${stats.patients.active}',
                      label: 'نشط',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.event_available_rounded,
                      value: '${stats.seenToday}',
                      label: 'شوهدوا اليوم',
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

class _StatTile extends StatelessWidget {
  const _StatTile({
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
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

/// Right beside the patients-total tile, per the redesign ask.
class _AddPatientTile extends StatelessWidget {
  const _AddPatientTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          children: [
            Icon(Icons.add_circle_rounded, color: AppColors.focus, size: 18),
            SizedBox(height: 6),
            Text(
              'إضافة',
              style: TextStyle(
                color: AppColors.focus,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'مريض جديد',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.inkSoft,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({
    required this.controller,
    required this.status,
    required this.searched,
    required this.onSearchChanged,
    required this.onStatus,
    required this.onClear,
  });

  final TextEditingController controller;
  final PatientStatusFilter status;
  final bool searched;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<PatientStatusFilter> onStatus;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'سجلات المرضى',
            style: TextStyle(
              color: AppColors.aqua,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'بحث بالاسم أو رقم الهاتف أو رقم الملف',
              suffixIcon: const Icon(Icons.search_rounded),
            ),
            onChanged: onSearchChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final s in PatientStatusFilter.values)
                ChoiceChip(
                  label: Text(s.label),
                  selected: status == s,
                  onSelected: (_) => onStatus(s),
                ),
              if (searched)
                TextButton(
                  onPressed: onClear,
                  child: const Text('مسح الفلاتر'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A newer .apk exists on GitHub — see UpdateCheckService for how this is
/// found (a single best-effort request, throttled to once a day) and why
/// it's a plain download link rather than any kind of silent auto-install.
class _UpdateAvailableBanner extends StatelessWidget {
  const _UpdateAvailableBanner({required this.info, required this.onDismiss});

  final UpdateInfo info;
  final VoidCallback onDismiss;

  Future<void> _download(BuildContext context) async {
    final uri = Uri.tryParse(info.downloadUrl);
    final opened =
        uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      AppSnack.error(context, 'تعذّر فتح رابط التحديث.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.ok.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.ok.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.system_update_alt_rounded,
            color: AppColors.ok,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'يتوفر إصدار جديد (${info.version}) من عيادتي.',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    TextButton(
                      onPressed: onDismiss,
                      child: const Text('لاحقًا'),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    FilledButton(
                      onPressed: () => _download(context),
                      child: const Text('تنزيل التحديث'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Nudges toward a manual backup once it's been a while — backups here are
/// entirely manual (see ClinicBackupService), so nothing else would ever
/// notice a stale or missing one on its own.
class _BackupReminderBanner extends StatelessWidget {
  const _BackupReminderBanner({
    required this.reminder,
    required this.onBackupNow,
    required this.onSnooze,
  });

  final BackupReminder reminder;
  final VoidCallback onBackupNow;
  final VoidCallback onSnooze;

  @override
  Widget build(BuildContext context) {
    final message = !reminder.hasAnyBackup
        ? 'لم يتم إنشاء أي نسخة احتياطية بعد لهذه العيادة.'
        : 'آخر نسخة احتياطية كانت منذ '
              '${DateTime.now().difference(reminder.lastBackup!).inDays} يوم.';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.sky.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.aqua.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.backup_outlined, color: AppColors.aqua, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    TextButton(
                      onPressed: onSnooze,
                      child: const Text('تذكير لاحقًا'),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    FilledButton(
                      onPressed: onBackupNow,
                      child: const Text('نسخ احتياطي الآن'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable nudge toward the "متابعات مستحقة" list — only shown when it's
/// actually non-empty, same "don't clutter the dashboard when there's
/// nothing to act on" rule the backup reminder above follows.
class _FollowUpsReminderBanner extends StatelessWidget {
  const _FollowUpsReminderBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.focus.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.focus.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.event_repeat_rounded,
                color: AppColors.focus,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '$count ${count == 1 ? 'مريض بحاجة' : 'مرضى بحاجة'} متابعة.',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.focusDeep,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_left_rounded,
                color: AppColors.focus,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.searched});

  final bool searched;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            searched ? Icons.search_off_rounded : Icons.folder_open_rounded,
            size: 40,
            color: AppColors.lens,
          ),
          const SizedBox(height: 12),
          Text(
            searched ? 'لا توجد نتائج مطابقة.' : 'لا توجد سجلات بعد.',
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            searched ? 'جرّبي كلمة بحث أخرى.' : 'أضيفي أول مريض من الأعلى.',
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Up to 20 rows at a time (see PatientsListState.perPage) — a card-list of
/// evenly proportioned columns (via Expanded/flex, not DataTable's
/// content-fitted auto-widths, which read as cramped and uneven) instead of
/// an ever-growing scroll list, so 100+ patients stays usable.
class _PatientsTable extends StatelessWidget {
  const _PatientsTable({
    required this.patients,
    required this.onToggleStatus,
    required this.onOpen,
  });

  final List<Patient> patients;
  final void Function(int id) onToggleStatus;
  final void Function(int id) onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const _PatientsTableHeader(),
          for (final (index, patient) in patients.indexed) ...[
            if (index > 0) const Divider(height: 1, indent: AppSpacing.lg),
            _PatientRow(
              patient: patient,
              onToggleStatus: () => onToggleStatus(patient.id!),
              onOpen: () => onOpen(patient.id!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Column widths every row below must match exactly, so headers line up
/// with the cells under them instead of drifting the way DataTable's
/// per-column auto-sizing could.
class _PatientColumns {
  const _PatientColumns._();

  static const name = 3;
  static const number = 2;
  static const phone = 2;
  static const status = 2;
  static const action = 44.0; // fixed, not flex — one icon's worth of width
}

class _PatientsTableHeader extends StatelessWidget {
  const _PatientsTableHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 11.5,
      color: AppColors.aqua,
      letterSpacing: 0.2,
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      color: AppColors.sky.withValues(alpha: 0.5),
      child: const Row(
        children: [
          Expanded(
            flex: _PatientColumns.name,
            child: Text('الاسم', style: style),
          ),
          Expanded(
            flex: _PatientColumns.number,
            child: Text('رقم الملف', style: style),
          ),
          Expanded(
            flex: _PatientColumns.phone,
            child: Text('الهاتف', style: style),
          ),
          Expanded(
            flex: _PatientColumns.status,
            child: Text('الحالة', style: style, textAlign: TextAlign.center),
          ),
          SizedBox(width: _PatientColumns.action),
        ],
      ),
    );
  }
}

class _PatientRow extends StatelessWidget {
  const _PatientRow({
    required this.patient,
    required this.onToggleStatus,
    required this.onOpen,
  });

  final Patient patient;
  final VoidCallback onToggleStatus;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                flex: _PatientColumns.name,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.aqua.withValues(alpha: 0.12),
                      child: Text(
                        patient.fullName.isNotEmpty ? patient.fullName[0] : '؟',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.aquaDeep,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        patient.fullName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: _PatientColumns.number,
                child: Text(
                  patient.patientNumber ?? '—',
                  style: const TextStyle(
                    color: AppColors.aqua,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                  textDirection: TextDirection.ltr,
                ),
              ),
              Expanded(
                flex: _PatientColumns.phone,
                child: Text(
                  patient.phone ?? '—',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 12.5,
                  ),
                  textDirection: TextDirection.ltr,
                ),
              ),
              Expanded(
                flex: _PatientColumns.status,
                child: Center(
                  child: GestureDetector(
                    onTap: onToggleStatus,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: patient.isActive
                            ? AppColors.ok.withValues(alpha: 0.1)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        patient.statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: patient.isActive
                              ? AppColors.ok
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: _PatientColumns.action,
                child: const Icon(
                  Icons.chevron_left_rounded,
                  color: AppColors.lens,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// السابق/التالي, each with its arrow pointing *inward* toward the middle
/// of the bar — the conventional RTL pagination pattern ("« السابق" /
/// "التالي »"), built by hand instead of via TextButton.icon so the icon's
/// position relative to its label is never left to an implicit default.
class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.lastPage,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int lastPage;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          _PagerButton(
            label: 'السابق',
            icon: Icons.chevron_left_rounded,
            iconFirst: false,
            onTap: onPrevious,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.sky.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'صفحة $page من $lastPage — $total مريض',
              style: const TextStyle(
                color: AppColors.inkSoft,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          _PagerButton(
            label: 'التالي',
            icon: Icons.chevron_right_rounded,
            iconFirst: true,
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

class _PagerButton extends StatelessWidget {
  const _PagerButton({
    required this.label,
    required this.icon,
    required this.iconFirst,
    required this.onTap,
  });

  final String label;
  final IconData icon;

  /// True to place the icon before the label in reading order (used by the
  /// "next" button, whose icon points further into the bar from the left);
  /// false places it after (the "previous" button, whose icon points into
  /// the bar from the right) — explicit either way, not left to a default.
  final bool iconFirst;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = enabled ? AppColors.aqua : AppColors.lens;
    final iconWidget = Icon(icon, size: 18, color: color);
    final labelWidget = Text(
      label,
      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: iconFirst
                ? [iconWidget, const SizedBox(width: 4), labelWidget]
                : [labelWidget, const SizedBox(width: 4), iconWidget],
          ),
        ),
      ),
    );
  }
}

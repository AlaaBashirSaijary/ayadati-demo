import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/admin/presentation/pages/admin_home_page.dart';
import '../../features/appointments/presentation/pages/appointments_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/clinics/presentation/providers/active_clinic_provider.dart';
import '../../features/clinics/presentation/widgets/clinic_switcher.dart';
import '../../features/patients/presentation/pages/dashboard_page.dart';
import '../theme/app_theme.dart';
import '../update/update_provider.dart';
import 'brand_mark.dart';

/// The app's top-level structure: patient management and system
/// administration are separate destinations with their own navigation
/// entry, not one screen with an admin card stacked into the patient list.
/// Adapts between a sidebar (iPad / wide screens — the primary target
/// device for this app) and a bottom tab bar (narrower screens).
///
/// Also the gate for the active-clinic switch: nothing below this widget
/// touches patient/visit data until ActiveClinicNotifier has actually
/// opened a clinic's database file (see ClinicDataDatabase) — nothing to
/// query yet otherwise.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _ShellDestination {
  const _ShellDestination({
    required this.icon,
    required this.label,
    required this.color,
    required this.page,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Widget page;
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Fire-and-forget, once per real session (not per clinic switch) — the
    // check itself throttles to once a day and fails silently, so this
    // never delays or blocks getting into the app.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(updateAvailableProvider.notifier).check(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clinicState = ref.watch(activeClinicProvider);

    if (clinicState.error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              clinicState.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ),
      );
    }

    if (!clinicState.isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isAdmin = ref.watch(authProvider).user?.isAdmin ?? false;

    final destinations = [
      const _ShellDestination(
        icon: Icons.people_alt_rounded,
        label: 'المرضى',
        color: AppColors.aqua,
        page: DashboardPage(),
      ),
      const _ShellDestination(
        icon: Icons.event_available_rounded,
        label: 'المواعيد',
        color: AppColors.ok,
        page: AppointmentsPage(),
      ),
      if (isAdmin)
        const _ShellDestination(
          icon: Icons.admin_panel_settings_rounded,
          label: 'الإدارة',
          color: AppColors.focus,
          page: AdminHomePage(),
        ),
    ];

    final index = _index < destinations.length ? _index : 0;
    final isWide = MediaQuery.sizeOf(context).width >= 700;

    final stack = IndexedStack(
      index: index,
      children: [for (final d in destinations) d.page],
    );

    if (!isWide) {
      // Phone-width fallback: bottom tabs instead of a sidebar. No separate
      // clinic-switcher bar here — the dashboard's own header shows it
      // right under the user's name, and the admin page's "العيادات"
      // section covers it too, so a third, unlabeled spot for it isn't
      // needed (that unlabeled spot was the actual complaint).
      return Scaffold(
        body: stack,
        bottomNavigationBar: destinations.length < 2
            ? null
            : DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: AppShadows.card,
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (final (i, d) in destinations.indexed)
                          _NavBadge(
                            destination: d,
                            selected: i == index,
                            onTap: () => setState(() => _index = i),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
      );
    }

    // iPad / wide layout: a persistent sidebar, matching the platform's own
    // master-detail navigation convention instead of a single scrolling page.
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 108,
            color: AppColors.sky.withValues(alpha: 0.5),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  const BrandMark(size: 34),
                  const SizedBox(height: AppSpacing.sm),
                  const ClinicSwitcher(),
                  const SizedBox(height: AppSpacing.xl),
                  for (final (i, d) in destinations.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _NavBadge(
                        destination: d,
                        selected: i == index,
                        onTap: () => setState(() => _index = i),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1, color: Color(0x14000000)),
          Expanded(child: stack),
        ],
      ),
    );
  }
}

/// A distinct, tappable "widget" per destination — a colored icon badge
/// that fills in when selected — instead of a plain flat icon+label pair.
class _NavBadge extends StatelessWidget {
  const _NavBadge({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? destination.color
                    : destination.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: destination.color.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                destination.icon,
                color: selected ? Colors.white : destination.color,
                size: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              destination.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? destination.color : AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/clinic.dart';
import '../providers/active_clinic_provider.dart';

/// The clinic name in the sidebar/tab bar, tappable to switch between
/// registered clinics or add a new one — each backed by its own separate
/// database file (see ClinicDataDatabase).
class ClinicSwitcher extends ConsumerWidget {
  const ClinicSwitcher({super.key, this.compact = false, this.onDark = false});

  /// Compact rendering for narrow layouts (bottom-tab phone width) — just
  /// the name, no card chrome, since it sits inside an AppBar there.
  final bool compact;

  /// True when placed over a dark/gradient background (the dashboard
  /// header) instead of a light card — swaps to white/translucent text so
  /// it stays legible instead of using the dark ink colors meant for white.
  final bool onDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activeClinicProvider);
    final active = state.active;
    if (active == null) return const SizedBox.shrink();

    final textColor = onDark ? Colors.white : AppColors.ink;
    final iconColor = onDark ? Colors.white70 : AppColors.inkSoft;

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onDark) ...[
          Icon(Icons.local_hospital_rounded, size: 13, color: iconColor),
          const SizedBox(width: 4),
          // Spelled out, not just an icon — this line sits directly under
          // the doctor's own name in the greeting, and when the clinic
          // happens to be named after the doctor the two lines can
          // otherwise read as an accidental repeat instead of two
          // different pieces of information.
          Text('العيادة:', style: TextStyle(fontSize: 11, color: iconColor)),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            active.name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: compact ? 12 : 12,
              color: textColor,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.unfold_more_rounded, size: 14, color: iconColor),
      ],
    );

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _openPicker(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: child,
      ),
    );
  }

  Future<void> _openPicker(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => const _ClinicPickerSheet(),
    );
  }
}

class _ClinicPickerSheet extends ConsumerStatefulWidget {
  const _ClinicPickerSheet();

  @override
  ConsumerState<_ClinicPickerSheet> createState() => _ClinicPickerSheetState();
}

class _ClinicPickerSheetState extends ConsumerState<_ClinicPickerSheet> {
  bool _addingNew = false;
  final _nameController = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submitNewClinic() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'أدخلي اسم العيادة.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final ok = await ref
        .read(activeClinicProvider.notifier)
        .createAndSwitch(_nameController.text.trim());

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = ref.read(activeClinicProvider).error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeClinicProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'العيادات',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final clinic in state.clinics)
              _ClinicTile(
                clinic: clinic,
                selected: clinic.id == state.active?.id,
                onTap: () async {
                  await ref
                      .read(activeClinicProvider.notifier)
                      .switchTo(clinic);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            const SizedBox(height: AppSpacing.sm),
            if (_addingNew) ...[
              TextField(
                controller: _nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'اسم العيادة الجديدة',
                  errorText: _error,
                ),
                onSubmitted: (_) => _submitNewClinic(),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() => _addingNew = false),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _submitNewClinic,
                      child: _saving
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('إنشاء'),
                    ),
                  ),
                ],
              ),
            ] else
              OutlinedButton.icon(
                onPressed: () => setState(() => _addingNew = true),
                icon: const Icon(Icons.add_rounded),
                label: const Text('إضافة عيادة جديدة'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ClinicTile extends StatelessWidget {
  const _ClinicTile({
    required this.clinic,
    required this.selected,
    required this.onTap,
  });

  final Clinic clinic;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.sky.withValues(alpha: 0.6)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.aqua : AppColors.inkSoft,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  clinic.name,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

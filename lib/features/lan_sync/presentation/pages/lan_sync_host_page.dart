import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../data/device_registry.dart';
import '../../data/lan_sync_server.dart';
import '../../data/lan_sync_service.dart';
import '../../domain/paired_device.dart';
import '../../domain/sync_permissions.dart';

/// Doctor's side: turn sharing on, read the pairing code to the secretary or
/// nurse, and decide what each paired tablet may do.
class LanSyncHostPage extends StatefulWidget {
  const LanSyncHostPage({super.key});

  @override
  State<LanSyncHostPage> createState() => _LanSyncHostPageState();
}

class _LanSyncHostPageState extends State<LanSyncHostPage> {
  final _service = LanSyncService.instance;
  List<PairedDevice> _devices = [];
  List<String> _addresses = [];
  PairingSession? _session;
  DevicePreset _preset = DevicePreset.secretary;
  bool _busy = false;
  static final _time = DateFormat('yyyy/MM/dd h:mm a', 'ar');

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final devices = await DeviceRegistry.instance.all();
    final addresses = await _service.localAddresses();
    if (!mounted) return;
    setState(() {
      _devices = devices;
      _addresses = addresses;
      _session = _service.server.pairing;
    });
  }

  Future<void> _toggle(bool on) async {
    setState(() => _busy = true);
    try {
      if (on) {
        await _service.start();
      } else {
        await _service.stop();
      }
    } catch (e) {
      if (mounted) {
        AppSnack.error(context, 'تعذّر تشغيل المزامنة على هذا الجهاز.');
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _refresh();
  }

  void _newCode() {
    setState(() => _session = _service.server.openPairing(_preset));
  }

  Future<void> _revoke(PairedDevice d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('فك ارتباط "${d.name}"؟'),
        content: const Text(
          'لن يستطيع هذا الجهاز الوصول لبيانات العيادة حتى يُربط من جديد.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text(
              'فك الارتباط',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await DeviceRegistry.instance.remove(d.id);
    _refresh();
  }

  Future<void> _setPermission(PairedDevice d, SyncPermission p, bool on) async {
    final next = {...d.permissions};
    if (on) {
      next.add(p);
    } else {
      next.remove(p);
    }
    await DeviceRegistry.instance.setPermissions(d.id, next);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final running = _service.isRunning;
    final server = _service.server;
    return Scaffold(
      appBar: AppBar(title: const Text('ربط جهاز السكرتيرة / الممرضة')),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const Text(
              'يعمل بالواي فاي المحلي بدون إنترنت. جهازك هو المرجع: السكرتيرة '
              'تسجّل المرضى والمواعيد والدفعات على جهازها فتصلك فورًا، وأنت '
              'تحدد ما يحق لها فعله. الاتصال مشفّر، وتبقى كل البيانات عندك.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.inkSoft,
                height: 1.6,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SurfaceCard(
              title: 'المشاركة',
              icon: Icons.wifi_tethering_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: running,
                    onChanged: _busy ? null : _toggle,
                    title: Text(running ? 'تعمل الآن' : 'متوقفة'),
                    subtitle: const Text(
                      'يبقى التطبيق مفتوحًا وشاشة الجهاز مضاءة أثناء المشاركة.',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                  if (running && _addresses.isNotEmpty)
                    Text(
                      'عنوان هذا الجهاز: ${_addresses.map((a) => '$a:${server.port}').join('  |  ')}',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkSoft,
                      ),
                    ),
                ],
              ),
            ),
            if (running) ...[
              const SizedBox(height: AppSpacing.md),
              SurfaceCard(
                title: 'ربط جهاز جديد',
                icon: Icons.add_link_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final p in DevicePreset.values)
                          ChoiceChip(
                            label: Text(p.label),
                            selected: _preset == p,
                            onSelected: (_) => setState(() => _preset = p),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'الصلاحيات تبدأ بحسب الاختيار ويمكنك تعديلها بعد الربط.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_session != null && _session!.isOpen) ...[
                      Center(
                        child: Text(
                          _session!.code,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 6,
                          ),
                        ),
                      ),
                      const Center(
                        child: Text(
                          'اكتب هذا الرمز على الجهاز الآخر خلال 5 دقائق (يُستعمل مرة واحدة).',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    FilledButton.icon(
                      onPressed: _newCode,
                      icon: const Icon(Icons.pin_outlined),
                      label: Text(
                        _session != null && _session!.isOpen
                            ? 'رمز جديد'
                            : 'إنشاء رمز ربط',
                      ),
                    ),
                    TextButton(
                      onPressed: _refresh,
                      child: const Text('تحديث القائمة'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            SurfaceCard(
              title: 'الأجهزة المرتبطة',
              icon: Icons.devices_other_rounded,
              child: _devices.isEmpty
                  ? const Text(
                      'لا توجد أجهزة مرتبطة بعد.',
                      style: TextStyle(color: AppColors.inkSoft),
                    )
                  : Column(
                      children: [
                        for (final d in _devices)
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text(
                              d.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              d.lastSeen == null
                                  ? 'لم يتصل بعد'
                                  : 'آخر اتصال ${_time.format(d.lastSeen!)}',
                              style: const TextStyle(fontSize: 11.5),
                            ),
                            children: [
                              for (final p in SyncPermission.values)
                                SwitchListTile(
                                  dense: true,
                                  value: d.permissions.contains(p),
                                  onChanged: (on) => _setPermission(d, p, on),
                                  title: Text(p.label),
                                  subtitle: Text(
                                    p.hint,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: TextButton.icon(
                                  onPressed: () => _revoke(d),
                                  icon: const Icon(
                                    Icons.link_off_rounded,
                                    color: AppColors.danger,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'فك الارتباط',
                                    style: TextStyle(color: AppColors.danger),
                                  ),
                                ),
                              ),
                            ],
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

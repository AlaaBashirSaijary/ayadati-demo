import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../data/lan_sync_client.dart';
import '../../data/lan_sync_server.dart';

/// Secretary/nurse tablet: find the doctor's device on the Wi-Fi and pair
/// with the code shown there.
class SecretaryPairingPage extends StatefulWidget {
  const SecretaryPairingPage({super.key, required this.onPaired});

  final void Function(SyncConnection connection) onPaired;

  @override
  State<SecretaryPairingPage> createState() => _SecretaryPairingPageState();
}

class _SecretaryPairingPageState extends State<SecretaryPairingPage> {
  final _host = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController(text: 'جهاز السكرتيرة');
  List<FoundHost> _found = [];
  bool _searching = false;
  bool _pairing = false;
  FoundHost? _selected;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _host.dispose();
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _searching = true);
    final found = await LanSyncClient.discover();
    if (!mounted) return;
    setState(() {
      _found = found;
      _searching = false;
      if (found.length == 1) _selected = found.first;
    });
  }

  Future<void> _pair() async {
    final host = _selected?.address ?? _host.text.trim();
    final port = _selected?.port ?? LanSyncServer.defaultPort;
    if (host.isEmpty || _code.text.trim().length < 6) {
      AppSnack.info(context, 'اختر جهاز الطبيب واكتب رمز الربط (6 أرقام).');
      return;
    }
    setState(() => _pairing = true);
    try {
      final connection = await LanSyncClient.pair(
        host: host,
        port: port,
        code: _code.text,
        deviceName: _name.text.trim().isEmpty
            ? 'جهاز السكرتيرة'
            : _name.text.trim(),
      );
      await connection.save();
      if (mounted) widget.onPaired(connection);
    } on SyncClientException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } finally {
      if (mounted) setState(() => _pairing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ربط بجهاز الطبيب')),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const Text(
              'على جهاز الطبيب: الإدارة ← "ربط جهاز السكرتيرة / الممرضة" ← تشغيل '
              'المشاركة ← إنشاء رمز ربط. وتأكد أن الجهازين على نفس الواي فاي.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.inkSoft,
                height: 1.6,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'أجهزة الأطباء على الشبكة',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                _searching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton(onPressed: _search, child: const Text('بحث')),
              ],
            ),
            if (_found.isEmpty && !_searching)
              const Text(
                'لم يظهر جهاز تلقائيًا — اكتب عنوانه أدناه.',
                style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
              ),
            for (final h in _found)
              ListTile(
                contentPadding: EdgeInsets.zero,
                selected: _selected == h,
                leading: Icon(
                  _selected == h
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                ),
                onTap: () => setState(() => _selected = h),
                title: Text(h.clinic.isEmpty ? 'جهاز الطبيب' : h.clinic),
                subtitle: Text(
                  '${h.address}:${h.port}',
                  textDirection: TextDirection.ltr,
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _host,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'أو عنوان جهاز الطبيب (مثال 192.168.1.20)',
              ),
              onChanged: (_) => setState(() => _selected = null),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'رمز الربط',
                counterText: '',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'اسم هذا الجهاز'),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _pairing ? null : _pair,
              icon: _pairing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link_rounded),
              label: const Text('ربط'),
            ),
          ],
        ),
      ),
    );
  }
}

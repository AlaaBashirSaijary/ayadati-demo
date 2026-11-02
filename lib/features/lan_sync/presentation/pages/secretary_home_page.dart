import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/money/currency.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../data/lan_sync_client.dart';
import '../../domain/sync_permissions.dart';

/// The secretary's / nurse's whole app: a small set of screens that talk to
/// the doctor's device. Only the tabs the doctor allowed are shown; the
/// doctor's device enforces the same limits on its side regardless.
class SecretaryHomePage extends StatefulWidget {
  const SecretaryHomePage({
    super.key,
    required this.connection,
    required this.onDisconnect,
  });

  final SyncConnection connection;
  final VoidCallback onDisconnect;

  @override
  State<SecretaryHomePage> createState() => _SecretaryHomePageState();
}

class _SecretaryHomePageState extends State<SecretaryHomePage> {
  late final LanSyncClient _client = LanSyncClient(widget.connection);
  Set<SyncPermission> _permissions = {};
  String _clinic = '';
  String? _error;
  bool _loading = true;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final info = await _client.call('session.info') as Map;
      _clinic = info['clinic'] as String? ?? widget.connection.clinic;
      _permissions = {
        for (final n in (info['permissions'] as List))
          ?SyncPermission.fromName(n as String),
      };
    } on SyncClientException catch (e) {
      _error = e.message;
      if (e.code == 'unpaired') {
        await SyncConnection.clear();
        if (mounted) widget.onDisconnect();
        return;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _disconnect() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('فك الارتباط بجهاز الطبيب؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('فك الارتباط'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await SyncConnection.clear();
    widget.onDisconnect();
  }

  List<(String, IconData, Widget Function())> get _tabs => [
    if (_permissions.contains(SyncPermission.viewPatients))
      (
        'المرضى',
        Icons.people_alt_outlined,
        () => _PatientsTab(client: _client, permissions: _permissions),
      ),
    if (_permissions.contains(SyncPermission.manageAppointments))
      (
        'المواعيد',
        Icons.event_outlined,
        () => _AppointmentsTab(client: _client, permissions: _permissions),
      ),
    if (_permissions.contains(SyncPermission.collectPayments))
      ('التحصيل', Icons.payments_outlined, () => _PaymentsTab(client: _client)),
  ];

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    return Scaffold(
      appBar: AppBar(
        title: Text(_clinic.isEmpty ? 'جهاز السكرتيرة' : _clinic),
        actions: [
          IconButton(
            tooltip: 'تحديث الاتصال',
            icon: const Icon(Icons.sync_rounded),
            onPressed: _load,
          ),
          IconButton(
            tooltip: 'فك الارتباط',
            icon: const Icon(Icons.link_off_rounded),
            onPressed: _disconnect,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            )
          : tabs.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Text('لم يمنحك الطبيب أي صلاحية بعد.'),
              ),
            )
          : ResponsiveBody(child: tabs[_tab.clamp(0, tabs.length - 1)].$3()),
      bottomNavigationBar: tabs.length < 2
          ? null
          : NavigationBar(
              selectedIndex: _tab.clamp(0, tabs.length - 1),
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: [
                for (final t in tabs)
                  NavigationDestination(icon: Icon(t.$2), label: t.$1),
              ],
            ),
    );
  }
}

Future<T?> _guard<T>(BuildContext context, Future<T> Function() action) async {
  try {
    return await action();
  } on SyncClientException catch (e) {
    if (context.mounted) AppSnack.error(context, e.message);
    return null;
  }
}

// ----------------------------------------------------------------- patients

class _PatientsTab extends StatefulWidget {
  const _PatientsTab({required this.client, required this.permissions});

  final LanSyncClient client;
  final Set<SyncPermission> permissions;

  @override
  State<_PatientsTab> createState() => _PatientsTabState();
}

class _PatientsTabState extends State<_PatientsTab> {
  final _query = TextEditingController();
  List<Map> _patients = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    final list = await _guard(
      context,
      () => widget.client.call('patients.search', {'q': _query.text.trim()}),
    );
    if (!mounted) return;
    setState(() {
      _patients = [for (final p in (list as List?) ?? const []) p as Map];
      _loading = false;
    });
  }

  Future<void> _add() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final age = TextEditingController();
    final address = TextEditingController();
    String? gender;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('مريض جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'الاسم الكامل'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'الهاتف'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: age,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'العمر'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: address,
                  decoration: const InputDecoration(labelText: 'العنوان'),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  emptySelectionAllowed: true,
                  segments: const [
                    ButtonSegment(value: 'male', label: Text('ذكر')),
                    ButtonSegment(value: 'female', label: Text('أنثى')),
                  ],
                  selected: {?gender},
                  onSelectionChanged: (s) =>
                      setLocal(() => gender = s.firstOrNull),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final created = await _guard(
      context,
      () => widget.client.call('patients.create', {
        'name': name.text,
        'phone': phone.text,
        'address': address.text,
        'age': int.tryParse(age.text.trim()),
        'gender': gender,
      }),
    );
    if (created != null && mounted) {
      AppSnack.success(context, 'تم تسجيل المريض وسيظهر عند الطبيب.');
      _search();
    }
  }

  Future<void> _open(Map p) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                p['name'] as String,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                [
                  if (p['number'] != null) 'رقم ${p['number']}',
                  if (p['age'] != null) '${p['age']} سنة',
                  if (p['phone'] != null) '${p['phone']}',
                ].join(' · '),
                style: const TextStyle(color: AppColors.inkSoft),
              ),
              const SizedBox(height: AppSpacing.md),
              if (widget.permissions.contains(
                SyncPermission.manageAppointments,
              ))
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.of(sheet).pop();
                    await bookAppointment(
                      context,
                      widget.client,
                      p['id'] as int,
                    );
                  },
                  icon: const Icon(Icons.event_available_rounded),
                  label: const Text('حجز موعد'),
                ),
              if (widget.permissions.contains(SyncPermission.editPatients))
                TextButton.icon(
                  onPressed: () async {
                    Navigator.of(sheet).pop();
                    await _editPhone(p);
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('تعديل الهاتف'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editPhone(Map p) async {
    final controller = TextEditingController(
      text: (p['phone'] as String?) ?? '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('هاتف ${p['name']}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final r = await _guard(
      context,
      () => widget.client.call('patients.update', {
        'id': p['id'],
        'phone': controller.text,
      }),
    );
    if (r != null) _search();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton:
          widget.permissions.contains(SyncPermission.registerPatients)
          ? FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('مريض جديد'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: TextField(
              controller: _query,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو الرقم أو الهاتف',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: _search,
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _patients.isEmpty
                ? const Center(
                    child: Text(
                      'لا نتائج.',
                      style: TextStyle(color: AppColors.inkSoft),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      96,
                    ),
                    itemCount: _patients.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final p = _patients[i];
                      return ListTile(
                        title: Text(
                          p['name'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          [
                            if (p['number'] != null) 'رقم ${p['number']}',
                            if (p['phone'] != null) '${p['phone']}',
                          ].join(' · '),
                        ),
                        trailing: const Icon(Icons.chevron_left_rounded),
                        onTap: () => _open(p),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Date → time → type, then books it; asks before double-booking a slot.
Future<void> bookAppointment(
  BuildContext context,
  LanSyncClient client,
  int patientId,
) async {
  final day = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime.now().subtract(const Duration(days: 1)),
    lastDate: DateTime.now().add(const Duration(days: 365)),
  );
  if (day == null || !context.mounted) return;
  final time = await showTimePicker(
    context: context,
    initialTime: const TimeOfDay(hour: 17, minute: 0),
  );
  if (time == null || !context.mounted) return;
  final at = DateTime(day.year, day.month, day.day, time.hour, time.minute);

  Future<Object?> create({bool force = false}) =>
      client.call('appointments.create', {
        'patientId': patientId,
        'at': at.toIso8601String(),
        if (force) 'force': true,
      });

  try {
    await create();
    if (context.mounted) AppSnack.success(context, 'تم حجز الموعد.');
  } on SyncClientException catch (e) {
    if (e.code == 'conflict' && context.mounted) {
      final force = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('موعد متعارض'),
          content: Text('${e.message}\nهل تحجز رغم ذلك؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('احجز'),
            ),
          ],
        ),
      );
      if (force == true && context.mounted) {
        await _guard(context, () => create(force: true));
        if (context.mounted) AppSnack.success(context, 'تم حجز الموعد.');
      }
    } else if (context.mounted) {
      AppSnack.error(context, e.message);
    }
  }
}

// -------------------------------------------------------------- appointments

class _AppointmentsTab extends StatefulWidget {
  const _AppointmentsTab({required this.client, required this.permissions});

  final LanSyncClient client;
  final Set<SyncPermission> permissions;

  @override
  State<_AppointmentsTab> createState() => _AppointmentsTabState();
}

class _AppointmentsTabState extends State<_AppointmentsTab> {
  DateTime _day = DateTime.now();
  List<Map> _items = [];
  bool _loading = true;
  static final _dayFormat = DateFormat('EEEE d MMMM', 'ar');
  static final _timeFormat = DateFormat('h:mm a', 'ar');

  static const _statusLabels = {
    'scheduled': 'مجدول',
    'completed': 'تمت الزيارة',
    'cancelled': 'ملغى',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _guard(
      context,
      () => widget.client.call('appointments.list', {
        'day': _day.toIso8601String(),
      }),
    );
    if (!mounted) return;
    setState(() {
      _items = [for (final a in (list as List?) ?? const []) a as Map];
      _loading = false;
    });
  }

  void _move(int days) {
    setState(() => _day = _day.add(Duration(days: days)));
    _load();
  }

  Future<void> _setStatus(Map a, String status) async {
    final r = await _guard(
      context,
      () => widget.client.call('appointments.setStatus', {
        'id': a['id'],
        'status': status,
      }),
    );
    if (r != null) _load();
  }

  Future<void> _addFor() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (c) => _PatientPicker(client: widget.client),
    );
    if (picked == null || !mounted) return;
    await bookAppointment(context, widget.client, picked);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addFor,
        icon: const Icon(Icons.add_rounded),
        label: const Text('حجز موعد'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () => _move(-1),
                ),
                Expanded(
                  child: Text(
                    _dayFormat.format(_day),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => _move(1),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? const Center(
                    child: Text(
                      'لا مواعيد في هذا اليوم.',
                      style: TextStyle(color: AppColors.inkSoft),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      96,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final a = _items[i];
                      final status = a['status'] as String;
                      return Card(
                        child: ListTile(
                          title: Text(
                            (a['name'] as String?) ?? '—',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${_timeFormat.format(DateTime.parse(a['at'] as String))} · ${_statusLabels[status] ?? status}',
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (s) => _setStatus(a, s),
                            itemBuilder: (_) => [
                              for (final e in _statusLabels.entries)
                                PopupMenuItem(
                                  value: e.key,
                                  child: Text(e.value),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PatientPicker extends StatefulWidget {
  const _PatientPicker({required this.client});

  final LanSyncClient client;

  @override
  State<_PatientPicker> createState() => _PatientPickerState();
}

class _PatientPickerState extends State<_PatientPicker> {
  final _query = TextEditingController();
  List<Map> _items = [];

  Future<void> _search() async {
    final list = await _guard(
      context,
      () => widget.client.call('patients.search', {'q': _query.text.trim()}),
    );
    if (mounted) {
      setState(
        () => _items = [for (final p in (list as List?) ?? const []) p as Map],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SizedBox(
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _query,
              autofocus: true,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'اختر المريض: اكتب جزءًا من الاسم ثم ابحث',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search_rounded),
                  onPressed: _search,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final p in _items)
                    ListTile(
                      title: Text(p['name'] as String),
                      subtitle: Text('${p['phone'] ?? ''}'),
                      onTap: () => Navigator.of(context).pop(p['id'] as int),
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

// ----------------------------------------------------------------- payments

class _PaymentsTab extends StatefulWidget {
  const _PaymentsTab({required this.client});

  final LanSyncClient client;

  @override
  State<_PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<_PaymentsTab> {
  List<Map> _debts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _guard(
      context,
      () => widget.client.call('payments.debts'),
    );
    if (!mounted) return;
    setState(() {
      _debts = [for (final d in (list as List?) ?? const []) d as Map];
      _loading = false;
    });
  }

  String _owed(Map d) {
    final owed = d['owed'] as Map;
    return [
      for (final e in owed.entries)
        Currency.fromCode(e.key as String).format((e.value as num).toDouble()),
    ].join('  +  ');
  }

  Future<void> _pay(Map d) async {
    final owed = (d['owed'] as Map).map(
      (k, v) => MapEntry(Currency.fromCode(k as String), (v as num).toDouble()),
    );
    var currency = owed.keys.first;
    final amount = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('دفعة من ${d['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (owed.length > 1)
                SegmentedButton<Currency>(
                  segments: [
                    for (final c in owed.keys)
                      ButtonSegment(value: c, label: Text(c.symbol)),
                  ],
                  selected: {currency},
                  onSelectionChanged: (s) => setLocal(() => currency = s.first),
                ),
              const SizedBox(height: 8),
              Text(
                'المتبقي: ${currency.format(owed[currency]!)}',
                style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
              ),
              TextField(
                controller: amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'المبلغ',
                  suffixText: currency.symbol,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('تسجيل'),
            ),
          ],
        ),
      ),
    );
    final value = double.tryParse(amount.text.trim().replaceAll(',', '.'));
    if (ok != true || value == null || value <= 0 || !mounted) return;
    final r = await _guard(
      context,
      () => widget.client.call('payments.record', {
        'patientId': d['patientId'],
        'currency': currency.code,
        'amount': value,
      }),
    );
    if (r != null && mounted) {
      AppSnack.success(context, 'سُجّلت الدفعة عند الطبيب.');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : _debts.isEmpty
        ? const Center(
            child: Text(
              'لا مبالغ متبقية.',
              style: TextStyle(color: AppColors.inkSoft),
            ),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: _debts.length,
              itemBuilder: (_, i) {
                final d = _debts[i];
                return Card(
                  child: ListTile(
                    title: Text(
                      d['name'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      _owed(d),
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    trailing: FilledButton.tonal(
                      onPressed: () => _pay(d),
                      child: const Text('دفعة'),
                    ),
                  ),
                );
              },
            ),
          );
  }
}

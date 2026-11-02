import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/whatsapp/whatsapp_service.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../clinics/presentation/providers/active_clinic_provider.dart';
import '../../domain/services/booking_link.dart';

/// Builds the clinic's patient-facing booking link and QR code. The doctor
/// picks working days and hours once; the link carries those settings, so
/// the booking page can offer only valid slots without any server. A
/// patient who uses it sends a structured WhatsApp message that "حجز من رسالة
/// واتساب" turns into an appointment in one tap.
class BookingLinkPage extends ConsumerStatefulWidget {
  const BookingLinkPage({super.key});

  @override
  ConsumerState<BookingLinkPage> createState() => _BookingLinkPageState();
}

class _BookingLinkPageState extends ConsumerState<BookingLinkPage> {
  static const _weekdayOrder = [6, 7, 1, 2, 3, 4, 5]; // Sat … Fri
  static const _weekdayNames = {
    1: 'الاثنين',
    2: 'الثلاثاء',
    3: 'الأربعاء',
    4: 'الخميس',
    5: 'الجمعة',
    6: 'السبت',
    7: 'الأحد',
  };

  final _phoneController = TextEditingController();
  Set<int> _days = {6, 7, 1, 2, 3, 4};
  int _from = 10;
  int _to = 20;
  bool _loaded = false;

  String get _prefix =>
      'booking_link.${ref.read(activeClinicProvider).active?.id}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _phoneController.text = prefs.getString('$_prefix.phone') ?? '';
    final days = prefs.getStringList('$_prefix.days');
    if (days != null) _days = days.map(int.parse).toSet();
    _from = prefs.getInt('$_prefix.from') ?? _from;
    _to = prefs.getInt('$_prefix.to') ?? _to;
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix.phone', _phoneController.text.trim());
    await prefs.setStringList('$_prefix.days', _days.map((d) => '$d').toList());
    await prefs.setInt('$_prefix.from', _from);
    await prefs.setInt('$_prefix.to', _to);
  }

  String? get _link {
    final number = WhatsAppService.normalize(_phoneController.text);
    final clinic = ref.read(activeClinicProvider).active?.name ?? '';
    if (number == null || _days.isEmpty || _to <= _from) return null;
    return BookingLink.build(
      clinicName: clinic,
      whatsappNumber: number,
      days: _days,
      fromHour: _from,
      toHour: _to,
    );
  }

  Future<void> _copy(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) AppSnack.success(context, 'تم نسخ رابط الحجز.');
  }

  Future<void> _shareOnWhatsApp(String link) async {
    final clinic = ref.read(activeClinicProvider).active?.name ?? 'العيادة';
    final text =
        'لحجز موعد في $clinic اضغط على الرابط واختر الوقت المناسب:\n$link';
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    final opened = await _launch(uri);
    if (!opened && mounted) AppSnack.error(context, 'تعذّر فتح واتساب.');
  }

  Future<bool> _launch(Uri uri) async {
    // Reuses the shared opener when a number is known; here there's no
    // recipient (the doctor picks a contact or status in WhatsApp itself).
    return WhatsAppService.openUri(uri);
  }

  @override
  Widget build(BuildContext context) {
    final link = _loaded ? _link : null;

    return Scaffold(
      appBar: AppBar(title: const Text('رابط الحجز عبر واتساب')),
      body: ResponsiveBody(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  const Text(
                    'شاركي الرابط أو الـQR مع مرضاك: يختار المريض يومًا ووقتًا '
                    'من أوقات دوامك، فتصلك رسالة منظّمة على واتساب تتحول لموعد '
                    'بضغطة من "حجز من رسالة واتساب".',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.inkSoft,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SurfaceCard(
                    title: 'إعدادات الحجز',
                    icon: Icons.tune_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textDirection: TextDirection.ltr,
                          onChanged: (_) {
                            _save();
                            setState(() {});
                          },
                          decoration: const InputDecoration(
                            labelText: 'رقم واتساب العيادة',
                            hintText: '0944123456',
                            helperText: 'الرقم الذي ستصلك عليه طلبات الحجز',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Text(
                          'أيام الدوام',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final d in _weekdayOrder)
                              FilterChip(
                                label: Text(_weekdayNames[d]!),
                                selected: _days.contains(d),
                                selectedColor: AppColors.aqua.withValues(
                                  alpha: 0.18,
                                ),
                                onSelected: (on) {
                                  setState(
                                    () => on ? _days.add(d) : _days.remove(d),
                                  );
                                  _save();
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: _HourPicker(
                                label: 'من الساعة',
                                value: _from,
                                onChanged: (h) {
                                  setState(() => _from = h);
                                  _save();
                                },
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _HourPicker(
                                label: 'حتى الساعة',
                                value: _to,
                                onChanged: (h) {
                                  setState(() => _to = h);
                                  _save();
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (link == null)
                    const SurfaceCard(
                      child: Text(
                        'أدخلي رقم واتساب العيادة، واختاري يومًا واحدًا على الأقل '
                        'وساعة نهاية بعد البداية ليظهر الرابط والـQR.',
                        style: TextStyle(color: AppColors.inkSoft, height: 1.5),
                      ),
                    )
                  else
                    SurfaceCard(
                      title: 'رابطك جاهز',
                      icon: Icons.qr_code_2_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.ink.withValues(alpha: 0.08),
                                ),
                              ),
                              child: QrImageView(
                                data: link,
                                size: 200,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: AppColors.aquaDeep,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          SelectableText(
                            link,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.inkSoft,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _copy(link),
                                  icon: const Icon(
                                    Icons.copy_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('نسخ الرابط'),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _shareOnWhatsApp(link),
                                  icon: const Icon(
                                    Icons.chat_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('مشاركة بواتساب'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF1FA855),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          const Text(
                            'ضعيه في وصف حساب واتساب للأعمال أو اطبعي الـQR '
                            'وعلّقيه على باب العيادة.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.inkSoft,
                            ),
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

class _HourPicker extends StatelessWidget {
  const _HourPicker({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  static String _text(int h) {
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12 ${h < 12 ? 'ص' : 'م'}';
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (var h = 6; h <= 23; h++)
          DropdownMenuItem(value: h, child: Text(_text(h))),
      ],
      onChanged: (h) {
        if (h != null) onChanged(h);
      },
    );
  }
}

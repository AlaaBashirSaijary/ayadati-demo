import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/ai/gemini_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/whatsapp/whatsapp_service.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../clinics/presentation/providers/active_clinic_provider.dart';
import '../../domain/clinic_page_data.dart';

const _previewBase = 'https://alaabashirsaijary.github.io/clinic-pages/sample-';
const _supportWhatsApp = '963984668063';
const _weekdayOrder = [6, 7, 1, 2, 3, 4, 5];
const _weekdayNames = {
  1: 'الاثنين',
  2: 'الثلاثاء',
  3: 'الأربعاء',
  4: 'الخميس',
  5: 'الجمعة',
  6: 'السبت',
  7: 'الأحد',
};

/// "صفحة عيادتي": the doctor fills in their details once, picks a design and
/// a colour (independent choices), and sends the result to be published as a
/// public page with built-in WhatsApp booking. Everything is stored locally;
/// publishing hands a small JSON file (+ the photo) to the vendor, who puts
/// the page online and sends back its link, which the doctor pastes here.
class ClinicPagePage extends ConsumerStatefulWidget {
  const ClinicPagePage({super.key});

  @override
  ConsumerState<ClinicPagePage> createState() => _ClinicPagePageState();
}

class _ClinicPagePageState extends ConsumerState<ClinicPagePage> {
  final _doctor = TextEditingController();
  final _specialty = TextEditingController();
  final _clinic = TextEditingController();
  final _tagline = TextEditingController();
  final _about = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  final _map = TextEditingController();
  final _color = TextEditingController();
  final _service = TextEditingController();
  final _credential = TextEditingController();
  final _published = TextEditingController();

  ClinicPageData _data = ClinicPageData();
  bool _loaded = false;
  bool _writing = false;

  String get _key => 'clinic_page.${ref.read(activeClinicProvider).active?.id}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _doctor,
      _specialty,
      _clinic,
      _tagline,
      _about,
      _phone,
      _city,
      _address,
      _map,
      _color,
      _service,
      _credential,
      _published,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    var data = raw == null
        ? ClinicPageData()
        : ClinicPageData.fromStorageJson(
            jsonDecode(raw) as Map<String, dynamic>,
          );
    if (raw == null) {
      // First open: borrow what the booking-link screen already knows.
      final id = ref.read(activeClinicProvider).active?.id;
      final days = prefs.getStringList('booking_link.$id.days');
      data = data.copyWith(
        clinicName: ref.read(activeClinicProvider).active?.name ?? '',
        phone: prefs.getString('booking_link.$id.phone') ?? '',
        days: days?.map(int.parse).toSet(),
        fromHour: prefs.getInt('booking_link.$id.from'),
        toHour: prefs.getInt('booking_link.$id.to'),
      );
    }
    _data = data;
    _doctor.text = data.doctorName;
    _specialty.text = data.specialty;
    _clinic.text = data.clinicName;
    _tagline.text = data.tagline;
    _about.text = data.about;
    _phone.text = data.phone;
    _city.text = data.city;
    _address.text = data.address;
    _map.text = data.mapUrl;
    _color.text = data.colorHex;
    _published.text = data.publishedUrl;
    if (mounted) setState(() => _loaded = true);
  }

  ClinicPageData _collect() => _data.copyWith(
    doctorName: _doctor.text,
    specialty: _specialty.text,
    clinicName: _clinic.text,
    tagline: _tagline.text,
    about: _about.text,
    phone: _phone.text,
    city: _city.text,
    address: _address.text,
    mapUrl: _map.text,
    publishedUrl: _published.text.trim(),
  );

  Future<ClinicPageData> _save() async {
    _data = _collect();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_data.toStorageJson()));
    return _data;
  }

  Future<String> _photoFilePath() async {
    final dir = await databaseFactory.getDatabasesPath();
    return p.join(dir, 'clinic_page_${_data.pageId}.jpg');
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 82,
    );
    if (file == null) return;
    final target = await _photoFilePath();
    await File(target).writeAsBytes(await file.readAsBytes());
    setState(() => _data = _collect().copyWith(photoPath: target));
    await _save();
  }

  Future<void> _preview() async {
    final data = await _save();
    final uri = Uri.parse(
      '$_previewBase${data.layout.key}/?color=${data.colorHex.toUpperCase()}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      AppSnack.error(context, 'تعذّر فتح المعاينة. تأكد من اتصالك بالإنترنت.');
    }
  }

  Future<void> _writeAbout() async {
    if (_specialty.text.trim().isEmpty) {
      AppSnack.info(context, 'اكتب التخصص أولًا.');
      return;
    }
    setState(() => _writing = true);
    final text = await GeminiService.instance.generateText(
      'اكتب بالعربية الفصحى المبسطة، بنبرة مهنية محايدة بلا مبالغة ولا وعود '
      'بالشفاء ولا عبارات تفضيل مثل "الأفضل"، شيئين بصيغة JSON فقط '
      '{"tagline":"جملة قصيرة جذابة (أقل من 60 حرفًا)",'
      '"about":"فقرة تعريفية من 3 جمل"} لصفحة عيادة تخصص '
      '${_specialty.text.trim()}'
      '${_services().isEmpty ? '' : ' وخدماتها: ${_services().join('، ')}'}.',
    );
    if (!mounted) return;
    setState(() => _writing = false);
    try {
      final m = RegExp(r'\{[\s\S]*\}').firstMatch(text ?? '');
      final j = jsonDecode(m!.group(0)!) as Map<String, dynamic>;
      _tagline.text = j['tagline'] as String? ?? _tagline.text;
      _about.text = j['about'] as String? ?? _about.text;
      AppSnack.success(context, 'تمت الكتابة. راجعها وعدّلها كما تشاء.');
    } catch (_) {
      AppSnack.error(context, 'تعذّر الاتصال بالمساعد الذكي الآن.');
    }
  }

  List<String> _services() => _data.services;

  String get _whatsApp => WhatsAppService.normalize(_phone.text) ?? '';

  Future<void> _sendForPublishing() async {
    final data = await _save();
    final problem = data.validate();
    if (problem != null) {
      if (mounted) AppSnack.error(context, problem);
      return;
    }
    final dir = Directory.systemTemp.createTempSync('clinic_page');
    final jsonFile = File(p.join(dir.path, '${data.pageId}.json'))
      ..writeAsStringSync(data.toSiteJsonString(whatsapp: _whatsApp));
    final files = [XFile(jsonFile.path, mimeType: 'application/json')];
    if (data.photoPath != null && File(data.photoPath!).existsSync()) {
      files.add(
        XFile(
          data.photoPath!,
          mimeType: 'image/jpeg',
          name: '${data.pageId}.jpg',
        ),
      );
    }
    await SharePlus.instance.share(
      ShareParams(
        files: files,
        text: 'طلب نشر صفحة عيادة (${data.doctorName.trim()})',
        subject: 'صفحة عيادتي',
      ),
    );
    if (mounted) {
      AppSnack.info(
        context,
        'أرسل الملفات إلى واتساب الدعم. سنردّ عليك برابط صفحتك.',
      );
    }
  }

  Future<void> _openSupport() => WhatsAppService.openUri(
    Uri.parse(
      'https://wa.me/$_supportWhatsApp?text=${Uri.encodeComponent('مرحبًا، أريد نشر صفحة عيادتي.')}',
    ),
  );

  void _addTo(
    TextEditingController c,
    List<String> list,
    void Function(List<String>) set,
  ) {
    final v = c.text.trim();
    if (v.isEmpty) return;
    set([...list, v]);
    c.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('صفحة عيادتي')),
      body: ResponsiveBody(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  const Text(
                    'صفحة احترافية باسمك تظهر في جوجل، فيها حجز عبر واتساب وحالة '
                    'الدوام. املأ بياناتك مرة واحدة، اختر التصميم واللون، ثم أرسلها '
                    'للنشر.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.inkSoft,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _designCard(),
                  const SizedBox(height: AppSpacing.md),
                  _identityCard(),
                  const SizedBox(height: AppSpacing.md),
                  _listCard(
                    title: 'الخدمات',
                    icon: Icons.medical_services_outlined,
                    hint: 'أضف خدمة (مثال: فحص النظر)',
                    controller: _service,
                    items: _data.services,
                    onChange: (l) => setState(
                      () => _data = _collect().copyWith(services: l),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _listCard(
                    title: 'الشهادات والعضويات (اختياري)',
                    icon: Icons.verified_outlined,
                    hint: 'مثال: عضو نقابة أطباء سوريا',
                    controller: _credential,
                    items: _data.credentials,
                    onChange: (l) => setState(
                      () => _data = _collect().copyWith(credentials: l),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _hoursCard(),
                  const SizedBox(height: AppSpacing.md),
                  _locationCard(),
                  const SizedBox(height: AppSpacing.md),
                  _publishCard(),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
      ),
    );
  }

  Widget _designCard() {
    final color = ClinicPageData.isValidHex(_color.text)
        ? Color(int.parse('FF${_color.text}', radix: 16))
        : AppColors.aqua;
    return SurfaceCard(
      title: 'التصميم واللون',
      icon: Icons.palette_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final l in PageLayout.values)
                ChoiceChip(
                  label: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(l.blurb, style: const TextStyle(fontSize: 10.5)),
                    ],
                  ),
                  selected: _data.layout == l,
                  onSelected: (_) =>
                      setState(() => _data = _collect().copyWith(layout: l)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final (name, hex) in pagePalettes)
                Tooltip(
                  message: name,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(99),
                    onTap: () => setState(() {
                      _color.text = hex;
                      _data = _collect().copyWith(colorHex: hex);
                    }),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Color(int.parse('FF$hex', radix: 16)),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _data.colorHex.toUpperCase() == hex
                              ? AppColors.ink
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _color,
            maxLength: 6,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: 'أو أدخل لونًا خاصًا (6 خانات)',
              prefixText: '#',
              suffixIcon: Padding(
                padding: const EdgeInsets.all(10),
                child: CircleAvatar(backgroundColor: color, radius: 10),
              ),
              counterText: '',
            ),
            onChanged: (v) {
              if (ClinicPageData.isValidHex(v)) {
                setState(() => _data = _collect().copyWith(colorHex: v));
              } else {
                setState(() {});
              }
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _preview,
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('معاينة التصميم بهذا اللون'),
          ),
        ],
      ),
    );
  }

  Widget _identityCard() {
    final hasPhoto =
        _data.photoPath != null && File(_data.photoPath!).existsSync();
    return SurfaceCard(
      title: 'هوية العيادة',
      icon: Icons.badge_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: AppColors.sky,
                backgroundImage: hasPhoto
                    ? FileImage(File(_data.photoPath!))
                    : null,
                child: hasPhoto
                    ? null
                    : const Icon(
                        Icons.person_outline,
                        color: AppColors.aqua,
                        size: 34,
                      ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickPhoto,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(hasPhoto ? 'تغيير الصورة' : 'صورة الطبيب'),
                    ),
                    if (hasPhoto)
                      TextButton(
                        onPressed: () async {
                          await File(_data.photoPath!).delete();
                          setState(
                            () => _data = _collect().copyWith(clearPhoto: true),
                          );
                          await _save();
                        },
                        child: const Text('حذف'),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'صورة واضحة بإضاءة جيدة ترفع جودة الصفحة كثيرًا.',
            style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _doctor,
            decoration: const InputDecoration(
              labelText: 'اسم الطبيب (مثال: د. سامر الحلبي)',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _specialty,
            decoration: const InputDecoration(
              labelText: 'التخصص (مثال: طب وجراحة العيون)',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _clinic,
            decoration: const InputDecoration(labelText: 'اسم العيادة'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _tagline,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'شعار قصير'),
          ),
          TextField(
            controller: _about,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'نبذة عنك وعن العيادة',
            ),
          ),
          if (GeminiService.instance.isAvailable) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: _writing ? null : _writeAbout,
                icon: _writing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 18),
                label: const Text('اكتب الشعار والنبذة بالمساعد الذكي'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _listCard({
    required String title,
    required IconData icon,
    required String hint,
    required TextEditingController controller,
    required List<String> items,
    required void Function(List<String>) onChange,
  }) {
    return SurfaceCard(
      title: title,
      icon: icon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (items.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in items)
                  InputChip(
                    label: Text(s),
                    onDeleted: () => onChange([...items]..remove(s)),
                  ),
              ],
            ),
          if (items.isNotEmpty) const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(hintText: hint),
                  onSubmitted: (_) => _addTo(controller, items, onChange),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () => _addTo(controller, items, onChange),
                icon: const Icon(Icons.add),
                tooltip: 'إضافة',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hoursCard() {
    return SurfaceCard(
      title: 'الدوام والحجز',
      icon: Icons.schedule_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'رقم واتساب العيادة',
              hintText: '09XXXXXXXX',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in _weekdayOrder)
                FilterChip(
                  label: Text(_weekdayNames[d]!),
                  selected: _data.days.contains(d),
                  onSelected: (on) {
                    final days = {..._data.days};
                    on ? days.add(d) : days.remove(d);
                    setState(() => _data = _collect().copyWith(days: days));
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _hourDropdown(
                  'من',
                  _data.fromHour,
                  (v) =>
                      setState(() => _data = _collect().copyWith(fromHour: v)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _hourDropdown(
                  'إلى',
                  _data.toHour,
                  (v) => setState(() => _data = _collect().copyWith(toHour: v)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hourDropdown(String label, int value, ValueChanged<int> onChanged) {
    String fmt(int h) =>
        '${h % 12 == 0 ? 12 : h % 12}:00 ${h < 12 ? 'ص' : 'م'}';
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (var h = 0; h <= 24; h++)
          DropdownMenuItem(
            value: h,
            child: Text(fmt(h % 24 == 0 && h == 24 ? 0 : h)),
          ),
      ],
      onChanged: (v) => v == null ? null : onChanged(v),
    );
  }

  Widget _locationCard() {
    return SurfaceCard(
      title: 'الموقع',
      icon: Icons.place_outlined,
      child: Column(
        children: [
          TextField(
            controller: _city,
            decoration: const InputDecoration(labelText: 'المدينة'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _address,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'العنوان التفصيلي'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _map,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'رابط الموقع على خرائط جوجل (اختياري)',
            ),
          ),
        ],
      ),
    );
  }

  Widget _publishCard() {
    final url = _published.text.trim();
    return SurfaceCard(
      title: 'النشر',
      icon: Icons.rocket_launch_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '1) اضغط "أرسل للنشر" واختر واتساب الدعم.\n'
            '2) نجهّز صفحتك ونرسل لك رابطها.\n'
            '3) الصق الرابط هنا لتشاركه مع مرضاك أو تطبعه كـQR.',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.inkSoft,
              height: 1.8,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: _sendForPublishing,
            icon: const Icon(Icons.send_rounded),
            label: const Text('أرسل للنشر'),
          ),
          TextButton.icon(
            onPressed: _openSupport,
            icon: const Icon(Icons.chat_outlined, size: 18),
            label: const Text('تواصل مع الدعم'),
          ),
          const Divider(height: 28),
          TextField(
            controller: _published,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'رابط صفحتي بعد النشر',
            ),
            onChanged: (_) => setState(() {}),
            onEditingComplete: _save,
          ),
          if (url.startsWith('http')) ...[
            const SizedBox(height: AppSpacing.md),
            Center(
              child: QrImageView(
                data: url,
                size: 150,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: url));
                    if (mounted) AppSnack.success(context, 'تم نسخ الرابط.');
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('نسخ'),
                ),
                OutlinedButton.icon(
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(text: 'صفحة عيادتي:\n$url'),
                  ),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('مشاركة'),
                ),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('فتح'),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: () async {
              await _save();
              if (mounted) AppSnack.success(context, 'تم حفظ بياناتك.');
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

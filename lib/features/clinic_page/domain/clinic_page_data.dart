import 'dart:convert';

/// The four designs a doctor can pick for their public page. The design and
/// the colour are independent choices (see tools/clinic_pages/build.py).
enum PageLayout {
  aurora('aurora', 'أورورا', 'عصري بخلفية متدرجة متحركة'),
  editorial('editorial', 'مجلّة', 'خط كبير أنيق وتصميم هادئ'),
  story('story', 'قصة', 'عمود ضيق مناسب للمشاركة على إنستغرام'),
  luxe('luxe', 'فخامة', 'داكن بتوهج لوني راقٍ');

  const PageLayout(this.key, this.label, this.blurb);

  final String key;
  final String label;
  final String blurb;

  static PageLayout fromKey(String? key) => PageLayout.values.firstWhere(
    (l) => l.key == key,
    orElse: () => PageLayout.aurora,
  );
}

/// Ready-made colours, same set as tools/clinic_pages/palettes.json.
const pagePalettes = <(String, String)>[
  ('فيروزي', '1287A0'),
  ('أخضر', '2F7D4F'),
  ('نيلي', '2B3F8C'),
  ('وردي', 'B8475A'),
  ('عنبري', 'B7791F'),
  ('بنفسجي', '6D45B5'),
  ('رمادي أزرق', '3E5C76'),
  ('مرجاني', 'D1553A'),
];

/// Everything the doctor enters for the public clinic page. Stored per
/// clinic on the device; [toSiteJson] is the exact shape the page builder
/// reads, so publishing is just sending that file (and the photo).
class ClinicPageData {
  ClinicPageData({
    this.layout = PageLayout.aurora,
    this.colorHex = '1287A0',
    this.doctorName = '',
    this.specialty = '',
    this.clinicName = '',
    this.tagline = '',
    this.about = '',
    this.services = const [],
    this.credentials = const [],
    this.phone = '',
    this.days = const {6, 7, 1, 2, 3, 4},
    this.fromHour = 16,
    this.toHour = 21,
    this.city = '',
    this.address = '',
    this.mapUrl = '',
    this.photoPath,
    this.publishedUrl = '',
    String? pageId,
  }) : pageId = pageId ?? _newId();

  final PageLayout layout;
  final String colorHex;
  final String doctorName;
  final String specialty;
  final String clinicName;
  final String tagline;
  final String about;
  final List<String> services;
  final List<String> credentials;
  final String phone;

  /// DateTime weekday numbers: 1 = Monday … 7 = Sunday.
  final Set<int> days;
  final int fromHour;
  final int toHour;
  final String city;
  final String address;
  final String mapUrl;
  final String? photoPath;
  final String publishedUrl;

  /// Random, unguessable folder name for the published page.
  final String pageId;

  static String _newId() {
    const chars = 'abcdefghijkmnpqrstuvwxyz23456789';
    final now = DateTime.now().microsecondsSinceEpoch;
    var n = now ^ (now >> 7);
    final b = StringBuffer('c');
    for (var i = 0; i < 7; i++) {
      b.write(chars[n.abs() % chars.length]);
      n = (n ~/ chars.length) + now + i * 7919;
    }
    return b.toString();
  }

  static final _hex = RegExp(r'^[0-9a-fA-F]{6}$');
  static bool isValidHex(String v) => _hex.hasMatch(v);

  /// The mandatory minimum before a page can be sent for publishing.
  String? validate() {
    if (doctorName.trim().isEmpty) return 'اكتب اسم الطبيب.';
    if (specialty.trim().isEmpty) return 'اكتب التخصص.';
    if (phone.trim().replaceAll(RegExp(r'\D'), '').length < 9) {
      return 'اكتب رقم واتساب صحيح.';
    }
    if (days.isEmpty || toHour <= fromHour) return 'حدّد أيام الدوام وساعاته.';
    if (!isValidHex(colorHex)) return 'اللون يجب أن يكون 6 خانات مثل 1287A0.';
    return null;
  }

  ClinicPageData copyWith({
    PageLayout? layout,
    String? colorHex,
    String? doctorName,
    String? specialty,
    String? clinicName,
    String? tagline,
    String? about,
    List<String>? services,
    List<String>? credentials,
    String? phone,
    Set<int>? days,
    int? fromHour,
    int? toHour,
    String? city,
    String? address,
    String? mapUrl,
    String? photoPath,
    bool clearPhoto = false,
    String? publishedUrl,
  }) => ClinicPageData(
    layout: layout ?? this.layout,
    colorHex: colorHex ?? this.colorHex,
    doctorName: doctorName ?? this.doctorName,
    specialty: specialty ?? this.specialty,
    clinicName: clinicName ?? this.clinicName,
    tagline: tagline ?? this.tagline,
    about: about ?? this.about,
    services: services ?? this.services,
    credentials: credentials ?? this.credentials,
    phone: phone ?? this.phone,
    days: days ?? this.days,
    fromHour: fromHour ?? this.fromHour,
    toHour: toHour ?? this.toHour,
    city: city ?? this.city,
    address: address ?? this.address,
    mapUrl: mapUrl ?? this.mapUrl,
    photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
    publishedUrl: publishedUrl ?? this.publishedUrl,
    pageId: pageId,
  );

  Map<String, dynamic> toStorageJson() => {
    'layout': layout.key,
    'color': colorHex,
    'doctorName': doctorName,
    'specialty': specialty,
    'clinicName': clinicName,
    'tagline': tagline,
    'about': about,
    'services': services,
    'credentials': credentials,
    'phone': phone,
    'days': days.toList(),
    'from': fromHour,
    'to': toHour,
    'city': city,
    'address': address,
    'mapUrl': mapUrl,
    'photoPath': photoPath,
    'publishedUrl': publishedUrl,
    'pageId': pageId,
  };

  factory ClinicPageData.fromStorageJson(Map<String, dynamic> j) =>
      ClinicPageData(
        layout: PageLayout.fromKey(j['layout'] as String?),
        colorHex: (j['color'] as String?) ?? '1287A0',
        doctorName: (j['doctorName'] as String?) ?? '',
        specialty: (j['specialty'] as String?) ?? '',
        clinicName: (j['clinicName'] as String?) ?? '',
        tagline: (j['tagline'] as String?) ?? '',
        about: (j['about'] as String?) ?? '',
        services: List<String>.from((j['services'] as List?) ?? const []),
        credentials: List<String>.from((j['credentials'] as List?) ?? const []),
        phone: (j['phone'] as String?) ?? '',
        days: ((j['days'] as List?) ?? const [6, 7, 1, 2, 3, 4])
            .map((d) => d as int)
            .toSet(),
        fromHour: (j['from'] as int?) ?? 16,
        toHour: (j['to'] as int?) ?? 21,
        city: (j['city'] as String?) ?? '',
        address: (j['address'] as String?) ?? '',
        mapUrl: (j['mapUrl'] as String?) ?? '',
        photoPath: j['photoPath'] as String?,
        publishedUrl: (j['publishedUrl'] as String?) ?? '',
        pageId: j['pageId'] as String?,
      );

  /// The file the page builder reads. Weekdays are converted to JavaScript's
  /// numbering (0 = Sunday … 6 = Saturday).
  Map<String, dynamic> toSiteJson({required String whatsapp}) => {
    'slug': pageId,
    'layout': layout.key,
    'color': '#${colorHex.toUpperCase()}',
    'name': doctorName.trim(),
    'specialty': specialty.trim(),
    'clinic': clinicName.trim(),
    'tagline': tagline.trim(),
    'about': about.trim(),
    'credentials': credentials,
    'services': services,
    'phone': phone.trim(),
    'whatsapp': whatsapp,
    'city': city.trim(),
    'address': address.trim(),
    'map_url': mapUrl.trim(),
    'booking': {
      'days': (days.map((d) => d % 7).toList()..sort()),
      'from': fromHour,
      'to': toHour,
    },
    if (photoPath != null) 'photo': 'photo.jpg',
  };

  String toSiteJsonString({required String whatsapp}) =>
      const JsonEncoder.withIndent(' ').convert(toSiteJson(whatsapp: whatsapp));
}

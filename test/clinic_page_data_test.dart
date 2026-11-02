import 'package:clinic_manager_flutter/features/clinic_page/domain/clinic_page_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'site json converts weekdays to JavaScript numbering and keeps colour',
    () {
      final data = ClinicPageData(
        doctorName: 'د. سامر',
        specialty: 'عيون',
        phone: '0911111111',
        days: {7, 1, 6},
        colorHex: 'c2410c',
      );
      final json = data.toSiteJson(whatsapp: '963911111111');
      expect(json['booking']['days'], [0, 1, 6]); // Sun, Mon, Sat
      expect(json['color'], '#C2410C');
      expect(json['slug'], data.pageId);
      expect(json.containsKey('photo'), false);
    },
  );

  test('validate asks for the essentials and a proper colour', () {
    expect(ClinicPageData().validate(), isNotNull);
    final ok = ClinicPageData(
      doctorName: 'د. سامر',
      specialty: 'عيون',
      phone: '0911111111',
    );
    expect(ok.validate(), isNull);
    expect(ok.copyWith(colorHex: 'xyz').validate(), isNotNull);
  });

  test('storage json round-trips', () {
    final data = ClinicPageData(
      layout: PageLayout.luxe,
      doctorName: 'د. سامر',
      services: ['فحص النظر'],
    );
    final back = ClinicPageData.fromStorageJson(data.toStorageJson());
    expect(back.layout, PageLayout.luxe);
    expect(back.services, ['فحص النظر']);
    expect(back.pageId, data.pageId);
  });
}

import 'package:clinic_manager_flutter/features/clinic_assistant/domain/patient_ai_prompts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const visits = [
    VisitBrief(
      date: '2026/10/01',
      type: 'معاينة',
      summary: 'التهاب ملتحمة',
      outcome: 'تحسّن',
    ),
  ];

  test(
    'brief prompt carries the clinical facts and tells the model not to invent',
    () {
      final p = patientBriefPrompt(
        age: 54,
        gender: 'ذكر',
        allergies: 'بنسلين',
        currentMedications: 'ميتفورمين',
        lastVisits: visits,
      );
      expect(p, contains('بنسلين'));
      expect(p, contains('ميتفورمين'));
      expect(p, contains('التهاب ملتحمة'));
      expect(p, contains('لا تضف أي معلومة غير مذكورة'));
      expect(p, isNot(contains('null')));
    },
  );

  test('empty optional facts are left out instead of printed as blanks', () {
    final p = patientBriefPrompt(lastVisits: const []);
    expect(p, isNot(contains('الحساسية:')));
    expect(p, contains('لا توجد زيارات سابقة'));
  });

  test(
    'instructions prompt keeps doses exactly as typed and forbids new drugs',
    () {
      final p = patientInstructionsPrompt(
        items: const [
          RxLine(
            drug: 'أموكسيسيلين',
            dosage: '500 ملغ',
            frequency: '3 مرات',
            duration: '7 أيام',
          ),
        ],
        age: 30,
      );
      expect(p, contains('أموكسيسيلين'));
      expect(p, contains('500 ملغ'));
      expect(p, contains('ولا تضف أدوية'));
    },
  );

  test(
    'referral prompt names the target but never asks for the patient name',
    () {
      final p = referralPrompt(
        target: 'جراحة العيون',
        doctorNote: 'ماء أبيض متقدم',
        lastVisits: visits,
      );
      expect(p, contains('جراحة العيون'));
      expect(p, contains('ماء أبيض متقدم'));
      expect(p, contains('ولا تذكر اسم المريض'));
    },
  );
}

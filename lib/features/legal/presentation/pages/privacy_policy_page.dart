import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../help/presentation/widgets/guide_pieces.dart';

/// A draft privacy policy written to match this app's actual behavior
/// (offline-first, no server, local SQLite only) rather than generic
/// boilerplate — but still a draft: see the disclaimer at the top. Whoever
/// sells this app should have it reviewed by a lawyer, especially for
/// compliance with whatever local health-data rules apply, before treating
/// it as binding. Fill in [_vendorName]/[_contactInfo] before publishing.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const _vendorName = 'عيادتي';
  static const _contactInfo = 'واتساب +963 984 668 063';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سياسة الخصوصية')),
      body: ResponsiveBody(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const GuideCallout(
              kind: GuideCalloutKind.warn,
              text:
                  'هذه مسودة أعدّها التطبيق تلقائيًا كنقطة انطلاق، وليست '
                  'استشارة قانونية. يجب مراجعتها من محامٍ مختص وتعديلها '
                  'حسب الأنظمة المحلية لحماية البيانات الصحية قبل اعتمادها '
                  'رسميًا.',
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'آخر تحديث: يُحدَّد عند الاعتماد الرسمي',
              style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
            ),
            const GuideHeading('١. مقدمة'),
            GuideParagraph(
              'توضّح هذه السياسة كيف يتعامل تطبيق "$_vendorName" مع '
              'البيانات التي تُدخلها العيادة (الطبيب/الطبيبة والطاقم '
              'المساعد) أثناء استخدام التطبيق، بما في ذلك بيانات المرضى.',
            ),
            const GuideHeading('٢. أين تُخزَّن البيانات'),
            const GuideParagraph(
              'التطبيق مصمَّم للعمل بلا إنترنت بالكامل. كل البيانات — '
              'سجلات المرضى، زيارات الفحص، الصور المرفقة، المواعيد، '
              'وحسابات المستخدمين — تُخزَّن محليًا فقط داخل قاعدة بيانات '
              'على الجهاز نفسه الذي يعمل عليه التطبيق. لا يحتاج التطبيق '
              'اتصالًا بالإنترنت لأداء وظائفه الأساسية.',
            ),
            const GuideHeading('٣. هل تصل البيانات إلى طرف ثالث؟'),
            GuideParagraph(
              'لا. لا يمتلك "$_vendorName" (الجهة المطوّرة للتطبيق) أي '
              'وصول إلى بيانات أي عيادة أو مريض، ولا تُرسَل أي بيانات '
              'تلقائيًا إلى أي خادم خارجي. الاستثناء الوحيد هو عندما '
              'تختار العيادة بنفسها تصدير بيانات (مثل طباعة إضبارة مريض '
              'كملف PDF) ومشاركتها يدويًا عبر تطبيق آخر على الجهاز — وهذا '
              'فعل واعٍ من المستخدم نفسه، لا سلوك تلقائي من التطبيق.',
            ),
            const GuideHeading('٤. من يملك البيانات ومن هو المسؤول عنها'),
            const GuideParagraph(
              'العيادة (الطبيب/الطبيبة صاحب/ة الحساب) هي المالكة الكاملة '
              'لكل البيانات التي تُدخلها، وهي الجهة المسؤولة قانونيًا أمام '
              'مرضاها عن كيفية جمع تلك البيانات والحفاظ عليها، بصفتها '
              'الجهة التي تتحكم فعليًا بجهاز التخزين. دور التطبيق هو '
              'توفير الأداة فقط.',
            ),
            const GuideHeading('٥. كيف تُحمى البيانات داخل التطبيق'),
            const GuideBullets([
              'كلمات مرور المستخدمين مُشفّرة بتقنية تجزئة قياسية (bcrypt) — لا تُحفظ كنص صريح في أي مكان.',
              'حساب مستقل لكل مستخدم (طبيب/ممرضة) بدل تسجيل دخول مشترك، مع سجل نشاط يوثّق من عدّل أو حذف ماذا ومتى.',
              'قفل اختياري برمز على مستوى الجهاز نفسه، منفصل عن حساب تسجيل الدخول.',
              'رمز استرداد لمرة واحدة عند إنشاء الحساب، لاستعادة كلمة المرور دون الحاجة لبريد إلكتروني متصل بالإنترنت.',
            ]),
            const GuideHeading('٦. النسخ الاحتياطي ومسؤولية العيادة'),
            const GuideParagraph(
              'يوفّر التطبيق نسخًا احتياطية يدوية مع تذكير دوري، لكن اتخاذ '
              'النسخة الاحتياطية فعليًا وحفظها بمكان آمن (قرص خارجي، جهاز '
              'آخر) هو مسؤولية العيادة نفسها. فقدان الجهاز أو تلفه دون '
              'نسخة احتياطية حديثة يعني فقدانًا فعليًا للبيانات — التطبيق '
              'لا يحتفظ بأي نسخة احتياطية خارج الجهاز ما لم تُنشئها '
              'العيادة بنفسها يدويًا.',
            ),
            const GuideHeading('٧. بيانات المرضى تحديدًا'),
            const GuideParagraph(
              'تشمل بيانات المرضى المدخلة: الاسم، معلومات التواصل، '
              'التاريخ الطبي، صور الفحص، وسجلات الزيارات والمواعيد. تُستخدم '
              'هذه البيانات حصريًا لغرض إدارة سجل المريض الطبي داخل '
              'العيادة، ولا تُستخدم لأي غرض تسويقي أو تحليلي أو تُشارك مع '
              'أي جهة خارجية من قِبل التطبيق نفسه.',
            ),
            const GuideHeading('٨. التغييرات على هذه السياسة'),
            const GuideParagraph(
              'قد تُحدَّث هذه السياسة مع تطوّر التطبيق. يُنصح بمراجعتها '
              'دوريًا، خصوصًا عند تحديث التطبيق لإصدار جديد.',
            ),
            const GuideHeading('٩. التواصل'),
            GuideParagraph('لأي استفسار بخصوص هذه السياسة: $_contactInfo'),
          ],
        ),
      ),
    );
  }
}

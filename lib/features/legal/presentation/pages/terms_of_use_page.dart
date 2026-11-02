import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../help/presentation/widgets/guide_pieces.dart';

/// A draft terms-of-use document matching how this app is actually sold
/// today (direct sale, no in-app activation/licensing mechanism yet — see
/// the product roadmap) rather than assuming infrastructure that doesn't
/// exist. Still a draft: see the disclaimer at the top. Fill in
/// [_vendorName]/[_contactInfo]/[_governingLaw] and have it reviewed by a
/// lawyer before treating it as binding.
class TermsOfUsePage extends StatelessWidget {
  const TermsOfUsePage({super.key});

  static const _vendorName = 'عيادتي';
  static const _contactInfo = 'واتساب +963 984 668 063';
  static const _governingLaw = '[يُحدَّد لاحقًا حسب بلد التشغيل]';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('شروط الاستخدام')),
      body: ResponsiveBody(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const GuideCallout(
              kind: GuideCalloutKind.warn,
              text:
                  'هذه مسودة أعدّها التطبيق تلقائيًا كنقطة انطلاق، وليست '
                  'استشارة قانونية. يجب مراجعتها من محامٍ مختص قبل '
                  'اعتمادها رسميًا كعقد ملزم.',
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'آخر تحديث: يُحدَّد عند الاعتماد الرسمي',
              style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
            ),
            const GuideHeading('١. القبول بالشروط'),
            GuideParagraph(
              'باستخدام تطبيق "$_vendorName"، توافق العيادة (الطبيب/ة '
              'وأي مستخدم آخر يُضاف لاحقًا) على هذه الشروط. من لا يوافق '
              'عليها يجب أن يتوقف عن استخدام التطبيق.',
            ),
            const GuideHeading('٢. وصف الخدمة'),
            const GuideParagraph(
              'التطبيق أداة محلية (بلا إنترنت) لإدارة سجلات المرضى '
              'وزيارات الفحص والمواعيد داخل عيادة واحدة أو أكثر لنفس '
              'المستخدم. لا يقدّم التطبيق حاليًا أي خدمة سحابية أو '
              'اشتراكًا دوريًا — كل البيانات محلية بالكامل (راجعي سياسة '
              'الخصوصية للتفاصيل).',
            ),
            const GuideHeading('٣. الترخيص'),
            const GuideParagraph(
              'يُمنح المستخدم ترخيصًا لاستخدام نسخة التطبيق التي حصل '
              'عليها ضمن عيادته الخاصة. لا يجوز إعادة بيع التطبيق أو '
              'توزيعه أو تفكيك شيفرته دون إذن كتابي مسبق من '
              '"$_vendorName".',
            ),
            const GuideHeading('٤. التطبيق ليس بديلًا عن الحكم الطبي المهني'),
            const GuideParagraph(
              'التطبيق أداة لتوثيق وتنظيم السجلات فقط — لا يقدّم تشخيصًا '
              'ولا توصية طبية، ولا يتحمّل "$_vendorName" أي مسؤولية عن '
              'قرارات طبية تُتَّخذ بالاعتماد على البيانات المُدخلة فيه. '
              'يبقى الحكم الطبي المهني بالكامل مسؤولية الطبيب/ة المعالج/ة.',
            ),
            const GuideHeading('٥. مسؤوليات المستخدم'),
            const GuideBullets([
              'دقة البيانات المُدخلة عن المرضى ومواعيدهم.',
              'الحفاظ على سرية كلمة المرور ورمز الاسترداد، وعدم مشاركتهما.',
              'أخذ نسخ احتياطية بشكل منتظم وحفظها في مكان آمن.',
              'التأكد من صلاحيات كل مستخدم (طبيب/ممرضة) تُمنح فقط لمن يحتاجها فعليًا.',
            ]),
            const GuideHeading('٦. حدود المسؤولية'),
            const GuideParagraph(
              'يُقدَّم التطبيق "كما هو" دون ضمانات صريحة بخلوّه التام من '
              'الأخطاء. لا يتحمّل "$_vendorName" مسؤولية فقدان البيانات '
              'الناتج عن فقدان الجهاز أو سرقته أو تلفه أو عدم أخذ نسخة '
              'احتياطية منتظمة من قِبل العيادة — راجعي قسم النسخ الاحتياطي '
              'في سياسة الخصوصية.',
            ),
            const GuideHeading('٧. الدعم والتحديثات'),
            const GuideParagraph(
              'يُقدَّم الدعم حاليًا بشكل مباشر (تواصل شخصي مع البائع)، '
              'والتحديثات تُوزَّع يدويًا إلى حين توفّر آلية تحديث تلقائية '
              'داخل التطبيق.',
            ),
            const GuideHeading('٨. الإنهاء'),
            const GuideParagraph(
              'يحق لأي من الطرفين إنهاء هذه العلاقة، مع بقاء بيانات '
              'العيادة (المخزَّنة محليًا على جهازها) ملكًا لها بالكامل — '
              'إنهاء العلاقة مع "$_vendorName" لا يؤثر على إمكانية '
              'الوصول لتلك البيانات المحلية.',
            ),
            const GuideHeading('٩. القانون الحاكم'),
            GuideParagraph('تخضع هذه الشروط لقوانين: $_governingLaw.'),
            const GuideHeading('١٠. التواصل'),
            GuideParagraph('لأي استفسار بخصوص هذه الشروط: $_contactInfo'),
          ],
        ),
      ),
    );
  }
}

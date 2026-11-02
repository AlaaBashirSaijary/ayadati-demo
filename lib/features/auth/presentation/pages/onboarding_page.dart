import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../legal/presentation/pages/privacy_policy_page.dart';
import '../../../legal/presentation/pages/terms_of_use_page.dart';
import '../../../visits/presentation/widgets/specialty_dropdown.dart';
import '../../../../main.dart' show ModeGate;
import '../../../lan_sync/presentation/pages/secretary_pairing_page.dart';
import '../providers/auth_provider.dart';
import 'login_page.dart';

/// First launch, no clinic/admin exists yet. On-device equivalent of running
/// database/seeders/ClinicSeeder.php once, except the clinic actually types
/// their own name/credentials instead of getting hardcoded demo ones.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _clinicController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  String? _specialtyId;

  @override
  void dispose() {
    _clinicController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authProvider.notifier)
        .completeOnboarding(
          clinicName: _clinicController.text.trim(),
          adminName: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          specialtyId: _specialtyId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('إعداد العيادة لأول مرة')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.formWidth(context, base: 460),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FadeSlideIn(
                      child: SvgPicture.asset(
                        'assets/images/Doctor-pana.svg',
                        height: Responsive.scale(context, 180),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FadeSlideIn(
                      child: const Text(
                        'هذا أول تشغيل للتطبيق — أنشئي حساب العيادة والمدير مرة واحدة.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.inkSoft,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _clinicController,
                      decoration: const InputDecoration(
                        labelText: 'اسم العيادة',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SpecialtyDropdown(
                      value: _specialtyId,
                      onChanged: (v) => setState(() => _specialtyId = v),
                      validator: (v) => v == null ? 'اختر اختصاصك' : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'اسمك'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'مطلوب';
                        if (!v.contains('@')) return 'بريد إلكتروني غير صحيح';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        labelText: 'كلمة المرور',
                      ),
                      validator: (v) => (v == null || v.length < 8)
                          ? '8 أحرف على الأقل'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _passwordConfirmController,
                      obscureText: true,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        labelText: 'تأكيد كلمة المرور',
                      ),
                      validator: (v) => v != _passwordController.text
                          ? 'كلمتا المرور غير متطابقتين'
                          : null,
                    ),
                    if (auth.error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        auth.error!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    FadeSlideIn(
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.sky.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            SvgPicture.asset(
                              'assets/images/Insurance-pana.svg',
                              height: 64,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            const Expanded(
                              child: Text(
                                'بياناتك تبقى محفوظة على هذا الجهاز فقط ولا '
                                'تُرسل لأي خادم خارجي — وستحصلين على رمز '
                                'استرداد بعد إنشاء الحساب لاستعادته إذا نسيتِ '
                                'كلمة المرور.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: Text.rich(
                          TextSpan(
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.inkSoft,
                              height: 1.6,
                            ),
                            children: [
                              const TextSpan(
                                text: 'بإنشاء الحساب أنتِ توافقين على ',
                              ),
                              TextSpan(
                                text: 'سياسة الخصوصية',
                                style: const TextStyle(
                                  color: AppColors.aqua,
                                  fontWeight: FontWeight.w700,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const PrivacyPolicyPage(),
                                    ),
                                  ),
                              ),
                              const TextSpan(text: ' و'),
                              TextSpan(
                                text: 'شروط الاستخدام',
                                style: const TextStyle(
                                  color: AppColors.aqua,
                                  fontWeight: FontWeight.w700,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const TermsOfUsePage(),
                                    ),
                                  ),
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    auth.isLoading
                        ? const Center(
                            child: SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            ),
                          )
                        : GradientButton(
                            label: 'إنشاء الحساب والدخول',
                            icon: Icons.check_rounded,
                            onPressed: _submit,
                          ),
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SecretaryPairingPage(
                              onPaired: (_) {
                                Navigator.of(
                                  context,
                                ).popUntil((r) => r.isFirst);
                                ModeGate.changed.value++;
                              },
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.devices_other_rounded, size: 16),
                        label: const Text(
                          'هذا جهاز سكرتيرة أو ممرضة؟ اربطه بجهاز الطبيب',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        ),
                        child: const Text(
                          'قمت بإعداد العيادة من قبل؟ تسجيل الدخول',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

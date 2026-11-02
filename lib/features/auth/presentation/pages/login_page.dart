import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../providers/auth_provider.dart';
import 'forgot_password_page.dart';

/// Mirrors resources/views/auth/login.blade.php.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authProvider.notifier)
        .signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    // As the root screen (AuthGate showing it directly, once a clinic
    // exists), there's nothing to go back to, so no app bar. Pushed from
    // OnboardingPage's "already set up a clinic before?" link, though,
    // canPop is true — show a back button so that detour isn't a dead end.
    final canGoBack = Navigator.canPop(context);

    return Scaffold(
      appBar: canGoBack
          ? AppBar(backgroundColor: Colors.transparent, elevation: 0)
          : null,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.85, -0.9),
            radius: 1.3,
            colors: [Color(0x331287A0), Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: Responsive.formWidth(context, base: 420),
                ),
                child: StaggeredFadeSlideIn(
                  spacing: AppSpacing.lg,
                  children: [
                    Center(
                      child: BrandMark(size: Responsive.scale(context, 56)),
                    ),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.sky.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'مرحباً بك',
                            style: TextStyle(
                              color: AppColors.aqua,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'تسجيل الدخول',
                            style: TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'ادخلي لفتح سجلات عيادتك فقط — بأمان ووضوح.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.inkSoft,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: AppShadows.card,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textDirection: TextDirection.ltr,
                              decoration: const InputDecoration(
                                labelText: 'البريد الإلكتروني',
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'مطلوب'
                                  : null,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              textDirection: TextDirection.ltr,
                              decoration: const InputDecoration(
                                labelText: 'كلمة المرور',
                              ),
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? 'مطلوب' : null,
                              onFieldSubmitted: (_) => _submit(),
                            ),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: TextButton(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const ForgotPasswordPage(),
                                  ),
                                ),
                                child: const Text(
                                  'نسيت كلمة المرور؟',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 200),
                              child: auth.error == null
                                  ? const SizedBox(width: double.infinity)
                                  : Padding(
                                      padding: const EdgeInsets.only(
                                        top: AppSpacing.md,
                                      ),
                                      child: Text(
                                        auth.error!,
                                        style: const TextStyle(
                                          color: AppColors.danger,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
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
                                    label: 'دخول إلى العيادة',
                                    icon: Icons.login_rounded,
                                    onPressed: _submit,
                                  ),
                          ],
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/gradient_button.dart';
import 'app_lock_provider.dart';

/// Recovers from a forgotten PIN by re-verifying identity with the
/// account's own email and password instead — the PIN lock itself has no
/// reset path of its own (a stranger who knew a hint could otherwise talk
/// their way past it), but a correct account password proves identity just
/// as strongly as the PIN was meant to. Success turns the lock off; the
/// clinic can set a fresh PIN afterward from Admin if they still want it.
class ForgotPinPage extends ConsumerStatefulWidget {
  const ForgotPinPage({super.key});

  @override
  ConsumerState<ForgotPinPage> createState() => _ForgotPinPageState();
}

class _ForgotPinPageState extends ConsumerState<ForgotPinPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final ok = await ref
        .read(authProvider.notifier)
        .signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );

    if (!mounted) return;

    if (!ok) {
      setState(() {
        _submitting = false;
        _error = ref.read(authProvider).error ?? 'تعذّر التحقق من الحساب.';
      });
      return;
    }

    await ref.read(appLockProvider.notifier).disableWithoutPin();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
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
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.sky.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_reset_rounded,
                          color: AppColors.aqua,
                          size: 28,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'نسيت رمز القفل',
                          style: TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'سجّلي الدخول بالبريد وكلمة المرور المستخدمة '
                          'لحسابك، وسيتم إيقاف قفل الرمز تلقائيًا — '
                          'يمكن تفعيله مجددًا برمز جديد من صفحة الإدارة.',
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
                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            child: _error == null
                                ? const SizedBox(width: double.infinity)
                                : Padding(
                                    padding: const EdgeInsets.only(
                                      top: AppSpacing.md,
                                    ),
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _submitting
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
                                  label: 'التحقق وإيقاف القفل',
                                  icon: Icons.lock_open_rounded,
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
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../providers/auth_provider.dart';

/// Offline stand-in for a "forgot password" email link: since the app never
/// touches the internet, there's no address to send a reset link to — the
/// recovery code issued at account creation (see RecoveryCodePage) is what
/// proves it's really the account owner asking.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _saving = false;
  String? _error;
  bool _done = false;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final error = await ref
        .read(authProvider.notifier)
        .resetPasswordWithRecoveryCode(
          email: _emailController.text,
          recoveryCode: _codeController.text,
          newPassword: _passwordController.text,
        );

    if (!mounted) return;

    setState(() {
      _saving = false;
      _error = error;
      _done = error == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('نسيت كلمة المرور')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.formWidth(context, base: 420),
              ),
              child: _done ? _SuccessCard() : _buildForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Container(
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
            const Text(
              'أدخلي بريد الحساب ورمز الاسترداد الذي حصلتِ عليه عند إنشاء '
              'الحساب لتعيين كلمة مرور جديدة. إن كنتِ ممرضة، يمكن لمدير '
              'العيادة إعادة تعيين كلمة مرورك من صفحة الإدارة بدلًا من ذلك.',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _codeController,
              textDirection: TextDirection.ltr,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'رمز الاسترداد',
                hintText: 'XXXX-XXXX-XXXX',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'كلمة مرور جديدة'),
              validator: (v) =>
                  (v == null || v.length < 8) ? '8 أحرف على الأقل' : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _error == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.md),
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
            _saving
                ? const Center(
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                : GradientButton(
                    label: 'إعادة تعيين كلمة المرور',
                    icon: Icons.lock_reset_rounded,
                    onPressed: _submit,
                  ),
          ],
        ),
      ),
    );
  }
}

class _SuccessCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.ok.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.ok,
              size: 32,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'تم تعيين كلمة المرور الجديدة',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'يمكنك الآن تسجيل الدخول بكلمة المرور الجديدة.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.lg),
          GradientButton(
            label: 'العودة لتسجيل الدخول',
            icon: Icons.login_rounded,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

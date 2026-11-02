import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../providers/auth_provider.dart';
import '../../../../core/widgets/app_snack.dart';

/// Shown exactly once, right after onboarding creates the admin account —
/// the app is fully offline, so this code (not an email link) is the only
/// way back in if the password is ever forgotten. Requires an explicit
/// "دون الرمز" confirmation before continuing, so it isn't easy to swipe
/// past without noticing.
class RecoveryCodePage extends ConsumerStatefulWidget {
  const RecoveryCodePage({super.key, required this.code});

  final String code;

  @override
  ConsumerState<RecoveryCodePage> createState() => _RecoveryCodePageState();
}

class _RecoveryCodePageState extends ConsumerState<RecoveryCodePage> {
  bool _confirmed = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    AppSnack.success(context, 'تم نسخ الرمز.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.formWidth(context, base: 440),
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
                      children: [
                        Icon(
                          Icons.vpn_key_rounded,
                          color: AppColors.aqua,
                          size: 28,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'رمز استرداد الحساب',
                          style: TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'التطبيق يعمل بدون اتصال بالإنترنت، لذلك لا يمكن '
                          'إرسال رابط لإعادة تعيين كلمة المرور عبر البريد. '
                          'احفظي هذا الرمز في مكان آمن — هو الطريقة الوحيدة '
                          'لاستعادة الحساب إذا نسيتِ كلمة المرور.',
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
                    child: Column(
                      children: [
                        Text(
                          widget.code,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 24,
                            letterSpacing: 2,
                            color: AppColors.aquaDeep,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton.icon(
                          onPressed: _copy,
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('نسخ الرمز'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        CheckboxListTile(
                          value: _confirmed,
                          onChanged: (v) =>
                              setState(() => _confirmed = v ?? false),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'دوّنتُ هذا الرمز في مكان آمن',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        GradientButton(
                          label: 'متابعة',
                          icon: Icons.arrow_forward_rounded,
                          onPressed: _confirmed
                              ? () => ref
                                    .read(authProvider.notifier)
                                    .acknowledgeRecoveryCode()
                              : null,
                        ),
                      ],
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

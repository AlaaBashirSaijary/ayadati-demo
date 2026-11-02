import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../widgets/brand_mark.dart';
import 'marketing_build.dart';
import 'trial_service.dart';
import '../../core/widgets/app_snack.dart';

const _supportWhatsAppNumber = '963984668063';

/// Shown instead of the whole app once the 14-day trial has run out and the
/// device hasn't been activated — the device code here is what the vendor
/// needs to hand back a matching activation code (see TrialService), so the
/// two things a doctor can do from this screen are get that code to the
/// vendor and type back what they receive.
class TrialGatePage extends StatefulWidget {
  const TrialGatePage({super.key, required this.onActivated});

  final VoidCallback onActivated;

  @override
  State<TrialGatePage> createState() => _TrialGatePageState();
}

class _TrialGatePageState extends State<TrialGatePage> {
  final _codeController = TextEditingController();
  String? _deviceCode;
  String? _error;
  bool _activating = false;

  @override
  void initState() {
    super.initState();
    TrialService.instance.deviceCode().then((code) {
      if (mounted) setState(() => _deviceCode = code);
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    setState(() {
      _activating = true;
      _error = null;
    });
    final ok = await TrialService.instance.activate(_codeController.text);
    if (!mounted) return;
    setState(() => _activating = false);
    if (ok) {
      widget.onActivated();
    } else {
      setState(() => _error = 'رمز التفعيل غير صحيح.');
    }
  }

  Future<void> _contactSupport() async {
    final code = _deviceCode ?? '';
    final message = Uri.encodeComponent(
      'مرحبًا، انتهت فترة تجربة تطبيق عيادتي عندي وأريد التفعيل.\n'
      'رمز جهازي: $code',
    );
    final uri = Uri.parse(
      'https://wa.me/$_supportWhatsAppNumber?text=$message',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      AppSnack.error(context, 'تعذّر فتح واتساب.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mist,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandMark(size: 56),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    MarketingBuild.enabled
                        ? 'انتهت صلاحية نسخة العرض'
                        : 'انتهت الفترة التجريبية',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    MarketingBuild.enabled
                        ? 'هذه نسخة عرض انتهت مدتها. للحصول على نسخة محدّثة '
                              'تواصل مع مطوّرة التطبيق.'
                        : 'جرّبتِ عيادتي لمدة ١٤ يومًا كاملة. للاستمرار، تواصلي '
                              'معنا لإتمام الشراء وتفعيل هذا الجهاز.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: AppShadows.card,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'رمز جهازك',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _deviceCode ?? '...',
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.aquaDeep,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'نسخ',
                              icon: const Icon(Icons.copy_rounded, size: 20),
                              onPressed: _deviceCode == null
                                  ? null
                                  : () {
                                      Clipboard.setData(
                                        ClipboardData(text: _deviceCode!),
                                      );
                                      AppSnack.success(
                                        context,
                                        'تم نسخ رمز الجهاز.',
                                      );
                                    },
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton.icon(
                          onPressed: _deviceCode == null
                              ? null
                              : _contactSupport,
                          icon: const Icon(Icons.chat_rounded, size: 18),
                          label: const Text('تواصل عبر واتساب لإتمام الشراء'),
                        ),
                      ],
                    ),
                  ),
                  if (!MarketingBuild.enabled) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: AppShadows.card,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'عندك رمز تفعيل؟',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkSoft,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _codeController,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.center,
                            textCapitalization: TextCapitalization.characters,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'XXXXX-XXXXX',
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: AppColors.danger,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
                          OutlinedButton(
                            onPressed: _activating ? null : _activate,
                            child: _activating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('تفعيل'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

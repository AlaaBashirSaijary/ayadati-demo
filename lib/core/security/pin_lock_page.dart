import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../widgets/brand_mark.dart';
import 'app_lock_provider.dart';
import 'forgot_pin_page.dart';

const _pinLength = 4;

/// Shown whenever the app is locked (see AppLockNotifier) — a plain PIN pad
/// with a "forgot PIN" escape hatch (see ForgotPinPage) that re-verifies
/// identity through the account's own email/password instead of the PIN.
class PinLockPage extends ConsumerStatefulWidget {
  const PinLockPage({super.key});

  @override
  ConsumerState<PinLockPage> createState() => _PinLockPageState();
}

class _PinLockPageState extends ConsumerState<PinLockPage> {
  String _entered = '';
  String? _error;
  bool _checking = false;

  Future<void> _onDigit(String digit) async {
    if (_checking || _entered.length >= _pinLength) return;
    setState(() {
      _entered += digit;
      _error = null;
    });

    if (_entered.length == _pinLength) {
      setState(() => _checking = true);
      final ok = await ref.read(appLockProvider.notifier).unlock(_entered);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _error = 'رمز غير صحيح';
          _entered = '';
          _checking = false;
        });
      }
      // On success the provider flips isLocked to false and AppLockGate
      // swaps this page out — nothing else to do here.
    }
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mist,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.formWidth(context, base: 360),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BrandMark(size: Responsive.scale(context, 64)),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'أدخلي رمز القفل',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _pinLength; i++)
                      Container(
                        width: 16,
                        height: 16,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < _entered.length
                              ? AppColors.aqua
                              : Colors.transparent,
                          border: Border.all(
                            color: _error != null
                                ? AppColors.danger
                                : AppColors.aqua,
                            width: 1.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 20,
                  child: Text(
                    _error ?? '',
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _NumberPad(
                  onDigit: _onDigit,
                  onBackspace: _onBackspace,
                  enabled: !_checking,
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ForgotPinPage()),
                  ),
                  child: const Text(
                    'نسيت الرمز؟',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NumberPad extends StatelessWidget {
  const _NumberPad({
    required this.onDigit,
    required this.onBackspace,
    required this.enabled,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in _rows)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final digit in row)
                  _PadButton(
                    label: digit,
                    onTap: enabled ? () => onDigit(digit) : null,
                  ),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 72),
            _PadButton(label: '0', onTap: enabled ? () => onDigit('0') : null),
            SizedBox(
              width: 72,
              height: 72,
              child: IconButton(
                onPressed: enabled ? onBackspace : null,
                icon: const Icon(Icons.backspace_outlined),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PadButton extends StatelessWidget {
  const _PadButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 64,
            height: 64,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

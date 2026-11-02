import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../theme/app_theme.dart';
import 'app_snack.dart';

/// A microphone button for a text field: tap, speak Arabic, and the words are
/// appended to the field as they're recognised; tap again to stop. Speech
/// recognition is done by the phone/tablet's own engine, so it can need an
/// internet connection (and the Arabic language pack) depending on the
/// device — when it isn't available the button says so instead of failing
/// silently, and typing keeps working as before.
class DictationButton extends StatefulWidget {
  const DictationButton({super.key, required this.controller});

  final TextEditingController controller;

  @override
  State<DictationButton> createState() => _DictationButtonState();
}

class _DictationButtonState extends State<DictationButton> {
  static final SpeechToText _speech = SpeechToText();
  static bool _initialized = false;
  static bool _available = false;
  static String? _localeId;

  bool _listening = false;

  /// Text already in the field when listening started, so the partial
  /// results replace only what was spoken, never what was typed.
  String _base = '';

  Future<bool> _ensureReady() async {
    if (_initialized) return _available;
    _initialized = true;
    try {
      _available = await _speech.initialize(
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _listening = false);
          }
        },
      );
      if (_available) {
        final locales = await _speech.locales();
        // Prefer Syrian, then any Arabic variant the device offers.
        final arabic = locales.where((l) => l.localeId.startsWith('ar'));
        _localeId =
            (arabic.where((l) => l.localeId.startsWith('ar_SY')).firstOrNull ??
                    arabic.firstOrNull)
                ?.localeId;
      }
    } catch (_) {
      _available = false;
    }
    return _available;
  }

  Future<void> _toggle() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (!await _ensureReady()) {
      if (mounted) {
        AppSnack.info(
          context,
          'الإملاء الصوتي غير متاح على هذا الجهاز أو لم تُمنح صلاحية الميكروفون.',
        );
      }
      return;
    }
    if (_localeId == null && mounted) {
      AppSnack.info(
        context,
        'لغة عربية غير مثبتة للتعرف على الكلام — ثبّتها من إعدادات الجهاز.',
      );
      return;
    }
    _base = widget.controller.text;
    setState(() => _listening = true);
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: _localeId,
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
      onResult: (result) {
        final spoken = result.recognizedWords;
        final joined = _base.trim().isEmpty
            ? spoken
            : '${_base.trimRight()} $spoken';
        widget.controller.value = TextEditingValue(
          text: joined,
          selection: TextSelection.collapsed(offset: joined.length),
        );
      },
    );
  }

  @override
  void dispose() {
    if (_listening) _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _listening ? 'إيقاف الإملاء' : 'إملاء صوتي',
      onPressed: _toggle,
      icon: Icon(
        _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
        color: _listening ? AppColors.danger : AppColors.aqua,
      ),
    );
  }
}

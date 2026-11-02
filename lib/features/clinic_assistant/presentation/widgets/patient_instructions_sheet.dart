import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/whatsapp/whatsapp_service.dart';
import '../../../../core/widgets/app_snack.dart';

/// Shows the AI-written patient instructions in an editable box, with copy
/// and "send on WhatsApp" (straight to the patient when their number is known,
/// otherwise the doctor picks the chat). Nothing is sent until the doctor
/// presses send in WhatsApp itself.
Future<void> showPatientInstructionsSheet(
  BuildContext context, {
  required String text,
  String? phone,
}) {
  final controller = TextEditingController(text: text);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'تعليمات للمريض',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'مسودة من الذكاء الاصطناعي — راجعها وعدّلها قبل الإرسال.',
            style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
          ),
          const SizedBox(height: AppSpacing.md),
          Flexible(
            child: TextField(
              controller: controller,
              maxLines: null,
              minLines: 8,
              decoration: const InputDecoration(alignLabelWithHint: true),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    final message = controller.text.trim();
                    final opened =
                        (phone != null &&
                            WhatsAppService.normalize(phone) != null)
                        ? await WhatsAppService.open(phone, message)
                        : await WhatsAppService.openUri(
                            Uri.parse(
                              'https://wa.me/?text=${Uri.encodeComponent(message)}',
                            ),
                          );
                    if (!opened && sheetContext.mounted) {
                      AppSnack.error(sheetContext, 'تعذّر فتح واتساب.');
                    }
                  },
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: const Text('إرسال عبر واتساب'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: controller.text));
                  if (sheetContext.mounted) {
                    AppSnack.success(sheetContext, 'تم النسخ.');
                  }
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('نسخ'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

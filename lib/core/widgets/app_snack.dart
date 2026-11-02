import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum _SnackKind { error, success, info }

/// One consistent look for every transient message: a floating card with a
/// colored icon badge and readable text, instead of the stock dark bar with
/// raw text. Use [AppSnack.error] for failures (the message should already
/// be a friendly sentence — see friendlyMessage), [AppSnack.success] for
/// confirmations, [AppSnack.info] for neutral notes.
class AppSnack {
  const AppSnack._();

  static void error(BuildContext context, String message) =>
      _show(context, message, _SnackKind.error);

  static void success(BuildContext context, String message) =>
      _show(context, message, _SnackKind.success);

  static void info(BuildContext context, String message) =>
      _show(context, message, _SnackKind.info);

  static void _show(BuildContext context, String message, _SnackKind kind) {
    final (icon, color) = switch (kind) {
      _SnackKind.error => (Icons.error_outline_rounded, AppColors.danger),
      _SnackKind.success => (Icons.check_circle_outline_rounded, AppColors.ok),
      _SnackKind.info => (Icons.info_outline_rounded, AppColors.aqua),
    };

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: Colors.white,
          elevation: 6,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: EdgeInsets.zero,
          duration: Duration(seconds: kind == _SnackKind.error ? 6 : 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.field),
            side: BorderSide(color: color.withValues(alpha: 0.25)),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: messenger.hideCurrentSnackBar,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.inkSoft,
                      ),
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

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'pressable_scale.dart';

/// Gradient pill button — the Flutter analogue of .btn-accent /
/// .action-tile-new in app.css. Used for the primary "add" actions instead
/// of a flat Material button, so the app has a real focal point per screen.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.gradient = AppColors.focusGradient,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          // A full stadium/pill shape — distinctly reads as a tappable
          // button instead of a flat colored bar, at any width.
          borderRadius: BorderRadius.circular(28),
          boxShadow: AppShadows.raised,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                // mainAxisSize.min alone only sizes the Row to its content —
                // it does NOT center that content when something upstream
                // (e.g. a stretch-aligned Column) still forces this button
                // to full width, which left the icon+label stuck to one
                // side instead of centered on wide buttons.
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
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

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Small, reusable building blocks the help guide's sections are written
/// with — a numbered step list, a tinted callout box, a bullet list, and a
/// simple two-column spec table — so every section reads consistently
/// instead of each one hand-rolling its own layout.
class GuideHeading extends StatelessWidget {
  const GuideHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13.5,
          color: AppColors.aquaDeep,
        ),
      ),
    );
  }
}

class GuideParagraph extends StatelessWidget {
  const GuideParagraph(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.inkSoft,
          height: 1.6,
        ),
      ),
    );
  }
}

class GuideSteps extends StatelessWidget {
  const GuideSteps(this.steps, {super.key});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, step) in steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(left: 8, top: 1),
                    decoration: BoxDecoration(
                      color: AppColors.sky,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.aquaDeep,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      step,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.inkSoft,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class GuideBullets extends StatelessWidget {
  const GuideBullets(this.items, {super.key});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6, left: 8),
                    child: Icon(Icons.circle, size: 5, color: AppColors.aqua),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.inkSoft,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

enum GuideCalloutKind { tip, warn, ok }

class GuideCallout extends StatelessWidget {
  const GuideCallout({
    super.key,
    required this.text,
    this.kind = GuideCalloutKind.tip,
  });

  final String text;
  final GuideCalloutKind kind;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (kind) {
      GuideCalloutKind.tip => (AppColors.aqua, Icons.lightbulb_outline_rounded),
      GuideCalloutKind.warn => (AppColors.danger, Icons.warning_amber_rounded),
      GuideCalloutKind.ok => (AppColors.ok, Icons.check_circle_outline_rounded),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.inkSoft,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A label/value spec row — used for the payment-tier and roles tables.
class GuideSpecTable extends StatelessWidget {
  const GuideSpecTable(this.rows, {super.key});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (final (index, row) in rows.indexed) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      row.$1,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppColors.aquaDeep,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.$2,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (index != rows.length - 1)
              const Divider(
                height: 1,
                indent: AppSpacing.md,
                endIndent: AppSpacing.md,
              ),
          ],
        ],
      ),
    );
  }
}

/// A wrap of short field-name chips — used for "which fields does this form
/// have" lists (e.g. the new-patient form).
class GuideFieldChips extends StatelessWidget {
  const GuideFieldChips(this.fields, {super.key});

  final List<String> fields;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final field in fields)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.sky.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                field,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.aquaDeep,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

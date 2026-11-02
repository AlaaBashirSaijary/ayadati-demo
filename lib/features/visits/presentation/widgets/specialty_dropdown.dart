import 'package:flutter/material.dart';

import '../../domain/entities/specialty_preset.dart';

/// "الاختصاص" picker shared by first-run setup and "add clinic". The choice
/// decides which exam form the clinic starts with.
class SpecialtyDropdown extends StatelessWidget {
  const SpecialtyDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.validator,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'الاختصاص',
        helperText:
            'نجهّز لك نموذج الفحص المناسب تلقائيًا ويمكنك تعديله لاحقًا',
      ),
      items: [
        for (final p in specialtyPresets)
          DropdownMenuItem(value: p.id, child: Text(p.name)),
      ],
      onChanged: onChanged,
      validator: validator,
    );
  }
}

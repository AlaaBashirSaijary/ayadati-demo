import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/appointment.dart';

/// Icon + color for an [AppointmentType] — shared by every place the app
/// shows a type badge (the day list, the booking form, the monthly report)
/// so the three payment tiers read consistently everywhere instead of each
/// screen re-deriving its own two-way (paid/free) styling that can't
/// represent the half-price middle tier.
extension AppointmentTypeStyle on AppointmentType {
  IconData get icon => switch (this) {
    AppointmentType.consultation => Icons.payments_rounded,
    // A half-filled circle reads as "half" on sight — a percent sign reads
    // as a discount/rate, which isn't what a half-price visit type means.
    AppointmentType.halfConsultation => Icons.incomplete_circle_rounded,
    AppointmentType.followUp => Icons.volunteer_activism_rounded,
  };

  Color get color => switch (this) {
    AppointmentType.consultation => AppColors.danger,
    AppointmentType.halfConsultation => AppColors.focus,
    AppointmentType.followUp => AppColors.ok,
  };
}

import 'package:flutter/material.dart';

/// Color/spacing tokens ported 1:1 from resources/css/app.css (--color-eye-*)
/// so the Flutter app reads as the same product, not a different one.
class AppColors {
  const AppColors._();

  static const ink = Color(0xFF0A2540);
  static const inkSoft = Color(0xFF3D5A73);
  static const sky = Color(0xFFE7F3F8);
  static const mist = Color(0xFFF4FAFC);
  static const aqua = Color(0xFF1287A0);
  static const aquaDeep = Color(0xFF0B6073);
  static const focus = Color(0xFF1F6FB2);
  static const focusDeep = Color(0xFF155A96);
  static const lens = Color(0xFF7EC8D8);
  static const danger = Color(0xFFB42318);
  static const ok = Color(0xFF0F766E);

  /// Same gradient as .btn-accent / .action-tile-new in app.css.
  static const focusGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [focus, focusDeep],
  );

  /// Same gradient as .action-tile-search in app.css.
  static const aquaGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [aqua, aquaDeep],
  );

  /// Same gradient as .diagnosis-hero in app.css.
  static const diagnosisGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFFDFF4F8), Colors.white, Color(0xFFE8F1FB)],
  );
}

/// Soft, layered shadows matching the web app's card elevation style
/// (box-shadow: 0 20px 50px -36px rgba(10,37,64,.55)) instead of Material's
/// flat default elevation.
class AppShadows {
  const AppShadows._();

  static List<BoxShadow> card = [
    BoxShadow(
      color: AppColors.ink.withValues(alpha: 0.10),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> raised = [
    BoxShadow(
      color: AppColors.ink.withValues(alpha: 0.16),
      blurRadius: 28,
      offset: const Offset(0, 14),
    ),
  ];
}

/// Corner radii used across surfaces so cards, fields and chips share one
/// visual rhythm.
class AppRadius {
  const AppRadius._();

  static const card = 20.0;
  static const field = 14.0;
  static const chip = 999.0;
}

class AppTheme {
  const AppTheme._();

  static const _fontFamily = 'IBMPlexSansArabic';

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.aqua,
        primary: AppColors.aqua,
        surface: AppColors.mist,
      ),
      scaffoldBackgroundColor: AppColors.mist,
      fontFamily: _fontFamily,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: _SlideFadePageTransitionsBuilder(),
          TargetPlatform.android: _SlideFadePageTransitionsBuilder(),
        },
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: _fontFamily),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFamily: _fontFamily,
        ),
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white,
        selectedColor: AppColors.aqua,
        // Explicit colors on both styles: ChoiceChip's Material3 default
        // otherwise resolves the unselected label color from the seeded
        // color scheme, which came out unreadable (near-white on white)
        // against this app's very light custom surface color.
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: AppColors.ink,
        ),
        secondaryLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: Colors.white,
        ),
        checkmarkColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          side: BorderSide(color: AppColors.ink.withValues(alpha: 0.08)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.9),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.ink.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.ink.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.aqua, width: 2),
        ),
        labelStyle: const TextStyle(
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
              backgroundColor: AppColors.aqua,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ).copyWith(
              overlayColor: WidgetStateProperty.all(
                Colors.white.withValues(alpha: 0.12),
              ),
              elevation: const WidgetStatePropertyAll(0),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: BorderSide(color: AppColors.ink.withValues(alpha: 0.1)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 0,
        highlightElevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.aqua,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.field),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.aquaDeep,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.ink.withValues(alpha: 0.08),
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.ink,
          fontSize: 17,
          fontWeight: FontWeight.w800,
          fontFamily: _fontFamily,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(
          color: AppColors.ink.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
    );
  }
}

/// Slide-up + fade page transition used app-wide, replacing the default
/// platform transition — the Flutter analogue of app.css's `.page-enter`
/// (rise-in) animation on every Blade view.
class _SlideFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const _SlideFadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// Small reusable spacing scale — keeps every screen consistent instead of
/// hand-picked paddings sprinkled everywhere.
class AppSpacing {
  const AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
}

/// The auth-flow pages (onboarding, login, forgot password, recovery code,
/// PIN lock) center a single form column sized for a phone. Left as-is on
/// an iPad, that column sits as a narrow, sparse island in the middle of a
/// much bigger screen — everything reads as too small even though the text
/// itself hasn't shrunk. This widens (and modestly enlarges) that column on
/// tablets, using the same width breakpoint AppShell already switches its
/// sidebar on, so "wide" means the same thing everywhere in the app.
class Responsive {
  const Responsive._();

  static const wideBreakpoint = 700.0;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wideBreakpoint;

  /// A centered form/card column's max width — [base] is the phone-width
  /// value the screen used before this existed.
  static double formWidth(BuildContext context, {required double base}) =>
      isWide(context) ? base * 1.55 : base;

  /// Scales a single size (an icon, an illustration, a headline) up
  /// modestly on tablets — mild on purpose, so it reads as "comfortable
  /// tablet layout" rather than "the phone screen got zoomed in".
  static double scale(
    BuildContext context,
    double base, {
    double factor = 1.25,
  }) => isWide(context) ? base * factor : base;
}

/// Centers a single-column page (settings-style sections, a form) and caps
/// its width on tablets. Without this, a page built as one full-width
/// `ListView` of cards/buttons — fine on a phone — stretches edge-to-edge
/// across a full iPad screen instead: buttons balloon into long bars, and
/// any `Row` with an `Expanded` in the middle (a name next to a status
/// badge, say) ends up with its trailing element stranded far off at the
/// opposite edge with a huge gap in between, since "the rest of the space"
/// is suddenly enormous. Capping the column's width keeps that space
/// reasonable, the same way a browser doesn't let a paragraph run the full
/// width of an ultrawide monitor.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({super.key, required this.child, this.maxWidth = 720});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (!Responsive.isWide(context)) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

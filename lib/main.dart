import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/di/injection.dart';
import 'core/security/app_lock_provider.dart';
import 'core/security/pin_lock_page.dart';
import 'core/theme/app_theme.dart';
import 'core/trial/marketing_build.dart';
import 'core/trial/trial_gate_page.dart';
import 'core/trial/trial_service.dart';
import 'core/widgets/app_shell.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/onboarding_page.dart';
import 'features/auth/presentation/pages/recovery_code_page.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/lan_sync/data/lan_sync_client.dart';
import 'features/lan_sync/presentation/pages/secretary_home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');
  setupDependencyInjection();
  runApp(const ProviderScope(child: ClinicManagerApp()));
}

class ClinicManagerApp extends StatelessWidget {
  const ClinicManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'عيادتي',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // The whole app reads right-to-left, same as dir="rtl" on the Laravel
      // layout's <html> tag.
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        // Every screen was sized for a phone; left alone on an iPad, text
        // and fields stayed phone-sized inside a much bigger canvas and
        // read as too small. A mild uniform bump on wide screens (the same
        // breakpoint AppShell's sidebar uses) makes text throughout the
        // app — not just the auth flow's own widened layouts — noticeably
        // more comfortable without looking "zoomed in".
        child: Builder(
          builder: (context) {
            final mediaQuery = MediaQuery.of(context);
            final app = _withDemoRibbon(child!);
            if (!Responsive.isWide(context)) return app;
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(
                  mediaQuery.textScaler.scale(1) * 1.15,
                ),
              ),
              child: app,
            );
          },
        ),
      ),
      home: const ModeGate(),
    );
  }

  /// Marketing builds carry a permanent ribbon (with the marketer's name) so a
  /// screenshot or a leaked copy shows what it is and who it was given to.
  Widget _withDemoRibbon(Widget child) {
    if (!MarketingBuild.enabled) return child;
    return Banner(
      message: MarketingBuild.ribbonText,
      location: BannerLocation.bottomStart,
      color: const Color(0xCCB3261E),
      child: child,
    );
  }
}

/// Decides whether this tablet is the doctor's (the normal app) or a
/// secretary's/nurse's that has been paired with the doctor's device, which
/// only shows the small reception app. A paired tablet needs no activation of
/// its own: the doctor's device is the licensed one and decides what it may do.
class ModeGate extends StatefulWidget {
  const ModeGate({super.key});

  /// Bumped after pairing or unpairing so the gate re-reads the saved link.
  static final ValueNotifier<int> changed = ValueNotifier(0);

  @override
  State<ModeGate> createState() => _ModeGateState();
}

class _ModeGateState extends State<ModeGate> {
  SyncConnection? _connection;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    ModeGate.changed.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    ModeGate.changed.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final c = await SyncConnection.load();
    if (mounted) {
      setState(() {
        _connection = c;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Scaffold(body: SizedBox.shrink());
    final c = _connection;
    if (c != null) {
      return SecretaryHomePage(
        connection: c,
        onDisconnect: () => ModeGate.changed.value++,
      );
    }
    return const TrialGate();
  }
}

/// The very first gate the app hits, before even the PIN lock — a device
/// past its 14-day trial with no activation code entered never reaches
/// anything else, onboarding included, until it does. See TrialService for
/// how the trial clock and the activation code are computed, both fully
/// offline.
class TrialGate extends StatefulWidget {
  const TrialGate({super.key});

  @override
  State<TrialGate> createState() => _TrialGateState();
}

class _TrialGateState extends State<TrialGate> {
  bool? _expired;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final expired = await TrialService.instance.isTrialExpired();
    if (mounted) setState(() => _expired = expired);
  }

  @override
  Widget build(BuildContext context) {
    if (_expired == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    if (_expired!) {
      return TrialGatePage(onActivated: () => setState(() => _expired = false));
    }
    return const AppLockGate();
  }
}

/// Sits in front of everything else and re-arms the PIN lock (if the clinic
/// turned it on — off by default) whenever the app leaves the foreground,
/// the same way a banking app relocks itself instead of trusting whoever
/// picks the iPad back up.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key});

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      ref.read(appLockProvider.notifier).lockIfEnabled();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(appLockProvider);
    // Wait for the stored lock setting to load before deciding — otherwise
    // a clinic with the lock enabled would see a one-frame flash of
    // whatever's behind it (login, dashboard...) while that read is in
    // flight.
    if (lock.isLoading) {
      return const Scaffold(body: SizedBox.shrink());
    }
    if (lock.enabled && lock.isLocked) return const PinLockPage();
    return const AuthGate();
  }
}

/// Root traffic controller — the Flutter analogue of the `auth`/`clinic`
/// route middleware group in routes/web.php: decides between onboarding,
/// login, and the dashboard based on session state.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    if (auth.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (auth.needsOnboarding) return const OnboardingPage();
    if (auth.pendingRecoveryCode != null) {
      return RecoveryCodePage(code: auth.pendingRecoveryCode!);
    }
    if (!auth.isSignedIn) return const LoginPage();
    return const AppShell();
  }
}

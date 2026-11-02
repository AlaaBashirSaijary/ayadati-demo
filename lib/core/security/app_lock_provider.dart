import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/injection.dart';
import 'app_lock_service.dart';

class AppLockState {
  const AppLockState({
    this.enabled = false,
    this.isLocked = false,
    this.isLoading = true,
  });

  /// Whether a PIN has been set — the lock is entirely opt-in.
  final bool enabled;

  /// Whether the lock screen is currently blocking the app. Only
  /// meaningful when [enabled] is true.
  final bool isLocked;

  final bool isLoading;

  AppLockState copyWith({bool? enabled, bool? isLocked, bool? isLoading}) {
    return AppLockState(
      enabled: enabled ?? this.enabled,
      isLocked: isLocked ?? this.isLocked,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Gates app entry behind an optional PIN — off by default, so it never
/// gets in the way unless the clinic explicitly turns it on from Admin.
class AppLockNotifier extends Notifier<AppLockState> {
  late final AppLockService _service;

  @override
  AppLockState build() {
    _service = sl<AppLockService>();
    Future.microtask(_restore);
    return const AppLockState();
  }

  Future<void> _restore() async {
    final enabled = await _service.isEnabled();
    state = AppLockState(enabled: enabled, isLocked: enabled, isLoading: false);
  }

  /// Called whenever the app leaves the foreground — re-arms the lock so
  /// it's the first thing shown on return, same as a banking app.
  void lockIfEnabled() {
    if (state.enabled) state = state.copyWith(isLocked: true);
  }

  Future<bool> unlock(String pin) async {
    final ok = await _service.verify(pin);
    if (ok) state = state.copyWith(isLocked: false);
    return ok;
  }

  /// Turns the lock on with a fresh PIN — takes effect immediately without
  /// re-locking, since the clinic is already inside the app when setting it.
  Future<void> enable(String pin) async {
    await _service.setPin(pin);
    state = state.copyWith(enabled: true, isLocked: false);
  }

  /// Requires the current PIN so a passerby can't just flip the switch off.
  Future<bool> disable(String currentPin) async {
    final ok = await _service.verify(currentPin);
    if (!ok) return false;
    await _service.disable();
    state = state.copyWith(enabled: false, isLocked: false);
    return true;
  }

  Future<bool> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    final ok = await _service.verify(currentPin);
    if (!ok) return false;
    await _service.setPin(newPin);
    return true;
  }

  /// Turns the lock off without checking the (forgotten) PIN — the caller
  /// must have already verified identity another way first (see
  /// ForgotPinPage, which re-authenticates with the account's own email and
  /// password instead). The clinic can set a fresh PIN afterward from
  /// Admin if they still want the lock on.
  Future<void> disableWithoutPin() async {
    await _service.disable();
    state = state.copyWith(enabled: false, isLocked: false);
  }
}

final appLockProvider = NotifierProvider<AppLockNotifier, AppLockState>(
  AppLockNotifier.new,
);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'update_check_service.dart';

/// Whether a newer build is available — null once dismissed for this
/// session even if [check] hasn't been asked to re-check, so closing the
/// dashboard banner doesn't reappear on the very next rebuild.
class UpdateNotifier extends Notifier<UpdateInfo?> {
  @override
  UpdateInfo? build() => null;

  Future<void> check({bool force = false}) async {
    final info = await UpdateCheckService.instance.checkForUpdate(force: force);
    if (info != null) state = info;
  }

  void dismiss() => state = null;
}

final updateAvailableProvider = NotifierProvider<UpdateNotifier, UpdateInfo?>(
  UpdateNotifier.new,
);

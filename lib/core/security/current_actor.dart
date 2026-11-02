/// The signed-in user's id/name, cached in memory so anything that needs
/// to attribute an action (see ActivityLogService) can read it without
/// every repository call threading "who's doing this?" down from the
/// presentation layer. AuthNotifier keeps this in sync with its own state
/// whenever the signed-in user changes (sign in, sign out, restore,
/// name edit) — there's deliberately no persistence here, since logging
/// only ever happens during a live session anyway.
class CurrentActor {
  CurrentActor._();

  static final CurrentActor instance = CurrentActor._();

  int? userId;
  String? userName;

  void set({required int? userId, required String? userName}) {
    this.userId = userId;
    this.userName = userName;
  }

  void clear() => set(userId: null, userName: null);
}

/// Whether a visit is a full-price معاينة or a reduced/free مراجعة —
/// distinct from [Visit.needsFollowUp] (which flags that a *future* visit is
/// needed). This instead classifies the visit being recorded right now.
///
/// Default business rule (mirrors the appointments feature's existing
/// "متابعة مجانية" window — see `GetFollowUpDays`): a patient's first visit,
/// and any visit more than the clinic's follow-up-days setting after their
/// last consultation, is a full [consultation]. A visit within that window
/// is a [checkup] — the doctor still enters whatever fee applies (often
/// half-price or free) via the visit's own fee field. The doctor can always
/// override the suggested type by hand.
enum VisitType {
  consultation,
  checkup;

  String get label => switch (this) {
    VisitType.consultation => 'معاينة',
    VisitType.checkup => 'مراجعة',
  };
}

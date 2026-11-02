/// What a paired device (the secretary's or nurse's tablet) is allowed to do
/// on the doctor's device. The doctor decides per device; the doctor's own
/// device checks every request against these, so a client can never grant
/// itself more than it was given.
enum SyncPermission {
  viewPatients('عرض المرضى والبحث', 'الاسم والهاتف والعمر فقط، لا السجل الطبي'),
  registerPatients('تسجيل مريض جديد', 'إضافة مرضى جدد'),
  editPatients('تعديل بيانات المريض الأساسية', 'الاسم والهاتف والعنوان'),
  manageAppointments('إدارة المواعيد', 'عرض الحجز وإضافته وتغيير حالته'),
  collectPayments('التحصيل والذمم', 'عرض المبالغ المتبقية وتسجيل الدفعات');

  const SyncPermission(this.label, this.hint);

  final String label;
  final String hint;

  static SyncPermission? fromName(String name) =>
      SyncPermission.values.where((p) => p.name == name).firstOrNull;
}

/// Starting points the doctor can tweak per device.
enum DevicePreset {
  secretary('سكرتيرة', {
    SyncPermission.viewPatients,
    SyncPermission.registerPatients,
    SyncPermission.editPatients,
    SyncPermission.manageAppointments,
    SyncPermission.collectPayments,
  }),
  nurse('ممرضة', {
    SyncPermission.viewPatients,
    SyncPermission.registerPatients,
    SyncPermission.manageAppointments,
  }),
  viewer('عرض فقط', {SyncPermission.viewPatients});

  const DevicePreset(this.label, this.permissions);

  final String label;
  final Set<SyncPermission> permissions;
}

/// Which permission each remote operation needs. Anything not listed here
/// is refused, so a new operation is closed by default until it's added.
const syncOpPermissions = <String, SyncPermission?>{
  'session.info': null, // any paired device
  'patients.search': SyncPermission.viewPatients,
  'patients.create': SyncPermission.registerPatients,
  'patients.update': SyncPermission.editPatients,
  'appointments.list': SyncPermission.manageAppointments,
  'appointments.create': SyncPermission.manageAppointments,
  'appointments.setStatus': SyncPermission.manageAppointments,
  'payments.debts': SyncPermission.collectPayments,
  'payments.record': SyncPermission.collectPayments,
};

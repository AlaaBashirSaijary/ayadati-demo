import '../../domain/entities/app_user.dart';

class AppUserModel extends AppUser {
  const AppUserModel({
    required super.id,
    required super.clinicId,
    required super.clinicName,
    required super.name,
    required super.email,
    required super.role,
  });

  factory AppUserModel.fromMap(Map<String, Object?> map) => AppUserModel(
    id: map['id']! as int,
    clinicId: map['clinic_id']! as int,
    clinicName: (map['clinic_name'] as String?) ?? '',
    name: map['name']! as String,
    email: map['email']! as String,
    role: (map['role'] as String?) ?? 'nurse',
  );
}

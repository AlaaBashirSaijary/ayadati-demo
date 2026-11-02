import 'package:equatable/equatable.dart';

/// Mirrors app/Models/User.php.
class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.clinicId,
    required this.clinicName,
    required this.name,
    required this.email,
    required this.role,
  });

  final int id;
  final int clinicId;
  final String clinicName;
  final String name;
  final String email;
  final String role;

  /// Mirrors User::isAdmin() — only admins may change storage settings.
  bool get isAdmin => role == 'admin';

  @override
  List<Object?> get props => [id, clinicId, clinicName, name, email, role];
}

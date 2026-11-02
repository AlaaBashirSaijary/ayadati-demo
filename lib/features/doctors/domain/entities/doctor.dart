import 'package:equatable/equatable.dart';

/// A named doctor within the active clinic — distinct from a `users` login
/// account (see AppUser): a group practice shares logins per staff member
/// but still needs each doctor's own appointments, visits, prescriptions
/// and certificates told apart on one shared schedule. See
/// ClinicDataDatabase's doctors table doc comment for why this isn't a
/// foreign key into `users`.
class Doctor extends Equatable {
  const Doctor({this.id, required this.name, this.isActive = true});

  final int? id;
  final String name;
  final bool isActive;

  Doctor copyWith({int? id, String? name, bool? isActive}) {
    return Doctor(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [id, name, isActive];
}

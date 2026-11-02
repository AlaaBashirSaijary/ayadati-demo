import '../../domain/entities/doctor.dart';

class DoctorModel extends Doctor {
  const DoctorModel({super.id, required super.name, super.isActive});

  factory DoctorModel.fromEntity(Doctor doctor) =>
      DoctorModel(id: doctor.id, name: doctor.name, isActive: doctor.isActive);

  factory DoctorModel.fromMap(Map<String, Object?> map) => DoctorModel(
    id: map['id'] as int?,
    name: map['name']! as String,
    isActive: (map['is_active']! as int) == 1,
  );

  /// Excludes 'created_at' — only set once, by the datasource's insert, so
  /// an update never overwrites when this doctor was first added.
  Map<String, Object?> toMap() {
    return {'name': name, 'is_active': isActive ? 1 : 0};
  }
}

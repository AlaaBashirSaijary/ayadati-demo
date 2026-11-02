import '../../domain/entities/clinic.dart';

class ClinicModel extends Clinic {
  const ClinicModel({
    required super.id,
    required super.name,
    required super.slug,
    required super.dbFileName,
  });

  factory ClinicModel.fromMap(Map<String, Object?> map) => ClinicModel(
    id: map['id']! as int,
    name: map['name']! as String,
    slug: map['slug']! as String,
    dbFileName: map['db_file_name']! as String,
  );
}

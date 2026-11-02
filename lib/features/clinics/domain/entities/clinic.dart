import 'package:equatable/equatable.dart';

/// One clinic in the registry. Mirrors app/Models/Clinic.php plus
/// [dbFileName] — the Flutter-only addition that makes "each clinic has its
/// own separate database" literally true: this is the SQLite file (kept
/// beside the app-level database, see AppDatabase.currentFolder()) that
/// holds this clinic's patients and visits, and nothing else's.
class Clinic extends Equatable {
  const Clinic({
    required this.id,
    required this.name,
    required this.slug,
    required this.dbFileName,
  });

  final int id;
  final String name;
  final String slug;
  final String dbFileName;

  @override
  List<Object?> get props => [id, name, slug, dbFileName];
}

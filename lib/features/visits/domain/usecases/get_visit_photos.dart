import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/visit_photo.dart';
import '../repositories/visit_repository.dart';

class GetVisitPhotos implements UseCase<List<VisitPhoto>, int> {
  const GetVisitPhotos(this._repository);

  final VisitRepository _repository;

  @override
  Future<Either<Failure, List<VisitPhoto>>> call(int visitId) {
    return _repository.listPhotos(visitId);
  }
}

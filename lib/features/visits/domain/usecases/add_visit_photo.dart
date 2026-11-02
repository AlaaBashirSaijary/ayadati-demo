import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/visit_repository.dart';

class AddVisitPhotoParams {
  const AddVisitPhotoParams({required this.visitId, required this.imageData});

  final int visitId;
  final Uint8List imageData;
}

class AddVisitPhoto implements UseCase<void, AddVisitPhotoParams> {
  const AddVisitPhoto(this._repository);

  final VisitRepository _repository;

  @override
  Future<Either<Failure, void>> call(AddVisitPhotoParams params) {
    return _repository.addPhoto(params.visitId, params.imageData);
  }
}

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../error/failures.dart';

/// Base contract every use case implements: domain logic in, `Either` a
/// [Failure] or a result out. Keeps the domain layer the single place
/// business rules live — the same role Laravel's Controllers +
/// FormRequest validation play together, just made explicit as a type.
abstract class UseCase<ReturnType, Params> {
  Future<Either<Failure, ReturnType>> call(Params params);
}

/// Marker for use cases that take no parameters (e.g. Logout).
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}

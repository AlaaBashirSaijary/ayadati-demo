import 'package:dartz/dartz.dart';

import '../../../../core/database/activity_log_service.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._local);

  final AuthLocalDataSource _local;

  @override
  Future<Either<Failure, AppUser>> login({
    required String email,
    required String password,
  }) async {
    try {
      final hash = await _local.passwordHashFor(email);
      // Same message for "no such user" and "wrong password" — mirrors
      // Laravel's default Auth::attempt() behaviour, which never reveals
      // which half of the credential pair was wrong.
      if (hash == null || !_local.verifyPassword(password, hash)) {
        return const Left(
          AuthFailure('البريد الإلكتروني أو كلمة المرور غير صحيحة.'),
        );
      }

      final user = await _local.findByEmail(email);
      if (user == null) {
        return const Left(
          AuthFailure('البريد الإلكتروني أو كلمة المرور غير صحيحة.'),
        );
      }

      await _local.rememberSession(user.id);
      return Right(user);
    } catch (e) {
      return Left(UnexpectedFailure.from('تعذّر تسجيل الدخول', e));
    }
  }

  @override
  Future<void> logout() => _local.forgetSession();

  @override
  Future<AppUser?> currentUser() async {
    final id = await _local.currentSessionUserId();
    if (id == null) return null;
    return _local.findById(id);
  }

  @override
  Future<Either<Failure, AppUser>> updateName(int userId, String name) async {
    if (name.trim().isEmpty) {
      return const Left(ValidationFailure({'name': 'أدخلي الاسم.'}));
    }
    try {
      return Right(await _local.updateName(userId, name.trim()));
    } catch (e) {
      return Left(UnexpectedFailure.from('تعذّر تحديث الاسم', e));
    }
  }

  @override
  Future<Either<Failure, Unit>> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    if (newPassword.length < 8) {
      return const Left(ValidationFailure({'password': '8 أحرف على الأقل.'}));
    }
    try {
      final ok = await _local.changePassword(
        userId,
        currentPassword,
        newPassword,
      );
      if (!ok) {
        return const Left(
          ValidationFailure({
            'current_password': 'كلمة المرور الحالية غير صحيحة.',
          }),
        );
      }
      return const Right(unit);
    } catch (e) {
      return Left(UnexpectedFailure.from('تعذّر تغيير كلمة المرور', e));
    }
  }

  @override
  Future<Either<Failure, Unit>> resetPasswordWithRecoveryCode({
    required String email,
    required String recoveryCode,
    required String newPassword,
  }) async {
    if (newPassword.length < 8) {
      return const Left(ValidationFailure({'password': '8 أحرف على الأقل.'}));
    }
    try {
      final ok = await _local.resetPasswordWithRecoveryCode(
        email: email,
        recoveryCode: recoveryCode,
        newPassword: newPassword,
      );
      if (!ok) {
        return const Left(
          AuthFailure('البريد الإلكتروني أو رمز الاسترداد غير صحيح.'),
        );
      }
      return const Right(unit);
    } catch (e) {
      return Left(UnexpectedFailure.from('تعذّرت إعادة تعيين كلمة المرور', e));
    }
  }

  @override
  Future<Either<Failure, String>> regenerateRecoveryCode(int userId) async {
    try {
      return Right(await _local.regenerateRecoveryCode(userId));
    } catch (e) {
      return Left(UnexpectedFailure.from('تعذّر إنشاء رمز استرداد جديد', e));
    }
  }

  @override
  Future<Either<Failure, List<AppUser>>> listClinicUsers(int clinicId) async {
    try {
      return Right(await _local.listUsersForClinic(clinicId));
    } catch (e) {
      return Left(StorageFailure.from('تعذّرت قراءة قائمة المستخدمين', e));
    }
  }

  @override
  Future<Either<Failure, AppUser>> createStaffUser({
    required int clinicId,
    required String name,
    required String email,
    required String password,
    required bool isAdmin,
  }) async {
    if (name.trim().isEmpty) {
      return const Left(ValidationFailure({'name': 'أدخلي الاسم.'}));
    }
    if (!email.contains('@')) {
      return const Left(
        ValidationFailure({'email': 'بريد إلكتروني غير صحيح.'}),
      );
    }
    if (password.length < 8) {
      return const Left(ValidationFailure({'password': '8 أحرف على الأقل.'}));
    }
    try {
      final user = await _local.createStaffUser(
        clinicId: clinicId,
        name: name.trim(),
        email: email.trim(),
        password: password,
        role: isAdmin ? 'admin' : 'nurse',
      );
      await ActivityLogService.instance.log(
        ActivityAction.userCreated,
        entityLabel: user.name,
      );
      return Right(user);
    } on StateError catch (e) {
      return Left(ValidationFailure({'email': e.message}));
    } catch (e) {
      return Left(UnexpectedFailure.from('تعذّر إنشاء الحساب', e));
    }
  }

  @override
  Future<Either<Failure, Unit>> adminSetPassword({
    required int userId,
    required String newPassword,
  }) async {
    if (newPassword.length < 8) {
      return const Left(ValidationFailure({'password': '8 أحرف على الأقل.'}));
    }
    try {
      final target = await _local.findById(userId);
      await _local.adminSetPassword(userId, newPassword);
      await ActivityLogService.instance.log(
        ActivityAction.userPasswordReset,
        entityLabel: target?.name,
      );
      return const Right(unit);
    } catch (e) {
      return Left(UnexpectedFailure.from('تعذّر تغيير كلمة المرور', e));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteStaffUser(int userId) async {
    try {
      final target = await _local.findById(userId);
      await _local.deleteUser(userId);
      await ActivityLogService.instance.log(
        ActivityAction.userDeleted,
        entityLabel: target?.name,
      );
      return const Right(unit);
    } on StateError catch (e) {
      return Left(ValidationFailure({'user': e.message}));
    } catch (e) {
      return Left(StorageFailure.from('تعذّر حذف المستخدم', e));
    }
  }
}

import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:agrobravo/features/auth/domain/entities/user_entity.dart';

abstract class AuthRepository {
  Future<Either<Exception, UserEntity>> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<Either<Exception, UserEntity>> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String userType, // 'USER_APP' or 'GUIA'
  });

  Future<void> signOut();

  Future<Option<UserEntity>> getCurrentUser();

  Future<Either<Exception, void>> resetPassword(String email);
  Future<Either<Exception, void>> verifyOTP(String email, String token);
  Future<Either<Exception, void>> updatePassword(String newPassword);
  Future<Either<Exception, void>> updateFirstAccess(String userId, bool isFirstAccess);
  Future<Either<Exception, void>> signInWithGoogle();
  Future<Either<Exception, void>> signInWithApple();
  Future<Either<Exception, void>> resendSignUpEmail(String email);
  Stream<AuthChangeEvent> get onAuthStateChange;
}

class EmailNotConfirmedException implements Exception {
  final String message;
  EmailNotConfirmedException([this.message = 'E-mail não confirmado. Verifique sua caixa de entrada.']);
  @override
  String toString() => message;
}


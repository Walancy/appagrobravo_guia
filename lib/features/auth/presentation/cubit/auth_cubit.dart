import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:agrobravo/features/auth/domain/repositories/auth_repository.dart';
import 'package:agrobravo/features/auth/presentation/cubit/auth_state.dart';
import 'package:dartz/dartz.dart';

@LazySingleton()
class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;

  AuthCubit(this._authRepository) : super(const AuthState.initial()) {
    _authRepository.onAuthStateChange.listen((event) {
      if (event == AuthChangeEvent.passwordRecovery) {
        emit(const AuthState.passwordRecovery());
      }

      if (event == AuthChangeEvent.signedOut) {
        emit(const AuthState.unauthenticated());
      }

      // Captura o retorno do OAuth (Google / Apple).
      // O Supabase dispara signedIn quando o deep link de callback é processado.
      // Executamos checkAuthStatus() para replicar exatamente o mesmo fluxo
      // do login por e-mail: busca perfil em public.users, salva cache e
      // emite AuthState.authenticated(user) ou requireFirstAccessPasswordChange.
      if (event == AuthChangeEvent.signedIn) {
        final alreadyAuthenticated = state.maybeWhen(
          authenticated: (_) => true,
          orElse: () => false,
        );
        if (!alreadyAuthenticated) {
          checkAuthStatus();
        }
      }
    });
  }

  Future<void> checkAuthStatus() async {
    emit(const AuthState.loading());
    final userOption = await _authRepository.getCurrentUser();
    userOption.fold(
      () => emit(const AuthState.unauthenticated()),
      (user) {
        // Bloqueia quem não tem nenhum role de guia (ex: USER_APP)
        if (!user.isGuide) {
          _authRepository.signOut();
          emit(const AuthState.unauthenticated());
          return;
        }
        // Guia pendente: logado mas sem acesso ao app
        if (user.roles.contains('GUIA_PENDENTE') &&
            !user.roles.contains('GUIA') &&
            !user.roles.contains('COLABORADOR') &&
            !user.roles.contains('MASTER')) {
          emit(AuthState.pendingGuide(user));
          return;
        }
        if (user.isFirstAccess) {
          emit(AuthState.requireFirstAccessPasswordChange(user));
        } else {
          emit(AuthState.authenticated(user));
        }
      },
    );
  }

  Future<void> login(String email, String password) async {
    emit(const AuthState.loading());

    final result = await _authRepository.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    result.fold(
      (error) {
        if (error is EmailNotConfirmedException) {
          emit(AuthState.emailVerificationRequired(email));
        } else {
          emit(AuthState.error(error.toString().replaceAll('Exception: ', '')));
        }
      },
      (user) {
        // Bloqueia quem não tem nenhum role de guia (ex: USER_APP)
        if (!user.isGuide) {
          _authRepository.signOut();
          emit(const AuthState.travelerAccess());
          return;
        }
        // Guia pendente: logado mas sem acesso ao app
        if (user.roles.contains('GUIA_PENDENTE') &&
            !user.roles.contains('GUIA') &&
            !user.roles.contains('COLABORADOR') &&
            !user.roles.contains('MASTER')) {
          emit(AuthState.pendingGuide(user));
          return;
        }
        if (user.isFirstAccess) {
          emit(AuthState.requireFirstAccessPasswordChange(user));
        } else {
          emit(AuthState.authenticated(user));
        }
      },
    );
  }

  Future<void> register(
    String name,
    String email,
    String password,
    String passwordConfirm,
  ) async {
    if (password != passwordConfirm) {
      emit(const AuthState.error('As senhas não conferem.'));
      return;
    }

    emit(const AuthState.loading());
    // Novo guia entra sempre como GUIA_PENDENTE — aguarda aprovação manual
    final result = await _authRepository.signUpWithEmailAndPassword(
      email: email,
      password: password,
      name: name,
      userType: 'GUIA_PENDENTE',
    );

    result.fold(
      (error) {
        if (error is EmailNotConfirmedException) {
          emit(AuthState.emailVerificationRequired(email));
        } else {
          emit(AuthState.error(error.toString().replaceAll('Exception: ', '')));
        }
      },
      (user) {
        // Recém-cadastrado entra direto na tela de pendência
        emit(AuthState.pendingGuide(user));
      },
    );
  }

  Future<void> recoverPassword(String email) async {
    emit(const AuthState.loading());
    final result = await _authRepository.resetPassword(email);
    result.fold(
      (error) => emit(AuthState.error(error.toString())),
      (_) => emit(const AuthState.passwordResetEmailSent()),
    );
  }

  Future<void> verifyRecoveryCode(String email, String code) async {
    emit(const AuthState.loading());
    final result = await _authRepository.verifyOTP(email, code);
    result.fold(
      (error) => emit(AuthState.error(error.toString())),
      (_) => emit(const AuthState.otpVerified()),
    );
  }

  Future<void> updatePassword(String password, String confirmPassword, {bool isFirstAccess = false}) async {
    if (password != confirmPassword) {
      emit(const AuthState.error('As senhas não conferem.'));
      return;
    }

    if (password.length < 6) {
      emit(const AuthState.error('A senha deve ter pelo menos 6 caracteres.'));
      return;
    }

    emit(const AuthState.loading());
    final result = await _authRepository.updatePassword(password);
    await result.fold(
      (error) async => emit(AuthState.error(error.toString())),
      (_) async {
        if (isFirstAccess) {
           final userOption = await _authRepository.getCurrentUser();
           await userOption.fold(
             () async {}, 
             (user) async {
               await _authRepository.updateFirstAccess(user.id, false);
             }
           );
        }
        emit(const AuthState.passwordUpdated());
      },
    );
  }

  Future<void> loginWithGoogle() async {
    // Não emitimos loading aqui: o browser será aberto e o app ficará em
    // background. Quando o usuário retornar, o listener de signedIn no
    // construtor chamará checkAuthStatus() e gerenciará o estado.
    // Emitimos erro apenas se o repositório falhar imediatamente (ex: browser
    // não pôde ser aberto).
    final result = await _authRepository.signInWithGoogle();
    result.fold(
      (error) => emit(AuthState.error(error.toString())),
      (_) {},
    );
  }

  Future<void> loginWithApple() async {
    // Mesma lógica do loginWithGoogle: estado gerenciado pelo listener de signedIn.
    final result = await _authRepository.signInWithApple();
    result.fold(
      (error) => emit(AuthState.error(error.toString())),
      (_) {},
    );
  }

  Future<void> logout() async {
    await _authRepository.signOut();
    emit(const AuthState.unauthenticated());
  }

  Future<Either<Exception, void>> deleteAccount() async {
    emit(const AuthState.loading());
    final result = await _authRepository.deleteAccount();
    return result.fold(
      (error) {
        emit(AuthState.error(error.toString()));
        return Left(error);
      },
      (_) async {
        await logout();
        return const Right(null);
      },
    );
  }

  Future<void> resendConfirmationEmail(String email) async {
    emit(const AuthState.loading());
    final result = await _authRepository.resendSignUpEmail(email);
    result.fold(
      (error) => emit(AuthState.error(error.toString().replaceAll('Exception: ', ''))),
      (_) => emit(AuthState.emailVerificationRequired(email)),
    );
  }
}

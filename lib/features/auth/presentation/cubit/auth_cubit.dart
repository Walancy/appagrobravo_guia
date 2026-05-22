import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:agrobravo/features/auth/domain/repositories/auth_repository.dart';
import 'package:agrobravo/features/auth/presentation/cubit/auth_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

@LazySingleton()
class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;

  AuthCubit(this._authRepository) : super(const AuthState.initial()) {
    _authRepository.onAuthStateChange.listen((event) {
      if (event == AuthChangeEvent.passwordRecovery) {
        emit(const AuthState.passwordRecovery());
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
        if (user.isFirstAccess) {
          emit(AuthState.requireFirstAccessPasswordChange(user));
        } else {
          emit(AuthState.authenticated(user));
        }
      },
    );
  }

  Future<void> login(
    String email,
    String password, {
    bool rememberMe = false,
  }) async {
    emit(const AuthState.loading());

    final prefs = await SharedPreferences.getInstance();
    if (rememberMe) {
      await prefs.setString('remembered_email', email);
      await prefs.setString('remembered_password', password);
    } else {
      await prefs.remove('remembered_email');
      await prefs.remove('remembered_password');
    }

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
        if (user.isFirstAccess) {
          emit(AuthState.requireFirstAccessPasswordChange(user));
        } else {
          emit(AuthState.authenticated(user));
        }
      },
    );
  }

  Future<String?> getRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('remembered_email');
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
    // Default to USER_APP for self-registration via app
    final result = await _authRepository.signUpWithEmailAndPassword(
      email: email,
      password: password,
      name: name,
      userType: 'USER_APP',
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
        emit(AuthState.authenticated(user));
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

  Future<void> resendConfirmationEmail(String email) async {
    emit(const AuthState.loading());
    final result = await _authRepository.resendSignUpEmail(email);
    result.fold(
      (error) => emit(AuthState.error(error.toString().replaceAll('Exception: ', ''))),
      (_) => emit(AuthState.emailVerificationRequired(email)),
    );
  }
}

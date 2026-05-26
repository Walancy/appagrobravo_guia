import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:agrobravo/features/auth/domain/entities/user_entity.dart';
import 'package:agrobravo/features/auth/domain/repositories/auth_repository.dart';
import 'package:agrobravo/features/auth/data/models/user_model.dart';
import 'dart:developer';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:google_sign_in/google_sign_in.dart';

@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _supabaseClient;

  AuthRepositoryImpl(this._supabaseClient);

  Future<void> _saveUserToPreferences(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_user_profile', jsonEncode(user.toJson()));
    } catch (e) {
      log('Erro ao salvar usuário no cache: $e');
    }
  }

  Future<UserModel?> _getUserFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('cached_user_profile');
      if (jsonString != null) {
        return UserModel.fromJson(jsonDecode(jsonString));
      }
    } catch (e) {
      log('Erro ao recuperar usuário do cache: $e');
    }
    return null;
  }

  @override
  Future<Either<Exception, UserEntity>> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        return Left(Exception('Login falhou: Usuário não retornado.'));
      }

      // Buscar dados complementares na tabela public.users
      final userProfile = await _supabaseClient
          .from('users')
          .select()
          .eq('id', response.user!.id)
          .maybeSingle();

      UserModel userModel;
      if (userProfile != null) {
        userModel = UserModel.fromJson(userProfile);
      } else {
        // Fallback: usuário existe no Auth mas não tem perfil em public.users
        final metadata = response.user!.userMetadata ?? {};
        userModel = UserModel(
          id: response.user!.id,
          email: email,
          nome: metadata['nome'] as String? ?? email.split('@').first,
          roles: (metadata['tipouser'] as List?)?.cast<String>() ?? [],
          foto: null,
          isFirstAccess: false,
        );
      }
      await _saveUserToPreferences(userModel);

      return Right(userModel.toEntity());
    } on AuthException catch (e) {
      log('Auth Error: ${e.message}');
      if (e.message.toLowerCase().contains('email not confirmed') ||
          e.message.toLowerCase().contains('confirmar seu e-mail') ||
          e.message.toLowerCase().contains('email_not_confirmed')) {
        return Left(EmailNotConfirmedException());
      }
      return Left(_mapAuthException(e));
    } catch (e) {
      log('Unexpected Error: $e');
      return Left(Exception('Erro inesperado ao fazer login.'));
    }
  }

  @override
  Future<Either<Exception, UserEntity>> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String userType,
  }) async {
    try {
      // Enviar metadados para que (se houver trigger) o banco saiba o que fazer
      final response = await _supabaseClient.auth.signUp(
        email: email,
        password: password,
        data: {
          'nome': name,
          'tipouser': [userType], // Envia como array
        },
      );

      if (response.user == null) {
        return Left(Exception('Cadastro falhou.'));
      }

      if (response.session == null) {
        // E-mail de confirmação é obrigatório e foi enviado, portanto não há sessão ativa ainda
        return Left(EmailNotConfirmedException());
      }

      // Opcional: Inserir manualmente se não houver trigger
      // Por segurança, vamos verificar se o perfil foi criado, se não, criamos.
      try {
        await _supabaseClient.from('users').upsert({
          'id': response.user!.id,
          'nome': name,
          'email': email,
          'tipouser': [userType],
        });
      } catch (e) {
        log('Erro ao criar perfil público (pode já existir via trigger): $e');
      }

      // Retorna a entidade (construída manualmente pois o fetch pode ter delay)
      final userModel = UserModel(
        id: response.user!.id,
        email: email,
        nome: name,
        roles: [userType],
        foto: null,
        isFirstAccess: false,
      );

      // Cache this basic model as well so subsequent immediate offline starts have something
      await _saveUserToPreferences(userModel);

      return Right(userModel.toEntity());
    } on AuthException catch (e) {
      return Left(_mapAuthException(e));
    } catch (e) {
      return Left(Exception('Erro inesperado ao cadastrar.'));
    }
  }

  @override
  Future<void> signOut() async {
    await _supabaseClient.auth.signOut();
    // Clear cache on sign out
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_user_profile');
  }

  @override
  Future<Option<UserEntity>> getCurrentUser() async {
    final user = _supabaseClient.auth.currentUser;
    if (user == null) return none();

    try {
      final userProfile = await _supabaseClient
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (userProfile != null) {
        final userModel = UserModel.fromJson(userProfile);
        await _saveUserToPreferences(userModel);
        return some(userModel.toEntity());
      }

      // Perfil não encontrado: tenta cache offline
      final cachedUser = await _getUserFromPreferences();
      if (cachedUser != null && cachedUser.id == user.id) {
        return some(cachedUser.toEntity());
      }

      // Fallback: constrói entidade básica dos metadados do Auth
      final metadata = user.userMetadata ?? {};
      final fallbackModel = UserModel(
        id: user.id,
        email: user.email ?? '',
        nome: metadata['nome'] as String? ?? (user.email ?? '').split('@').first,
        roles: (metadata['tipouser'] as List?)?.cast<String>() ?? [],
        foto: null,
        isFirstAccess: false,
      );
      return some(fallbackModel.toEntity());
    } catch (e) {
      log('Erro ao recuperar usuário atual: $e. Tentando cache offline.');
      final cachedUser = await _getUserFromPreferences();
      if (cachedUser != null && cachedUser.id == user.id) {
        return some(cachedUser.toEntity());
      }
      return none();
    }
  }

  @override
  Future<Either<Exception, void>> resetPassword(String email) async {
    try {
      await _supabaseClient.auth.resetPasswordForEmail(email);
      return const Right(null);
    } on AuthException catch (e) {
      return Left(_mapAuthException(e));
    } catch (e) {
      return Left(Exception('Erro ao solicitar redefinição de senha.'));
    }
  }

  @override
  Future<Either<Exception, void>> updatePassword(String newPassword) async {
    try {
      await _supabaseClient.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return const Right(null);
    } on AuthException catch (e) {
      return Left(_mapAuthException(e));
    } catch (e) {
      return Left(Exception('Erro ao atualizar a senha.'));
    }
  }

  @override
  Future<Either<Exception, void>> verifyOTP(String email, String token) async {
    try {
      final res = await _supabaseClient.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.recovery,
      );
      if (res.user != null) {
        return const Right(null);
      } else {
        return Left(Exception('Token inválido ou expirado.'));
      }
    } on AuthException catch (e) {
      return Left(_mapAuthException(e));
    } catch (e) {
      return Left(Exception('Erro ao verificar código.'));
    }
  }

  @override
  Future<Either<Exception, void>> updateFirstAccess(String userId, bool isFirstAccess) async {
    try {
      await _supabaseClient.from('users').update({
        'first_access': isFirstAccess,
      }).eq('id', userId);
      return const Right(null);
    } catch (e) {
      log('Erro ao atualizar primeiro acesso: $e');
      return Left(Exception('Erro ao atualizar primeiro acesso.'));
    }
  }

  @override
  Future<Either<Exception, void>> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        await _supabaseClient.auth.signInWithOAuth(OAuthProvider.google);
        return const Right(null);
      }

      final googleSignIn = GoogleSignIn(
        scopes: ['profile', 'email'],
        clientId: defaultTargetPlatform == TargetPlatform.iOS
            ? '175750237033-1nc7m8nsj7s3d1d6ql6mki91nmpk4pkp.apps.googleusercontent.com'
            : null,
        serverClientId: '175750237033-u5p4jglif68kv2gtioqhvknkr4dd732n.apps.googleusercontent.com',
      );

      await googleSignIn.signOut().catchError((_) => null);
      
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return Left(Exception('Login cancelado pelo usuário.'));
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        return Left(Exception('Não foi possível obter o token de identidade do Google.'));
      }

      await _supabaseClient.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      return const Right(null);
    } on AuthException catch (e) {
      return Left(_mapAuthException(e));
    } catch (e) {
      return Left(Exception('Erro ao fazer login com Google: $e'));
    }
  }

  @override
  Future<Either<Exception, void>> signInWithApple() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final rawNonce = _supabaseClient.auth.generateRawNonce();
        final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

        final credential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: hashedNonce,
        );

        final idToken = credential.identityToken;
        if (idToken == null) {
          return Left(Exception('Não foi possível obter o token de identidade da Apple.'));
        }

        await _supabaseClient.auth.signInWithIdToken(
          provider: OAuthProvider.apple,
          idToken: idToken,
          nonce: rawNonce,
        );
        return const Right(null);
      } else {
        // Android ou Web: usa o fluxo de redirecionamento Web OAuth
        await _supabaseClient.auth.signInWithOAuth(
          OAuthProvider.apple,
          redirectTo: kIsWeb ? null : 'io.supabase.agrobravoappguia://login-callback/',
        );
        return const Right(null);
      }
    } on AuthException catch (e) {
      return Left(_mapAuthException(e));
    } catch (e) {
      return Left(Exception('Erro ao fazer login com a Apple: $e'));
    }
  }

  @override
  Stream<AuthChangeEvent> get onAuthStateChange =>
      _supabaseClient.auth.onAuthStateChange.map((data) => data.event);

  @override
  Future<Either<Exception, void>> resendSignUpEmail(String email) async {
    try {
      await _supabaseClient.auth.resend(
        type: OtpType.signup,
        email: email,
      );
      return const Right(null);
    } on AuthException catch (e) {
      return Left(_mapAuthException(e));
    } catch (e) {
      return Left(Exception('Erro ao reenviar e-mail de confirmação.'));
    }
  }

  @override
  Future<Either<Exception, void>> deleteAccount() async {
    try {
      await _supabaseClient.rpc('delete_user_account');
      return const Right(null);
    } catch (e) {
      log('Erro ao excluir conta: $e');
      return Left(Exception('Erro ao excluir conta no servidor: $e'));
    }
  }

  Exception _mapAuthException(AuthException e) {
    final message = e.message;

    // Tradução de limites de taxa (Resend Rate Limit)
    if (message.contains('For security purposes, you can only request this after')) {
      final regex = RegExp(r'\d+');
      final match = regex.firstMatch(message);
      if (match != null) {
        final seconds = match.group(0);
        return Exception('Por motivos de segurança, você só pode solicitar o reenvio após $seconds segundos.');
      } else {
        return Exception('Por motivos de segurança, aguarde um momento antes de solicitar novamente.');
      }
    }

    // Tradução de credenciais inválidas
    if (message == 'Invalid login credentials') {
      return Exception('E-mail ou senha incorretos.');
    }

    // Tradução de e-mail já cadastrado
    if (message == 'User already registered') {
      return Exception('Este e-mail já está cadastrado.');
    }

    return Exception(message);
  }
}

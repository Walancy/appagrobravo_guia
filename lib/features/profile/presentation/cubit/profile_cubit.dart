import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:injectable/injectable.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:agrobravo/features/profile/domain/entities/profile_entity.dart';
import 'package:agrobravo/features/profile/domain/repositories/profile_repository.dart';
import 'package:agrobravo/features/profile/presentation/cubit/profile_state.dart';
import 'package:agrobravo/features/auth/domain/repositories/auth_repository.dart';

@injectable
class ProfileCubit extends Cubit<ProfileState> {
  final ProfileRepository _profileRepository;
  final AuthRepository _authRepository;

  ProfileCubit(this._profileRepository, this._authRepository)
    : super(const ProfileState.initial());

  String _mapFailure(Object failure) {
    final message = failure.toString();
    if (message.contains('SocketException') ||
        message.contains('ClientException') ||
        message.contains('Network is unreachable') ||
        message.contains('Failed host lookup')) {
      return 'Sem conexão com a internet. Verifique sua rede.';
    }
    return message.replaceAll('Exception: ', '');
  }

  Future<void> loadProfile([String? userId]) async {
    emit(const ProfileState.loading());

    try {
      String? targetUserId = userId;
      bool isMe = false;

      if (targetUserId == null) {
        final userOption = await _authRepository.getCurrentUser();
        targetUserId = userOption.fold(() => null, (user) => user.id);
        isMe = true;
      } else {
        final userOption = await _authRepository.getCurrentUser();
        final currentId = userOption.fold(() => null, (user) => user.id);
        isMe = targetUserId == currentId;
      }

      if (targetUserId == null) {
        emit(const ProfileState.error('Usuário não autenticado'));
        return;
      }

      final profileResult = await _profileRepository.getProfile(targetUserId);
      final postsResult = await _profileRepository.getUserPosts(targetUserId);

      profileResult.fold(
        (error) => emit(ProfileState.error(_mapFailure(error))),
        (profile) {
          postsResult.fold(
            (error) => emit(ProfileState.error(_mapFailure(error))),
            (posts) => emit(
              ProfileState.loaded(profile: profile, posts: posts, isMe: isMe),
            ),
          );
        },
      );
    } catch (e) {
      emit(ProfileState.error('Erro ao carregar perfil: ${_mapFailure(e)}'));
    }
  }

  void setPendingAvatar(XFile file) {
    state.maybeMap(
      loaded: (currentState) {
        emit(currentState.copyWith(pendingAvatar: file));
      },
      orElse: () {},
    );
  }

  void setPendingCover(XFile file) {
    state.maybeMap(
      loaded: (currentState) {
        emit(currentState.copyWith(pendingCover: file));
      },
      orElse: () {},
    );
  }

  Future<void> saveChanges() async {
    final currentState = state.maybeMap(
      loaded: (s) => s,
      orElse: () => null,
    );
    if (currentState == null) return;

    // Se não há nada para salvar, apenas desliga a edição
    if (currentState.pendingAvatar == null && currentState.pendingCover == null) {
      emit(currentState.copyWith(isEditing: false));
      return;
    }

    // Upload Avatar se houver
    if (currentState.pendingAvatar != null) {
      state.maybeMap(
        loaded: (s) => emit(s.copyWith(isUpdatingAvatar: true)),
        orElse: () {},
      );
      final file = currentState.pendingAvatar!;
      final bytes = await file.readAsBytes();
      final extension = file.path.split('.').last;
      final result = await _profileRepository.updateProfilePhoto(bytes, extension);
      
      result.fold(
        (error) => emit(ProfileState.error(_mapFailure(error))),
        (newUrl) {
          state.maybeMap(
            loaded: (s) {
              emit(s.copyWith(
                profile: s.profile.copyWith(avatarUrl: newUrl),
                isUpdatingAvatar: false,
                pendingAvatar: null,
              ));
            },
            orElse: () {},
          );
        },
      );
    }

    // Upload Cover se houver
    if (currentState.pendingCover != null) {
      state.maybeMap(
        loaded: (s) => emit(s.copyWith(isUpdatingCover: true)),
        orElse: () {},
      );
      final file = currentState.pendingCover!;
      final bytes = await file.readAsBytes();
      final extension = file.path.split('.').last;
      final result = await _profileRepository.updateCoverPhoto(bytes, extension);
      
      result.fold(
        (error) => emit(ProfileState.error(_mapFailure(error))),
        (newUrl) {
          state.maybeMap(
            loaded: (s) {
              emit(s.copyWith(
                profile: s.profile.copyWith(coverUrl: newUrl),
                isUpdatingCover: false,
                pendingCover: null,
              ));
            },
            orElse: () {},
          );
        },
      );
    }

    // Desliga modo edição após salvar tudo com sucesso
    state.maybeMap(
      loaded: (s) => emit(s.copyWith(isEditing: false)),
      orElse: () {},
    );
  }

  void cancelEditing() {
    state.maybeMap(
      loaded: (currentState) {
        emit(currentState.copyWith(
          isEditing: false,
          pendingAvatar: null,
          pendingCover: null,
        ));
      },
      orElse: () {},
    );
  }

  void toggleEditing() {
    state.maybeMap(
      loaded: (currentState) {
        if (currentState.isEditing) {
          // Se estava editando e clicou, resetamos os pendentes ao fechar
          cancelEditing();
        } else {
          emit(currentState.copyWith(isEditing: true));
        }
      },
      orElse: () {},
    );
  }

  Future<dartz.Either<Exception, List<ProfileEntity>>> getConnections(
    String userId,
  ) async {
    return _profileRepository.getConnections(userId);
  }

  Future<void> requestConnection(String userId) async {
    final result = await _profileRepository.requestConnection(userId);
    result.fold(
      (error) => emit(ProfileState.error(_mapFailure(error))),
      (_) => loadProfile(userId),
    );
  }

  Future<void> cancelConnection(String userId) async {
    final result = await _profileRepository.cancelConnection(userId);
    result.fold(
      (error) => emit(ProfileState.error(_mapFailure(error))),
      (_) => loadProfile(userId),
    );
  }

  Future<void> acceptConnection(String userId) async {
    final result = await _profileRepository.acceptConnection(userId);
    result.fold(
      (error) => emit(ProfileState.error(_mapFailure(error))),
      (_) =>
          loadProfile(), // Reload current user profile to update counts if needed
    );
  }

  Future<void> rejectConnection(String userId) async {
    final result = await _profileRepository.rejectConnection(userId);
    result.fold(
      (error) => emit(ProfileState.error(_mapFailure(error))),
      (_) => loadProfile(),
    );
  }

  Future<void> removeConnection(String userId) async {
    final result = await _profileRepository.removeConnection(userId);
    result.fold(
      (error) => emit(ProfileState.error(_mapFailure(error))),
      (_) => loadProfile(userId),
    );
  }

  Future<void> updateFoodPreferences(List<String> preferences) async {
    final result = await _profileRepository.updateFoodPreferences(preferences);
    result.fold(
      (error) => emit(ProfileState.error(_mapFailure(error))),
      (_) => state.maybeMap(
        loaded: (currentState) => emit(
          currentState.copyWith(
            profile: currentState.profile.copyWith(
              foodPreferences: preferences,
            ),
          ),
        ),
        orElse: () {},
      ),
    );
  }

  Future<void> updateMedicalRestrictions(List<String> restrictions) async {
    final result = await _profileRepository.updateMedicalRestrictions(
      restrictions,
    );
    result.fold(
      (error) => emit(ProfileState.error(_mapFailure(error))),
      (_) => state.maybeMap(
        loaded: (currentState) => emit(
          currentState.copyWith(
            profile: currentState.profile.copyWith(
              medicalRestrictions: restrictions,
            ),
          ),
        ),
        orElse: () {},
      ),
    );
  }

  Future<void> updateAccountData(Map<String, dynamic> data) async {
    final result = await _profileRepository.updateAccountData(data: data);
    result.fold(
      (error) => emit(ProfileState.error(_mapFailure(error))),
      (_) => loadProfile(),
    );
  }

  Future<void> updateNotificationPreferences(Map<String, bool> prefs) async {
    final result = await _profileRepository.updateNotificationPreferences(
      prefs,
    );
    result.fold(
      (error) => emit(ProfileState.error(_mapFailure(error))),
      (_) =>
          null, // Don't reload whole profile, just local save. Or reload if needed.
    );
  }

  Future<Map<String, bool>> getNotificationPreferences() async {
    final result = await _profileRepository.getNotificationPreferences();
    return result.fold((_) => {}, (prefs) => prefs);
  }
}

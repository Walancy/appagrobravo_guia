import 'dart:typed_data';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:agrobravo/features/profile/domain/entities/profile_entity.dart';
import 'package:agrobravo/features/home/domain/entities/post_entity.dart';

part 'profile_state.freezed.dart';

@freezed
abstract class ProfileState with _$ProfileState {
  const factory ProfileState.initial() = _Initial;
  const factory ProfileState.loading() = _Loading;
  const factory ProfileState.loaded({
    required ProfileEntity profile,
    required List<PostEntity> posts,
    required bool isMe,
    @Default(false) bool isEditing,
    @Default(false) bool isUpdatingAvatar,
    @Default(false) bool isUpdatingCover,
    // Imagens selecionadas mas ainda não salvas (preview local em bytes).
    // Só são enviadas ao servidor quando o usuário toca em "Salvar".
    Uint8List? pendingAvatar,
    Uint8List? pendingCover,
  }) = _Loaded;
  const factory ProfileState.error(String message) = _Error;
}

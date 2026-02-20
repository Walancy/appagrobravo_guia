import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:agrobravo/features/profile/domain/entities/profile_entity.dart';

part 'chat_entity.freezed.dart';

@freezed
abstract class ChatEntity with _$ChatEntity {
  const factory ChatEntity({
    required String id,
    required String title,
    required String subtitle,
    String? imageUrl,
    DateTime? startDate,
    DateTime? endDate,
    @Default(0) int unreadCount,
    @Default(0) int memberCount,
  }) = _ChatEntity;
}

@freezed
abstract class GuideEntity with _$GuideEntity {
  const factory GuideEntity({
    required String id,
    required String name,
    required String role,
    String? avatarUrl,
  }) = _GuideEntity;
}

@freezed
abstract class ChatData with _$ChatData {
  const factory ChatData({
    ChatEntity? currentMission,
    @Default([]) List<GuideEntity> guides,
    @Default([]) List<ChatEntity> history,
    @Default({}) Map<String, String> lastMessages,
    @Default({}) Map<String, DateTime> lastMessageTimes,
  }) = _ChatData;
}

@freezed
abstract class GroupMemberEntity with _$GroupMemberEntity {
  const factory GroupMemberEntity({
    required String id,
    required String name,
    required String role,
    required bool isGuide,
    @Default(false) bool isMe,
    String? avatarUrl,
    @Default(ConnectionStatus.none) ConnectionStatus connectionStatus,
  }) = _GroupMemberEntity;
}

@freezed
abstract class GroupDetailEntity with _$GroupDetailEntity {
  const factory GroupDetailEntity({
    required List<GroupMemberEntity> members,
    required List<String> mediaUrls,
  }) = _GroupDetailEntity;
}

/// Plain (non-freezed) traveler info used in the Viajantes chat tab.
class TravelerInfo {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? role;
  final String groupId;
  final String groupName;
  final String missionId;
  final String missionName;
  final String? missionLogo;

  const TravelerInfo({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.role,
    required this.groupId,
    required this.groupName,
    required this.missionId,
    required this.missionName,
    this.missionLogo,
  });
}

/// Plain (non-freezed) guide info used in the Guias chat tab.
class GuideInfo {
  final String id;
  final String name;
  final String? avatarUrl;
  final String role;
  final List<String> groupNames;
  final List<String> groupIds;
  final Set<String> missionNames;

  const GuideInfo({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.role,
    this.groupNames = const [],
    this.groupIds = const [],
    this.missionNames = const {},
  });
}

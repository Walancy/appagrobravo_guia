import 'package:image_picker/image_picker.dart';
import 'package:dartz/dartz.dart';
import 'package:agrobravo/features/chat/domain/entities/chat_entity.dart';
import 'package:agrobravo/features/chat/domain/entities/message_entity.dart';

abstract class ChatRepository {
  Future<Either<Exception, ChatData>> getChatData();
  Stream<List<MessageEntity>> getMessages(String chatId, {bool isGroup = true});
  Future<void> sendMessage(
    String chatId,
    String text, {
    bool isGroup = true,
    XFile? image,
    String? replyToId,
  });
  Future<void> editMessage(String messageId, String newText);
  Future<void> deleteMessages(List<String> messageIds);
  Future<Either<Exception, GroupDetailEntity>> getGroupDetails(String groupId);

  /// DMs received from travelers (eu sou o guia)
  Future<Either<Exception, List<GuideEntity>>> getTravelerDMs();

  /// Other guides — with their group names for display
  Future<Either<Exception, List<GuideEntity>>> getGuideContacts();

  /// All guides with group name tags
  Future<Either<Exception, List<GuideInfo>>> getGuideInfos();

  /// All groups across all missions with mission name
  Future<Either<Exception, List<ChatEntity>>> getAllGroups();

  /// All travelers (participants) from all groups where I'm a guide
  Future<Either<Exception, List<TravelerInfo>>> getAllTravelers();
}

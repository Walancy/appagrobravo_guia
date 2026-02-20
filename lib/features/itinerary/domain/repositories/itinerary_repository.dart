import 'package:dartz/dartz.dart';
import '../entities/itinerary_item.dart';
import '../entities/itinerary_group.dart';
import '../entities/emergency_contacts.dart';
import '../entities/guide_mission.dart';
import '../entities/menu_item.dart';

abstract class ItineraryRepository {
  Future<Either<Exception, List<GuideMission>>> getGuideMissions();
  Future<Either<Exception, ItineraryGroupEntity>> getGroupDetails(
    String groupId,
  );
  Future<Either<Exception, List<ItineraryItemEntity>>> getItinerary(
    String groupId,
  );
  Future<Either<Exception, List<MenuItemEntity>>> getMenu(String eventId);
  Future<Either<Exception, List<Map<String, dynamic>>>> getTravelTimes(
    String groupId,
  );
  Future<Either<Exception, String?>> getUserGroupId();
  Future<Either<Exception, List<String>>> getUserPendingDocuments();
  Future<Either<Exception, List<Map<String, dynamic>>>> getGroupParticipants(
    String groupId,
  );
  Future<Either<Exception, List<String>>> getEventAttendance(String eventId);
  Future<Either<Exception, void>> updateAttendance(
    String eventId,
    String userId,
    bool isPresent,
  );
  Future<Either<Exception, EmergencyContacts>> getEmergencyContacts(
    double lat,
    double lng,
  );
}

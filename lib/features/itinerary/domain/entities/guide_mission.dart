import 'package:agrobravo/features/home/domain/entities/mission_entity.dart';
import 'package:agrobravo/features/itinerary/domain/entities/itinerary_group.dart';

class GuideMission {
  final MissionEntity mission;
  final List<ItineraryGroupEntity> groups;

  GuideMission({required this.mission, required this.groups});
}

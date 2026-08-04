import 'package:dartz/dartz.dart';
import '../entities/itinerary_item.dart';
import '../entities/itinerary_group.dart';
import '../entities/emergency_contacts.dart';
import '../entities/guide_mission.dart';
import '../entities/menu_item.dart';
import '../entities/guia_evento_status.dart';

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

  /// Grava as presenças de todos os passageiros em lote ao concluir o checklist.
  /// [presencas] é uma lista de maps com 'user_id' (String) e 'presente' (bool).
  Future<Either<Exception, void>> confirmarPresencas(
    String eventId,
    List<Map<String, dynamic>> presencas,
  );

  Future<Either<Exception, EmergencyContacts>> getEmergencyContacts(
    double lat,
    double lng,
  );

  // ─── Check-in / Check-out do guia ────────────────────────────────────────

  /// Retorna o status atual do guia no evento, ou null se ainda não iniciado.
  Future<Either<Exception, GuiaEventoStatus?>> getGuiaEventoStatus(
    String eventoId,
    String guiaId,
  );

  /// Registra o check-in: grava checkin_at = [checkinAt] e status = 'checkin_feito'.
  /// Também confirma as presenças em lote.
  Future<Either<Exception, GuiaEventoStatus>> registrarCheckin(
    String eventoId,
    String guiaId,
    DateTime checkinAt,
    List<Map<String, dynamic>> presencas,
  );

  /// Registra o check-out: grava checkout_at = [checkoutAt] e status = 'checkout_feito'.
  /// Também confirma as presenças em lote.
  Future<Either<Exception, GuiaEventoStatus>> registrarCheckout(
    String eventoId,
    String guiaId,
    DateTime checkoutAt,
    List<Map<String, dynamic>> presencas,
  );

  /// Reverte o check-in: volta status para 'pendente' e limpa checkin_at / checkout_at.
  Future<Either<Exception, GuiaEventoStatus>> resetarCheckin(
    String eventoId,
    String guiaId,
  );
}


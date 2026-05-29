import 'package:dartz/dartz.dart';
import 'package:agrobravo/features/notifications/domain/entities/notification_entity.dart';
import 'package:agrobravo/features/notifications/domain/entities/participante_entity.dart';
import 'package:agrobravo/features/notifications/domain/entities/lembrete_entity.dart';

abstract class NotificationsRepository {
  Future<Either<Exception, List<NotificationEntity>>> getNotifications();
  Future<Either<Exception, Unit>> markAsRead(String notificationId);
  Future<Either<Exception, Unit>> markAllAsRead();
  Future<Either<Exception, Unit>> respondFollowRequest(
    String userId,
    bool accept,
  );
  Future<Either<Exception, Unit>> sendGroupNotification({
    required String groupId,
    required String title,
    required String message,
    List<String>? destinatarios, // null = todos do grupo
  });
  Future<Either<Exception, List<ParticipanteEntity>>> getGrupoParticipantes(
    String groupId,
  );
  Future<Either<Exception, List<LembreteEntity>>> getLembretesHistorico(
    String groupId,
  );

  // ── Etapa 2: Agendamento ──────────────────────────────────────────────────
  Future<Either<Exception, Unit>> agendarLembrete({
    required String groupId,
    required String title,
    required String message,
    required DateTime agendadoPara,
    List<String>? destinatarios,
  });
  Future<Either<Exception, Unit>> cancelarLembrete(String lembreteId);
  Future<Either<Exception, Unit>> atualizarHorarioLembrete(
    String lembreteId,
    DateTime novoHorario,
  );
  Future<Either<Exception, Unit>> editarLembrete({
    required String lembreteId,
    required String mensagem,
    required DateTime agendadoPara,
    List<String>? destinatarios, // null = todos
    required int totalDestinatarios,
  });
  Future<Either<Exception, Unit>> enviarLembreteAgora(String lembreteId);
}



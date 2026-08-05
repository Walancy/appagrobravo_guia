import 'package:agrobravo/features/notifications/data/models/notification_model.dart';
import 'package:agrobravo/features/notifications/domain/entities/notification_entity.dart';
import 'package:agrobravo/features/notifications/domain/entities/participante_entity.dart';
import 'package:agrobravo/features/notifications/domain/entities/lembrete_entity.dart';
import 'package:agrobravo/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

@LazySingleton(as: NotificationsRepository)
class NotificationsRepositoryImpl implements NotificationsRepository {
  final SupabaseClient _supabaseClient;

  NotificationsRepositoryImpl(this._supabaseClient);

  Future<void> _saveNotificationsToCache(List<NotificationEntity> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList =
          list
              .map(
                (e) => {
                  'id': e.id,
                  'userName': e.userName,
                  'userAvatar': e.userAvatar,
                  'typeIndex': e.type.index,
                  'postImage': e.postImage,
                  'postId': e.postId,
                  'solicitacaoUserId': e.solicitacaoUserId,
                  'docId': e.docId,
                  'postOwnerId': e.postOwnerId,
                  'batepapoId': e.batepapoId,
                  'senderId': e.senderId,
                  'message': e.message,
                  'createdAt': e.createdAt.toIso8601String(),
                  'isRead': e.isRead,
                },
              )
              .toList();
      await prefs.setString('cached_notifications', jsonEncode(jsonList));
    } catch (e) {
      // ignore
    }
  }

  Future<List<NotificationEntity>> _getNotificationsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('cached_notifications');
      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        return jsonList.map((json) {
          return NotificationEntity(
            id: json['id'],
            userName: json['userName'],
            userAvatar: json['userAvatar'],
            type: NotificationType.values[json['typeIndex'] ?? 0],
            postImage: json['postImage'],
            postId: json['postId'],
            solicitacaoUserId: json['solicitacaoUserId'],
            docId: json['docId'],
            postOwnerId: json['postOwnerId'],
            batepapoId: json['batepapoId'],
            senderId: json['senderId'],
            message: json['message'],
            createdAt: DateTime.parse(json['createdAt']),
            isRead: json['isRead'] ?? false,
          );
        }).toList();
      }
    } catch (e) {
      // ignore
    }
    return [];
  }

  @override
  Future<Either<Exception, List<NotificationEntity>>> getNotifications() async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) return Left(Exception('Usuário não autenticado'));

      // Fetch notifications
      final response = await _supabaseClient
          .from('notificacoes')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List;

      // Collect unique requester IDs to fetch their profiles
      final requesterIds =
          data
              .where((n) => n['solicitacao_user_id'] != null)
              .map((n) => n['solicitacao_user_id'] as String)
              .toSet()
              .toList();

      Set<String> activePendingRequesterIds = {};
      Map<String, dynamic> profilesMap = {};
      if (requesterIds.isNotEmpty) {
        try {
          final profilesResponse = await _supabaseClient
              .from('users')
              .select('id, nome, foto')
              .inFilter('id', requesterIds);

          for (var profile in (profilesResponse as List)) {
            profilesMap[profile['id']] = profile;
          }

          final conexoesRes = await _supabaseClient
              .from('conexoes')
              .select('seguidor_id')
              .eq('seguido_id', userId)
              .eq('aprovou', false)
              .inFilter('seguidor_id', requesterIds);

          for (var row in (conexoesRes as List)) {
            final sId = row['seguidor_id'] as String?;
            if (sId != null) activePendingRequesterIds.add(sId);
          }
        } catch (_) {}
      }

      // Collect post IDs for thumbnails
      final postIds =
          data
              .where((n) => n['post_id'] != null)
              .map((n) => n['post_id'] as String)
              .toSet()
              .toList();

      Map<String, String> postThumbnails = {};
      Map<String, String> postOwners = {};
      if (postIds.isNotEmpty) {
        try {
          final postsResponse = await _supabaseClient
              .from('posts')
              .select('id, imagens, user_id')
              .inFilter('id', postIds);

          for (var post in (postsResponse as List)) {
            final imgs = post['imagens'] as List?;
            if (imgs != null && imgs.isNotEmpty) {
              postThumbnails[post['id']] = imgs.first as String;
            }
            postOwners[post['id']] = post['user_id'] as String;
          }
        } catch (_) {}
      }

      final notifications =
          data
              .map((json) {
                final model = NotificationModel.fromJson(json);
                final solicitanteId = json['solicitacao_user_id'] as String?;
                final profile =
                    solicitanteId != null ? profilesMap[solicitanteId] : null;

                final postId = json['post_id'] as String?;
                final postThumbnail =
                    postId != null ? postThumbnails[postId] : null;
                final postOwnerId = postId != null ? postOwners[postId] : null;

                final isPendingFollow = solicitanteId != null && activePendingRequesterIds.contains(solicitanteId);
                final isRespondida = (json['solicitacaorespondida'] as bool? ?? false) ||
                    (model.toEntity().type == NotificationType.follow && !isPendingFollow);

                return model
                    .copyWith(
                      userName: profile?['nome'],
                      userAvatar: profile?['foto'],
                    )
                    .toEntity()
                    .copyWith(
                      postImage: postThumbnail,
                      postOwnerId: postOwnerId,
                      solicitacaoRespondida: isRespondida,
                    );
              })
              .where((n) => n.type != NotificationType.message && n.batepapoId == null)
              .toList();

      // Cache
      await _saveNotificationsToCache(notifications);

      return Right(notifications);
    } catch (e) {
      // Try cache
      final cached = await _getNotificationsFromCache();
      if (cached.isNotEmpty) {
        return Right(cached);
      }
      return Left(Exception('Erro ao buscar notificações: $e'));
    }
  }

  @override
  Future<Either<Exception, Unit>> markAsRead(String notificationId) async {
    try {
      await _supabaseClient
          .from('notificacoes')
          .update({'lido': true})
          .eq('id', notificationId);
      return const Right(unit);
    } catch (e) {
      return Left(Exception('Erro ao marcar como lida: $e'));
    }
  }

  @override
  Future<Either<Exception, Unit>> markAllAsRead() async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) return Left(Exception('Usuário não autenticado'));

      await _supabaseClient
          .from('notificacoes')
          .update({'lido': true})
          .eq('user_id', userId)
          .eq('lido', false);
      return const Right(unit);
    } catch (e) {
      return Left(Exception('Erro ao marcar todas como lidas: $e'));
    }
  }

  @override
  Future<Either<Exception, Unit>> respondFollowRequest(
    String userId,
    bool accept,
  ) async {
    try {
      final currentUserId = _supabaseClient.auth.currentUser?.id;
      if (currentUserId == null)
        return Left(Exception('Usuário não autenticado'));

      if (accept) {
        await _supabaseClient.from('conexoes').update({'aprovou': true}).match({
          'seguidor_id': userId,
          'seguido_id': currentUserId,
        });
      } else {
        await _supabaseClient.from('conexoes').delete().match({
          'seguidor_id': userId,
          'seguido_id': currentUserId,
        });
      }

      // Update notification status if exists
      await _supabaseClient
          .from('notificacoes')
          .update({'solicitacaorespondida': true, 'lido': true})
          .match({'solicitacao_user_id': userId, 'user_id': currentUserId});

      return const Right(unit);
    } catch (e) {
      return Left(Exception('Erro ao responder solicitação: $e'));
    }
  }

  @override
  Future<Either<Exception, Unit>> sendGroupNotification({
    required String groupId,
    required String title,
    required String message,
    List<String>? destinatarios,
  }) async {
    try {
      final currentUserId = _supabaseClient.auth.currentUser?.id;
      if (currentUserId == null) {
        return Left(Exception('Usuário não autenticado'));
      }

      // Fetch Mission ID
      final groupRes = await _supabaseClient
          .from('grupos')
          .select('missao_id')
          .eq('id', groupId)
          .maybeSingle();
      final missaoId = groupRes?['missao_id'] as String?;

      Set<String> allUserIds;

      if (destinatarios != null && destinatarios.isNotEmpty) {
        // Destinatários específicos selecionados pelo guia
        allUserIds = destinatarios.toSet();
        allUserIds.remove(currentUserId);
      } else {
        // Todos os participantes + líderes do grupo
        final participantsRes = await _supabaseClient
            .from('gruposParticipantes')
            .select('user_id')
            .eq('grupo_id', groupId);
        final participantIds =
            (participantsRes as List).map((e) => e['user_id'] as String).toSet();

        final leadersRes = await _supabaseClient
            .from('lideresGrupo')
            .select('lider_id')
            .eq('grupo_id', groupId);
        final leaderIds =
            (leadersRes as List).map((e) => e['lider_id'] as String).toSet();

        allUserIds = {...participantIds, ...leaderIds};
        allUserIds.remove(currentUserId);
      }

      if (allUserIds.isEmpty) {
        return const Right(unit);
      }

      // Inserir notificações (trigger existente dispara o push)
      final notifications = allUserIds.map((userId) {
        return {
          'user_id': userId,
          'grupo_id': groupId,
          'missao_id': missaoId,
          'titulo': title,
          'assunto': title,
          'mensagem': message,
          'lido': false,
        };
      }).toList();

      await _supabaseClient.from('notificacoes').insert(notifications);

      // Registrar no histórico de lembretes
      await _supabaseClient.from('lembretes').insert({
        'grupo_id': groupId,
        'missao_id': missaoId,
        'criado_por': currentUserId,
        'titulo': title,
        'mensagem': message,
        'destinatarios': destinatarios, // null = todos
        'total_destinatarios': allUserIds.length,
        'status': 'enviado',
      });

      return const Right(unit);
    } catch (e) {
      return Left(Exception('Erro ao enviar notificação para o grupo: $e'));
    }
  }

  @override
  Future<Either<Exception, List<ParticipanteEntity>>> getGrupoParticipantes(
    String groupId,
  ) async {
    try {
      // Participantes
      final participantsRes = await _supabaseClient
          .from('gruposParticipantes')
          .select('user_id')
          .eq('grupo_id', groupId);
      final participantIds =
          (participantsRes as List).map((e) => e['user_id'] as String).toList();

      // Líderes
      final leadersRes = await _supabaseClient
          .from('lideresGrupo')
          .select('lider_id')
          .eq('grupo_id', groupId);
      final leaderIds =
          (leadersRes as List).map((e) => e['lider_id'] as String).toSet();

      // Usuário logado
      final currentUserId = _supabaseClient.auth.currentUser?.id;

      // Todos os IDs únicos (exceto o próprio guia logado)
      final allIds = {...participantIds, ...leaderIds};
      allIds.remove(currentUserId);

      if (allIds.isEmpty) return const Right([]);

      final usersRes = await _supabaseClient
          .from('users')
          .select('id, nome, foto')
          .inFilter('id', allIds.toList());

      final participantes = (usersRes as List).map((u) {
        return ParticipanteEntity(
          id: u['id'] as String,
          nome: u['nome'] as String? ?? 'Sem nome',
          foto: u['foto'] as String?,
          isGuia: leaderIds.contains(u['id']),
        );
      }).toList()
        ..sort((a, b) => a.nome.compareTo(b.nome));

      return Right(participantes);
    } catch (e) {
      return Left(Exception('Erro ao buscar participantes: $e'));
    }
  }

  @override
  Future<Either<Exception, List<LembreteEntity>>> getLembretesHistorico(
    String groupId,
  ) async {
    try {
      final currentUserId = _supabaseClient.auth.currentUser?.id;
      if (currentUserId == null) return Left(Exception('Não autenticado'));

      // Agendados primeiro (por agendado_para ASC), depois enviados (created_at DESC)
      final res = await _supabaseClient
          .from('lembretes')
          .select()
          .eq('grupo_id', groupId)
          .eq('criado_por', currentUserId)
          .neq('status', 'cancelado')
          .order('created_at', ascending: false);

      final lembretes = (res as List).map((json) {
        final destinatariosRaw = json['destinatarios'];
        List<String>? destinatarios;
        if (destinatariosRaw is List) {
          destinatarios = destinatariosRaw.map((e) => e.toString()).toList();
        }
        return LembreteEntity(
          id: json['id'] as String,
          grupoId: json['grupo_id'] as String,
          missaoId: json['missao_id'] as String?,
          criadoPor: json['criado_por'] as String,
          titulo: json['titulo'] as String,
          mensagem: json['mensagem'] as String,
          destinatarios: destinatarios,
          totalDestinatarios: (json['total_destinatarios'] as int?) ?? 0,
          status: json['status'] as String? ?? 'enviado',
          createdAt: DateTime.parse(json['created_at'] as String),
          agendadoPara: json['agendado_para'] != null
              ? DateTime.parse(json['agendado_para'] as String)
              : null,
          processadoEm: json['processado_em'] != null
              ? DateTime.parse(json['processado_em'] as String)
              : null,
        );
      }).toList();

      // Ordena: agendados primeiro (por agendado_para), depois enviados (por created_at)
      lembretes.sort((a, b) {
        if (a.isAgendado && !b.isAgendado) return -1;
        if (!a.isAgendado && b.isAgendado) return 1;
        if (a.isAgendado && b.isAgendado) {
          return (a.agendadoPara ?? a.createdAt)
              .compareTo(b.agendadoPara ?? b.createdAt);
        }
        return b.createdAt.compareTo(a.createdAt);
      });

      return Right(lembretes);
    } catch (e) {
      return Left(Exception('Erro ao buscar histórico: $e'));
    }
  }

  // ── Etapa 2: Agendamento ──────────────────────────────────────────────────

  @override
  Future<Either<Exception, Unit>> agendarLembrete({
    required String groupId,
    required String title,
    required String message,
    required DateTime agendadoPara,
    List<String>? destinatarios,
  }) async {
    try {
      final currentUserId = _supabaseClient.auth.currentUser?.id;
      if (currentUserId == null) return Left(Exception('Não autenticado'));

      final groupRes = await _supabaseClient
          .from('grupos')
          .select('missao_id')
          .eq('id', groupId)
          .maybeSingle();
      final missaoId = groupRes?['missao_id'] as String?;

      // Calcula o total de destinatários para exibir no histórico
      int totalDest = 0;
      if (destinatarios != null) {
        totalDest = destinatarios.length;
      } else {
        // Conta participantes + líderes (exceto o guia)
        final pRes = await _supabaseClient
            .from('gruposParticipantes')
            .select('user_id')
            .eq('grupo_id', groupId);
        final lRes = await _supabaseClient
            .from('lideresGrupo')
            .select('lider_id')
            .eq('grupo_id', groupId);
        final ids = {
          ...(pRes as List).map((e) => e['user_id'] as String),
          ...(lRes as List).map((e) => e['lider_id'] as String),
        }..remove(currentUserId);
        totalDest = ids.length;
      }

      await _supabaseClient.from('lembretes').insert({
        'grupo_id': groupId,
        'missao_id': missaoId,
        'criado_por': currentUserId,
        'titulo': title,
        'mensagem': message,
        'destinatarios': destinatarios,
        'total_destinatarios': totalDest,
        'status': 'agendado',
        'agendado_para': agendadoPara.toUtc().toIso8601String(),
      });

      return const Right(unit);
    } catch (e) {
      return Left(Exception('Erro ao agendar lembrete: $e'));
    }
  }

  @override
  Future<Either<Exception, Unit>> cancelarLembrete(String lembreteId) async {
    try {
      await _supabaseClient
          .from('lembretes')
          .update({'status': 'cancelado'})
          .eq('id', lembreteId);
      return const Right(unit);
    } catch (e) {
      return Left(Exception('Erro ao cancelar lembrete: $e'));
    }
  }

  @override
  Future<Either<Exception, Unit>> atualizarHorarioLembrete(
    String lembreteId,
    DateTime novoHorario,
  ) async {
    try {
      await _supabaseClient
          .from('lembretes')
          .update({'agendado_para': novoHorario.toUtc().toIso8601String()})
          .eq('id', lembreteId);
      return const Right(unit);
    } catch (e) {
      return Left(Exception('Erro ao atualizar horário: $e'));
    }
  }

  @override
  Future<Either<Exception, Unit>> editarLembrete({
    required String lembreteId,
    required String mensagem,
    required DateTime agendadoPara,
    List<String>? destinatarios,
    required int totalDestinatarios,
  }) async {
    try {
      await _supabaseClient
          .from('lembretes')
          .update({
            'mensagem': mensagem,
            'agendado_para': agendadoPara.toUtc().toIso8601String(),
            'destinatarios': destinatarios,
            'total_destinatarios': totalDestinatarios,
          })
          .eq('id', lembreteId);
      return const Right(unit);
    } catch (e) {
      return Left(Exception('Erro ao editar lembrete: $e'));
    }
  }

  @override
  Future<Either<Exception, Unit>> enviarLembreteAgora(String lembreteId) async {
    try {
      await _supabaseClient.rpc(
        'send_lembrete_now',
        params: {'p_lembrete_id': lembreteId},
      );
      return const Right(unit);
    } catch (e) {
      return Left(Exception('Erro ao enviar lembrete: $e'));
    }
  }
}






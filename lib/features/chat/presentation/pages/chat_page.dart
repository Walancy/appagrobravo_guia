import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:agrobravo/core/components/app_header.dart';
import 'package:agrobravo/core/components/documents_alert_card.dart';
import 'package:agrobravo/core/constants/translations.dart';
import 'package:agrobravo/core/di/injection.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/tokens/app_spacing.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/features/chat/domain/entities/chat_entity.dart';
import 'package:agrobravo/features/chat/domain/repositories/chat_repository.dart';
import 'package:agrobravo/features/chat/presentation/pages/chat_detail_page.dart';
import 'package:agrobravo/features/chat/presentation/pages/individual_chat_page.dart';
import 'package:agrobravo/features/documents/presentation/cubit/documents_cubit.dart';
import 'package:agrobravo/features/documents/presentation/cubit/documents_state.dart';

// ─── Mission info model ────────────────────────────────────────────────────────
class _MissionInfo {
  final String name;
  final String? logo;
  _MissionInfo({required this.name, this.logo});
}



class ChatPage extends StatefulWidget {
  final String? groupId;
  final ValueChanged<bool>? onUnreadChanged;

  const ChatPage({super.key, this.groupId, this.onUnreadChanged});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _repo = getIt<ChatRepository>();
  final _supabase = Supabase.instance.client;

  // Data
  List<TravelerInfo> _allTravelers = [];
  List<GuideInfo> _guides = [];
  List<ChatEntity> _allGroups = [];

  // Mission info map (for BottomSheet photos)
  final Map<String, _MissionInfo> _missionInfoMap = {};

  // Last messages — updated in real-time
  Map<String, String> _lastMessages = {};
  Map<String, DateTime> _lastMessageTimes = {};

  // chat-id → entity-id reverse lookup (for real-time updates)
  final Map<String, String> _batePapoToEntityId = {};

  // Group images map (groupId -> imageUrl)
  final Map<String, String?> _groupImageMap = {};

  // Unread counts per entity-id
  final Map<String, int> _unreadCounts = {};

  // Last-visit timestamps (loaded from SharedPreferences)
  Map<String, DateTime> _lastVisit = {};

  // Real-time subscription
  RealtimeChannel? _realtimeChannel;

  // Loading/error
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLastVisits().then((_) => _loadAll());
  }

  Future<void> _loadLastVisits() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      final map = <String, DateTime>{};

      // 1. Carregar localmente do SharedPreferences como fallback
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where(
        (k) => k.startsWith('chat_last_visit_'),
      );
      for (final k in keys) {
        final val = prefs.getString(k);
        if (val != null) {
          final dt = DateTime.parse(val);
          map[k.replaceFirst('chat_last_visit_', '')] =
              dt.isUtc ? dt : dt.toUtc();
        }
      }

      // 2. Buscar do Supabase (batepapo_leituras)
      if (currentUserId != null) {
        final reads = await _supabase
            .from('batepapo_leituras')
            .select('batepapo_id, last_read_at')
            .eq('user_id', currentUserId);

        for (final row in reads) {
          final bpId = row['batepapo_id'] as String?;
          final lastReadStr = row['last_read_at'] as String?;
          if (bpId != null && lastReadStr != null) {
            final dt = DateTime.parse(lastReadStr).toUtc();
            map['bp_$bpId'] = dt;
          }
        }
      }

      _lastVisit = map;
    } catch (e) {
      debugPrint('[ChatPage] _loadLastVisits ERRO: $e');
    }
  }

  void _notifyUnreadStatus() {
    final hasUnread = _unreadCounts.values.any((c) => c > 0);
    widget.onUnreadChanged?.call(hasUnread);
  }

  Future<void> _markAsRead(String entityId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      final now = DateTime.now().toUtc();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('chat_last_visit_$entityId', now.toIso8601String());

      if (mounted) {
        setState(() {
          _lastVisit[entityId] = now;
          _unreadCounts[entityId] = 0;
        });
        _notifyUnreadStatus();
      }

      // Persistir no Supabase na tabela batepapo_leituras
      if (currentUserId != null) {
        String? batePapoId;
        for (final entry in _batePapoToEntityId.entries) {
          if (entry.value == entityId) {
            batePapoId = entry.key;
            break;
          }
        }

        if (batePapoId != null) {
          await _supabase.from('batepapo_leituras').upsert({
            'user_id': currentUserId,
            'batepapo_id': batePapoId,
            'last_read_at': now.toIso8601String(),
          });
        }
      }
    } catch (e) {
      debugPrint('[ChatPage] _markAsRead ERRO: $e');
    }
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  // ─── Data loading ────────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint('[ChatPage] _loadAll iniciando — groupId=${widget.groupId}');

      final results = await Future.wait([
        _repo.getAllTravelers(),
        _repo.getGuideInfos(),
        _repo.getAllGroups(),
      ]);

      final travelers = results[0].fold(
        (e) {
          debugPrint('[ChatPage] getAllTravelers ERRO: $e');
          return <TravelerInfo>[];
        },
        (l) => List<TravelerInfo>.from(l as List),
      );
      final guides = results[1].fold(
        (e) {
          debugPrint('[ChatPage] getGuideInfos ERRO: $e');
          return <GuideInfo>[];
        },
        (l) => List<GuideInfo>.from(l as List),
      );
      final groups = results[2].fold(
        (e) {
          debugPrint('[ChatPage] getAllGroups ERRO: $e');
          return <ChatEntity>[];
        },
        (l) => List<ChatEntity>.from(l as List),
      );

      debugPrint('[ChatPage] dados carregados — travelers=${travelers.length}, guides=${guides.length}, groups=${groups.length}');

      // Ensure active groupId is present in groups list
      if (widget.groupId != null && !groups.any((g) => g.id == widget.groupId)) {
        try {
          final gRes = await _supabase
              .from('grupos')
              .select('id, nome, missao_id')
              .eq('id', widget.groupId!)
              .maybeSingle();
          if (gRes != null) {
            String missionName = '';
            final missaoId = gRes['missao_id'] as String?;
            if (missaoId != null) {
              try {
                final mRes = await _supabase
                    .from('missoes')
                    .select('nome')
                    .eq('id', missaoId)
                    .maybeSingle();
                missionName = mRes?['nome'] as String? ?? '';
              } catch (_) {}
            }
            groups.add(
              ChatEntity(
                id: widget.groupId!,
                title: gRes['nome'] as String? ?? 'Grupo da Missão',
                subtitle: missionName,
                unreadCount: 0,
              ),
            );
          } else {
            groups.add(
              ChatEntity(
                id: widget.groupId!,
                title: 'Grupo da Missão',
                subtitle: '',
                unreadCount: 0,
              ),
            );
          }
        } catch (e) {
          debugPrint('[ChatPage] erro ao buscar grupo fallback: $e');
          groups.add(
            ChatEntity(
              id: widget.groupId!,
              title: 'Grupo da Missão',
              subtitle: '',
              unreadCount: 0,
            ),
          );
        }
      }

      // Fetch all guides for active groups to ensure guides are always populated
      final groupIdsToFetchGuides = groups.map((g) => g.id).toSet();
      if (widget.groupId != null) groupIdsToFetchGuides.add(widget.groupId!);

      if (groupIdsToFetchGuides.isNotEmpty) {
        try {
          final currentUserId = _supabase.auth.currentUser?.id;
          final leadersRes = await _supabase
              .from('lideresGrupo')
              .select('lider_id, grupo_id')
              .inFilter('grupo_id', groupIdsToFetchGuides.toList());

          // Map leader_id -> groupIds, groupNames, missionNames
          final Map<String, List<String>> leaderGroupIdsMap = {};
          final Map<String, List<String>> leaderGroupNamesMap = {};
          final Map<String, Set<String>> leaderMissionNamesMap = {};

          for (final l in leadersRes as List) {
            final lid = l['lider_id'] as String?;
            final gid = l['grupo_id'] as String?;
            if (lid != null && gid != null) {
              leaderGroupIdsMap.putIfAbsent(lid, () => []);
              if (!leaderGroupIdsMap[lid]!.contains(gid)) {
                leaderGroupIdsMap[lid]!.add(gid);
              }

              final matchingGroup = groups.firstWhere(
                (g) => g.id == gid,
                orElse: () => ChatEntity(id: gid, title: 'Grupo', subtitle: ''),
              );
              if (matchingGroup.title.isNotEmpty) {
                leaderGroupNamesMap.putIfAbsent(lid, () => []);
                if (!leaderGroupNamesMap[lid]!.contains(matchingGroup.title)) {
                  leaderGroupNamesMap[lid]!.add(matchingGroup.title);
                }
              }
              if (matchingGroup.subtitle.isNotEmpty) {
                leaderMissionNamesMap.putIfAbsent(lid, () => {});
                leaderMissionNamesMap[lid]!.add(matchingGroup.subtitle);
              }
            }
          }

          final leaderIds = leaderGroupIdsMap.keys
              .where((id) => id != currentUserId)
              .toSet();

          if (leaderIds.isNotEmpty) {
            final usersRes = await _supabase
                .from('users')
                .select('id, nome, foto, cargo')
                .inFilter('id', leaderIds.toList());

            for (final u in usersRes as List) {
              final uid = u['id'] as String?;
              if (uid == null) continue;

              final gIds = leaderGroupIdsMap[uid] ?? [];
              final gNames = leaderGroupNamesMap[uid] ?? [];
              final mNames = leaderMissionNamesMap[uid] ?? {};

              final existingIdx = guides.indexWhere((g) => g.id == uid);
              if (existingIdx >= 0) {
                final existing = guides[existingIdx];
                final updatedGroupIds = {...existing.groupIds, ...gIds}.toList();
                final updatedGroupNames = {...existing.groupNames, ...gNames}.toList();
                final updatedMissionNames = {...existing.missionNames, ...mNames};
                guides[existingIdx] = GuideInfo(
                  id: existing.id,
                  name: existing.name,
                  role: existing.role,
                  avatarUrl: existing.avatarUrl,
                  groupIds: updatedGroupIds,
                  groupNames: updatedGroupNames,
                  missionNames: updatedMissionNames,
                );
              } else {
                guides.add(
                  GuideInfo(
                    id: uid,
                    name: u['nome'] as String? ?? 'Guia',
                    role: u['cargo'] as String? ?? 'Guia da Missão',
                    avatarUrl: u['foto'] as String?,
                    groupIds: gIds,
                    groupNames: gNames,
                    missionNames: mNames,
                  ),
                );
              }
            }
          }
        } catch (e) {
          debugPrint('[ChatPage] erro ao buscar líderes extras: $e');
        }
      }

      // Build mission info map from groups
      final missionInfoMap = <String, _MissionInfo>{};
      for (final g in groups) {
        if (g.subtitle.isNotEmpty && !missionInfoMap.containsKey(g.subtitle)) {
          missionInfoMap[g.subtitle] = _MissionInfo(
            name: g.subtitle,
            logo: null,
          );
        }
      }

      // Fetch mission logos from Supabase by name
      if (missionInfoMap.isNotEmpty) {
        try {
          final missionNames = missionInfoMap.keys.toList();
          final missionsRes = await _supabase
              .from('missoes')
              .select('nome, logo')
              .inFilter('nome', missionNames);
          for (final m in missionsRes as List) {
            final nome = m['nome'] as String?;
            final logo = m['logo'] as String?;
            if (nome != null && missionInfoMap.containsKey(nome)) {
              missionInfoMap[nome] = _MissionInfo(name: nome, logo: logo);
            }
          }
        } catch (e) {
          debugPrint('[ChatPage] erro ao buscar logos de missão: $e');
        }
      }

      // Also add mission info from travelers
      for (final t in travelers) {
        if (t.missionName.isNotEmpty &&
            !missionInfoMap.containsKey(t.missionName)) {
          missionInfoMap[t.missionName] = _MissionInfo(
            name: t.missionName,
            logo: t.missionLogo,
          );
        }
      }

      // Fetch last messages for travelers, guides and groups
      final msgs = <String, String>{};
      final times = <String, DateTime>{};
      final batePapoMap = <String, String>{};

      await Future.wait([
        ...travelers.map(
          (t) => _fetchLastMessage(t.id, false, msgs, times, batePapoMap),
        ),
        ...guides.map(
          (g) => _fetchLastMessage(g.id, false, msgs, times, batePapoMap),
        ),
        ...groups.map(
          (g) => _fetchLastMessage(g.id, true, msgs, times, batePapoMap),
        ),
      ]);

      if (mounted) {
        setState(() {
          _allTravelers = travelers;
          _guides = guides;
          _allGroups = groups;
          _missionInfoMap
            ..clear()
            ..addAll(missionInfoMap);
          _lastMessages = msgs;
          _lastMessageTimes = times;
          _batePapoToEntityId.addAll(batePapoMap);
          _groupImageMap.clear();
          for (final g in groups) {
            _groupImageMap[g.id] = g.imageUrl;
          }
          _isLoading = false;
        });
      }

      _subscribeToMessages();
      _notifyUnreadStatus();
      debugPrint('[ChatPage] _loadAll concluído com sucesso');
    } catch (e, st) {
      debugPrint('[ChatPage] _loadAll ERRO FATAL: $e');
      debugPrint('[ChatPage] StackTrace: $st');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchLastMessage(
    String entityId,
    bool isGroup,
    Map<String, String> msgs,
    Map<String, DateTime> times,
    Map<String, String> batePapoMap,
  ) async {
    try {
      String? batePapoId;
      if (isGroup) {
        final res =
            await _supabase
                .from('batePapo')
                .select('id')
                .eq('grupo_id', entityId)
                .maybeSingle();
        batePapoId = res?['id'] as String?;
      } else {
        final userId = _supabase.auth.currentUser?.id;
        if (userId == null) return;
        final res =
            await _supabase
                .from('batePapo')
                .select('id')
                .or(
                  'and(lider_id.eq.$entityId,user_id.eq.$userId,grupo_id.is.null),and(lider_id.eq.$userId,user_id.eq.$entityId,grupo_id.is.null)',
                )
                .maybeSingle();
        batePapoId = res?['id'] as String?;
      }

      if (batePapoId == null) return;
      batePapoMap[batePapoId] = entityId;

      // Fetch last message
      final currentUserId = _supabase.auth.currentUser?.id;
      final lastVisitForEntity = _lastVisit[entityId] ?? _lastVisit['bp_$batePapoId'];
      if (lastVisitForEntity != null) {
        _lastVisit[entityId] = lastVisitForEntity;
      }

      final msg =
          await _supabase
              .from('mensagens')
              .select('mensagem, created_at')
              .eq('batepapo_id', batePapoId)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

      if (msg != null) {
        msgs[entityId] = msg['mensagem'] as String? ?? '📎 Arquivo';
        if (msg['created_at'] != null) {
          times[entityId] = DateTime.parse(msg['created_at']).toLocal();
        }
      }

      // Unread count
      if (currentUserId != null) {
        try {
          var query = _supabase
              .from('mensagens')
              .select('id')
              .eq('batepapo_id', batePapoId)
              .neq('user_id', currentUserId)
              .eq('deletado', false);

          if (lastVisitForEntity != null) {
            query = query.gt(
              'created_at',
              lastVisitForEntity.toIso8601String(),
            );
          } else {
            // Se o usuário nunca abriu a conversa (primeiro acesso), inicializa no Supabase
            final now = DateTime.now().toUtc();
            _lastVisit[entityId] = now;
            _supabase.from('batepapo_leituras').upsert({
              'user_id': currentUserId,
              'batepapo_id': batePapoId,
              'last_read_at': now.toIso8601String(),
            }).then((_) {}).catchError((_) {});

            if (mounted) {
              setState(() {
                _unreadCounts[entityId] = 0;
              });
              _notifyUnreadStatus();
            }
            return;
          }

          final countResp = await query.count(CountOption.exact);

          if (mounted) {
            setState(() {
              _unreadCounts[entityId] = countResp.count;
            });
            _notifyUnreadStatus();
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  // ─── Real-time ───────────────────────────────────────────────────────────────

  void _subscribeToMessages() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel =
        _supabase
            .channel('chat_page_messages')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'mensagens',
              callback: (payload) {
                final newRow = payload.newRecord;
                final chatId = newRow['batepapo_id'] as String?;
                final text = newRow['mensagem'] as String? ?? 'Imagem/Arquivo';
                final createdAt = newRow['created_at'] as String?;

                if (chatId == null) return;
                final entityId = _batePapoToEntityId[chatId];
                if (entityId == null) {
                  _loadAll();
                  return;
                }

                if (mounted) {
                  setState(() {
                    _lastMessages[entityId] = text;
                    if (createdAt != null) {
                      _lastMessageTimes[entityId] =
                          DateTime.parse(createdAt).toLocal();
                    }
                    // Only increment if the sender is not the current user
                    final senderId = newRow['user_id'] as String?;
                    final myId = _supabase.auth.currentUser?.id;
                    if (senderId != null && senderId != myId) {
                      _unreadCounts[entityId] =
                          (_unreadCounts[entityId] ?? 0) + 1;
                    }
                  });
                  _notifyUnreadStatus();
                }
              },
            )
            .subscribe();
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          // Espaço para não sobrepor a AppBar — padrão do projeto
          const HeaderSpacer(),

          BlocBuilder<DocumentsCubit, DocumentsState>(
            builder: (context, state) {
              if (state.hasPendingDocuments) {
                return const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: DocumentsAlertCard(),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          Expanded(
            child:
                _isLoading
                    ? const _ChatTabSkeleton()
                    : _error != null
                    ? _buildError()
                    : _buildUnifiedList(),
          ),
        ],
      ),
    );
  }

  // ─── Unified List Builder ────────────────────────────────────────────────────

  Widget _buildUnifiedList() {
    // Filter Groups by groupId if provided
    List<ChatEntity> filteredGroups = _allGroups;
    if (widget.groupId != null) {
      filteredGroups = filteredGroups.where((g) => g.id == widget.groupId).toList();
    }

    // Filter Guides by groupId if provided — sem fallback, mostra apenas os do grupo
    List<GuideInfo> filteredGuides = _guides;
    if (widget.groupId != null) {
      filteredGuides = filteredGuides.where((g) => g.groupIds.contains(widget.groupId)).toList();
    }

    // Filter Travelers by groupId if provided — sem fallback
    List<TravelerInfo> filteredTravelers = _allTravelers;
    if (widget.groupId != null) {
      filteredTravelers = filteredTravelers.where((t) => t.groupId == widget.groupId).toList();
    }

    // Helper for sorting items by last message time descending (most recent first)
    int compareByLastMessageTime(String idA, String nameA, String idB, String nameB) {
      final timeA = _lastMessageTimes[idA];
      final timeB = _lastMessageTimes[idB];
      if (timeA != null && timeB != null) {
        return timeB.compareTo(timeA);
      } else if (timeA != null) {
        return -1;
      } else if (timeB != null) {
        return 1;
      } else {
        return nameA.toLowerCase().compareTo(nameB.toLowerCase());
      }
    }

    filteredGroups = List.from(filteredGroups)
      ..sort((a, b) => compareByLastMessageTime(a.id, a.title, b.id, b.title));

    filteredGuides = List.from(filteredGuides)
      ..sort((a, b) => compareByLastMessageTime(a.id, a.name, b.id, b.name));

    filteredTravelers = List.from(filteredTravelers)
      ..sort((a, b) => compareByLastMessageTime(a.id, a.name, b.id, b.name));

    if (filteredGroups.isEmpty && filteredGuides.isEmpty && filteredTravelers.isEmpty) {
      return _buildEmpty(
        context.t('Nenhuma conversa encontrada.', 'No conversations found.'),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // ─── Groups Section ───────────────────────────────────────────────
        if (filteredGroups.isNotEmpty) ...[
          _buildSectionHeader(context.t('Grupo da Missão', 'Mission Group')),
          ...filteredGroups.map((g) => _buildGroupTile(g)),
        ],

        // ─── Guides Section ───────────────────────────────────────────────
        if (filteredGuides.isNotEmpty) ...[
          _buildSectionHeader(context.t('Guias da Missão', 'Mission Guides')),
          ...filteredGuides.map((g) => _buildGuideTile(g)),
        ],

        // ─── Travelers Section ───────────────────────────────────────────
        if (filteredTravelers.isNotEmpty) ...[
          _buildSectionHeader(context.t('Viajantes', 'Travelers')),
          ...filteredTravelers.map((t) => _buildTravelerTile(t)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 14, AppSpacing.md, 6),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.bodySmall.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _buildGroupTile(ChatEntity g) {
    return _ChatListTile(
      id: g.id,
      name: g.title,
      subtitle: _lastMessages[g.id] ?? '',
      imageUrl: g.imageUrl,
      isGroup: true,
      lastTime: _lastMessageTimes[g.id],
      unreadCount: _unreadCounts[g.id] ?? 0,
      onTap: () async {
        _markAsRead(g.id);
        await Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, _, _) => ChatDetailPage(chat: g),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
        _markAsRead(g.id);
      },
    );
  }

  Widget _buildGuideTile(GuideInfo g) {
    final guideEntity = GuideEntity(
      id: g.id,
      name: g.name,
      role: g.role,
      avatarUrl: g.avatarUrl,
    );
    return _ChatListTile(
      id: g.id,
      name: g.name,
      subtitle: _lastMessages[g.id] ?? g.role,
      imageUrl: g.avatarUrl,
      isGroup: false,
      lastTime: _lastMessageTimes[g.id],
      unreadCount: _unreadCounts[g.id] ?? 0,
      onTap: () async {
        _markAsRead(g.id);
        await Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, _, _) => IndividualChatPage(guide: guideEntity),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
        _markAsRead(g.id);
      },
    );
  }

  Widget _buildTravelerTile(TravelerInfo t) {
    final lastMsg = _lastMessages[t.id];
    final lastTime = _lastMessageTimes[t.id];
    return _ChatListTile(
      id: t.id,
      name: t.name,
      subtitle: lastMsg ?? '',
      imageUrl: t.avatarUrl,
      isGroup: false,
      lastTime: lastTime,
      unreadCount: _unreadCounts[t.id] ?? 0,
      onTap: () async {
        _markAsRead(t.id);
        await Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder:
                (_, _, _) => IndividualChatPage(
                  guide: GuideEntity(
                    id: t.id,
                    name: t.name,
                    role: t.role ?? t.groupName,
                    avatarUrl: t.avatarUrl,
                  ),
                ),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
        _markAsRead(t.id);
      },
    );
  }

  // ─── Error ───────────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            context.t('Erro ao carregar', 'Error loading'),
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loadAll,
            child: Text(context.t('Tentar novamente', 'Try again')),
          ),
        ],
      ),
    );
  }


  // ─── Empty ────────────────────────────────────────────────────────────────────

  Widget _buildEmpty(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 12),
            Text(
              msg,
              style: AppTextStyles.bodySmall.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}



// ─── Reusable Chat List Tile ──────────────────────────────────────────────────

class _ChatListTile extends StatelessWidget {
  final String id;
  final String name;
  final String subtitle;
  final String? imageUrl;
  final bool isGroup;
  final DateTime? lastTime;
  final int unreadCount;
  final VoidCallback onTap;

  const _ChatListTile({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.isGroup,
    required this.onTap,
    this.imageUrl,
    this.lastTime,
    this.unreadCount = 0,
  });

  String _formatTime(DateTime date, BuildContext context) {
    final localDate = date.toLocal();
    final now = DateTime.now();
    if (now.day == localDate.day &&
        now.month == localDate.month &&
        now.year == localDate.year) {
      return DateFormat('HH:mm').format(localDate);
    } else if (now.difference(localDate).inDays < 2 &&
        now.day != localDate.day) {
      return context.t('Ontem', 'Yesterday');
    } else {
      return DateFormat('dd/MM').format(localDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 10,
        ),
        child: Row(
          children: [
            // Avatar with unread badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.08),
                  backgroundImage:
                      imageUrl != null
                          ? CachedNetworkImageProvider(imageUrl!)
                          : null,
                  child:
                      imageUrl == null
                          ? Icon(
                            isGroup
                                ? Icons.group_rounded
                                : Icons.person_rounded,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.4),
                          )
                          : null,
                ),
                if (hasUnread)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight:
                                hasUnread ? FontWeight.w700 : FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (lastTime != null)
                        Text(
                          _formatTime(lastTime!, context),
                          style: AppTextStyles.bodySmall.copyWith(
                            color:
                                hasUnread
                                    ? const Color(0xFF25D366)
                                    : Colors.grey,
                            fontSize: 11,
                            fontWeight:
                                hasUnread ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subtitle,
                          style: AppTextStyles.bodySmall.copyWith(
                            color:
                                hasUnread
                                    ? Theme.of(context).colorScheme.onSurface
                                        .withValues(alpha: 0.85)
                                    : AppColors.textSecondary,
                            fontWeight:
                                hasUnread ? FontWeight.w600 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Chat Tab Skeleton ────────────────────────────────────────────────────────

class _ChatTabSkeleton extends StatefulWidget {
  const _ChatTabSkeleton();

  @override
  State<_ChatTabSkeleton> createState() => _ChatTabSkeletonState();
}

class _ChatTabSkeletonState extends State<_ChatTabSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final baseColor =
            isDark
                ? Color.lerp(
                  const Color(0xFF2A2A2A),
                  const Color(0xFF3A3A3A),
                  _animation.value,
                )!
                : Color.lerp(
                  const Color(0xFFE8E8E8),
                  const Color(0xFFF5F5F5),
                  _animation.value,
                )!;

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: 8,
          physics: const NeverScrollableScrollPhysics(),
          separatorBuilder:
              (_, _) => Divider(
                height: 1,
                indent: 72,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.03),
              ),
          itemBuilder:
              (_, _) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // Avatar placeholder
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: baseColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name line
                          Container(
                            height: 13,
                            width: 120,
                            decoration: BoxDecoration(
                              color: baseColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Message line
                          Container(
                            height: 11,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: baseColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Time placeholder
                    Container(
                      height: 10,
                      width: 28,
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
        );
      },
    );
  }
}

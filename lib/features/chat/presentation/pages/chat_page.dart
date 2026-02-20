import 'dart:async';

import 'package:agrobravo/core/di/injection.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/tokens/app_spacing.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/features/chat/domain/entities/chat_entity.dart';
import 'package:agrobravo/features/chat/domain/repositories/chat_repository.dart';
import 'package:agrobravo/features/chat/presentation/pages/chat_detail_page.dart';
import 'package:agrobravo/features/chat/presentation/pages/individual_chat_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Mission info model ────────────────────────────────────────────────────────
class _MissionInfo {
  final String name;
  final String? logo;
  _MissionInfo({required this.name, this.logo});
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
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
  Map<String, int> _unreadCounts = {};

  // Last-visit timestamps (loaded from SharedPreferences)
  Map<String, DateTime> _lastVisit = {};

  // Real-time subscription
  RealtimeChannel? _realtimeChannel;

  // Loading/error
  bool _isLoading = true;
  String? _error;

  // Travelers tab filters
  String? _travelerMissionFilter;
  String? _travelerGroupFilter;

  // Groups tab filter
  String? _selectedMissionFilter;

  // Guides tab filters
  String? _guideMissionFilter;
  String? _guideGroupFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadLastVisits().then((_) => _loadAll());
  }

  Future<void> _loadLastVisits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where(
        (k) => k.startsWith('chat_last_visit_'),
      );
      final map = <String, DateTime>{};
      for (final k in keys) {
        final val = prefs.getString(k);
        if (val != null) {
          final dt = DateTime.parse(val);
          map[k.replaceFirst('chat_last_visit_', '')] =
              dt.isUtc ? dt : dt.toUtc();
        }
      }
      _lastVisit = map;
    } catch (_) {}
  }

  Future<void> _markAsRead(String entityId) async {
    try {
      final now = DateTime.now().toUtc();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('chat_last_visit_$entityId', now.toIso8601String());
      if (mounted) {
        setState(() {
          _lastVisit[entityId] = now;
          _unreadCounts[entityId] = 0;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  void _onTabChanged() => setState(() {});

  // ─── Data loading ────────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _repo.getAllTravelers(),
        _repo.getGuideInfos(),
        _repo.getAllGroups(),
      ]);

      final travelers = results[0].fold(
        (e) => <TravelerInfo>[],
        (l) => l as List<TravelerInfo>,
      );
      final guides = results[1].fold(
        (e) => <GuideInfo>[],
        (l) => l as List<GuideInfo>,
      );
      final groups = results[2].fold(
        (e) => <ChatEntity>[],
        (l) => l as List<ChatEntity>,
      );

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
        } catch (_) {}
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
    } catch (e) {
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
      final lastVisitForEntity = _lastVisit[entityId];

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
          times[entityId] = DateTime.parse(msg['created_at']);
        }
      }

      // Unread count — only if user has visited before
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
          }

          final countResp = await query.count(CountOption.exact);

          if (mounted) {
            setState(() {
              _unreadCounts[entityId] = countResp.count ?? 0;
            });
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
                      _lastMessageTimes[entityId] = DateTime.parse(createdAt);
                    }
                    // Only increment if the sender is not the current user
                    final senderId = newRow['user_id'] as String?;
                    final myId = _supabase.auth.currentUser?.id;
                    if (senderId != null && senderId != myId) {
                      _unreadCounts[entityId] =
                          (_unreadCounts[entityId] ?? 0) + 1;
                    }
                  });
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
          SafeArea(
            bottom: false,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
              labelStyle: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              unselectedLabelStyle: AppTextStyles.bodySmall.copyWith(
                fontSize: 13,
              ),
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Viajantes'),
                Tab(text: 'Guias'),
                Tab(text: 'Grupos'),
              ],
            ),
          ),

          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? _buildError()
                    : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTravelersList(),
                        _buildGuidesList(),
                        _buildGroupsList(),
                      ],
                    ),
          ),
        ],
      ),
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
          Text('Erro ao carregar', style: AppTextStyles.bodyMedium),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loadAll,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  // ─── Viajantes tab ───────────────────────────────────────────────────────────

  Widget _buildTravelersList() {
    // Unique missions and groups for filter
    final missions = <String>{};
    for (final t in _allTravelers) {
      if (t.missionName.isNotEmpty) missions.add(t.missionName);
    }

    // Groups available for the selected mission (or all)
    final availableGroups = <String, String>{}; // groupId → groupName
    for (final t in _allTravelers) {
      if (_travelerMissionFilter == null ||
          t.missionName == _travelerMissionFilter) {
        availableGroups[t.groupId] = t.groupName;
      }
    }

    // Filter travelers
    List<TravelerInfo> filtered = _allTravelers;
    if (_travelerMissionFilter != null) {
      filtered =
          filtered
              .where((t) => t.missionName == _travelerMissionFilter)
              .toList();
    }
    if (_travelerGroupFilter != null) {
      filtered =
          filtered.where((t) => t.groupId == _travelerGroupFilter).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter row
        if (missions.isNotEmpty || availableGroups.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              10,
              AppSpacing.md,
              6,
            ),
            child: Row(
              children: [
                // Mission filter
                _FilterButton(
                  label: _travelerMissionFilter ?? 'Missão',
                  icon: Icons.map_outlined,
                  isActive: _travelerMissionFilter != null,
                  onTap: () => _showTravelerMissionSheet(missions.toList()),
                ),
                const SizedBox(width: 8),
                // Group filter (only if a mission is selected or there are groups)
                if (availableGroups.isNotEmpty)
                  _FilterButton(
                    label:
                        _travelerGroupFilter != null
                            ? (availableGroups[_travelerGroupFilter] ?? 'Grupo')
                            : 'Grupo',
                    icon: Icons.group_outlined,
                    isActive: _travelerGroupFilter != null,
                    onTap: () => _showTravelerGroupSheet(availableGroups),
                  ),
              ],
            ),
          ),

        Expanded(
          child:
              filtered.isEmpty
                  ? _buildEmpty('Nenhum viajante encontrado.')
                  : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: filtered.length,
                    separatorBuilder:
                        (_, __) => Divider(
                          height: 1,
                          indent: 72,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.06),
                        ),
                    itemBuilder: (context, i) {
                      final t = filtered[i];
                      // Use DM last message if available
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
                        badge:
                            _travelerGroupFilter == null &&
                                    _travelerMissionFilter == null
                                ? t.groupName
                                : null,
                        onTap: () async {
                          _markAsRead(t.id);
                          await Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (_, __, ___) => IndividualChatPage(
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
                    },
                  ),
        ),
      ],
    );
  }

  void _showTravelerMissionSheet(List<String> missions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => _MissionFilterSheet(
            missions: missions,
            missionInfoMap: _missionInfoMap,
            selectedMission: _travelerMissionFilter,
            onSelect: (m) {
              setState(() {
                _travelerMissionFilter = m;
                _travelerGroupFilter = null; // reset group when mission changes
              });
              Navigator.pop(ctx);
            },
          ),
    );
  }

  void _showTravelerGroupSheet(Map<String, String> groups) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.6,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              16,
              AppSpacing.md,
              MediaQuery.of(ctx).padding.bottom + AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Filtrar por grupo',
                  style: AppTextStyles.h3.copyWith(fontSize: 17),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.group_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        title: const Text('Todos os grupos'),
                        trailing:
                            _travelerGroupFilter == null
                                ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.primary,
                                )
                                : null,
                        onTap: () {
                          setState(() => _travelerGroupFilter = null);
                          Navigator.pop(ctx);
                        },
                      ),
                      const Divider(height: 1),
                      ...groups.entries.map(
                        (e) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.07),
                              shape: BoxShape.circle,
                              image:
                                  _groupImageMap[e.key] != null
                                      ? DecorationImage(
                                        image: CachedNetworkImageProvider(
                                          _groupImageMap[e.key]!,
                                        ),
                                        fit: BoxFit.cover,
                                      )
                                      : null,
                            ),
                            child:
                                _groupImageMap[e.key] == null
                                    ? Icon(
                                      Icons.group_outlined,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.45),
                                      size: 22,
                                    )
                                    : null,
                          ),
                          title: Text(
                            e.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing:
                              _travelerGroupFilter == e.key
                                  ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.primary,
                                  )
                                  : null,
                          onTap: () {
                            setState(
                              () =>
                                  _travelerGroupFilter =
                                      _travelerGroupFilter == e.key
                                          ? null
                                          : e.key,
                            );
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  // ─── Guias tab ───────────────────────────────────────────────────────────────

  // ─── Guias tab ───────────────────────────────────────────────────────────────

  Widget _buildGuidesList() {
    if (_guides.isEmpty) return _buildEmpty('Nenhum guia encontrado.');

    // Filters data
    final missions = <String>{};
    final availableGroups = <String, String>{}; // groupId → groupName

    for (final g in _guides) {
      missions.addAll(g.missionNames);
      for (int i = 0; i < g.groupIds.length; i++) {
        if (_guideMissionFilter == null ||
            g.missionNames.contains(_guideMissionFilter)) {
          availableGroups[g.groupIds[i]] = g.groupNames[i];
        }
      }
    }

    // Apply filtering
    List<GuideInfo> filtered = _guides;
    if (_guideMissionFilter != null) {
      filtered =
          filtered
              .where((g) => g.missionNames.contains(_guideMissionFilter))
              .toList();
    }
    if (_guideGroupFilter != null) {
      filtered =
          filtered
              .where((g) => g.groupIds.contains(_guideGroupFilter))
              .toList();
    }

    return Column(
      children: [
        // Filter row
        if (missions.isNotEmpty || availableGroups.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              10,
              AppSpacing.md,
              6,
            ),
            child: Row(
              children: [
                _FilterButton(
                  label: _guideMissionFilter ?? 'Missão',
                  icon: Icons.map_outlined,
                  isActive: _guideMissionFilter != null,
                  onTap: () => _showGuideMissionSheet(missions.toList()),
                ),
                const SizedBox(width: 8),
                if (availableGroups.isNotEmpty)
                  _FilterButton(
                    label:
                        _guideGroupFilter != null
                            ? (availableGroups[_guideGroupFilter] ?? 'Grupo')
                            : 'Grupo',
                    icon: Icons.group_outlined,
                    isActive: _guideGroupFilter != null,
                    onTap: () => _showGuideGroupSheet(availableGroups),
                  ),
              ],
            ),
          ),
        Expanded(
          child:
              filtered.isEmpty
                  ? _buildEmpty(
                    'Nenhum guia encontrado para os filtros selecionados.',
                  )
                  : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: filtered.length,
                    separatorBuilder:
                        (_, __) => Divider(
                          height: 1,
                          indent: 72,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.06),
                        ),
                    itemBuilder: (context, i) {
                      final g = filtered[i];
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
                        badge:
                            g.groupNames.isNotEmpty && _guideGroupFilter == null
                                ? g.groupNames.first
                                : null,
                        onTap: () async {
                          _markAsRead(g.id);
                          await Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (_, __, ___) =>
                                      IndividualChatPage(guide: guideEntity),
                              transitionDuration: Duration.zero,
                              reverseTransitionDuration: Duration.zero,
                            ),
                          );
                          _markAsRead(g.id);
                        },
                      );
                    },
                  ),
        ),
      ],
    );
  }

  void _showGuideMissionSheet(List<String> missions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => _MissionFilterSheet(
            missions: missions,
            missionInfoMap: _missionInfoMap,
            selectedMission: _guideMissionFilter,
            onSelect: (m) {
              setState(() {
                _guideMissionFilter = m;
                _guideGroupFilter = null;
              });
              Navigator.pop(ctx);
            },
          ),
    );
  }

  void _showGuideGroupSheet(Map<String, String> groups) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.6,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              16,
              AppSpacing.md,
              MediaQuery.of(ctx).padding.bottom + AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text('Filtrar por Grupo', style: AppTextStyles.h3),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.group_outlined,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        title: const Text('Todos os grupos'),
                        trailing:
                            _guideGroupFilter == null
                                ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.primary,
                                )
                                : null,
                        onTap: () {
                          setState(() => _guideGroupFilter = null);
                          Navigator.pop(ctx);
                        },
                      ),
                      const Divider(height: 1),
                      ...groups.entries.map(
                        (e) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.07),
                              shape: BoxShape.circle,
                              image:
                                  _groupImageMap[e.key] != null
                                      ? DecorationImage(
                                        image: CachedNetworkImageProvider(
                                          _groupImageMap[e.key]!,
                                        ),
                                        fit: BoxFit.cover,
                                      )
                                      : null,
                            ),
                            child:
                                _groupImageMap[e.key] == null
                                    ? const Icon(
                                      Icons.group_outlined,
                                      color: Colors.grey,
                                      size: 22,
                                    )
                                    : null,
                          ),
                          title: Text(
                            e.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing:
                              _guideGroupFilter == e.key
                                  ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.primary,
                                  )
                                  : null,
                          onTap: () {
                            setState(() => _guideGroupFilter = e.key);
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  // ─── Grupos tab ──────────────────────────────────────────────────────────────

  Widget _buildGroupsList() {
    final missions = <String>{};
    for (final g in _allGroups) {
      if (g.subtitle.isNotEmpty) missions.add(g.subtitle);
    }

    final filtered =
        _selectedMissionFilter == null
            ? _allGroups
            : _allGroups
                .where((g) => g.subtitle == _selectedMissionFilter)
                .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (missions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              10,
              AppSpacing.md,
              6,
            ),
            child: _FilterButton(
              label: _selectedMissionFilter ?? 'Todas as missões',
              icon: Icons.filter_list_rounded,
              isActive: _selectedMissionFilter != null,
              onTap: () => _showMissionFilterSheet(missions.toList()),
            ),
          ),
        Expanded(
          child:
              filtered.isEmpty
                  ? _buildEmpty('Nenhum grupo encontrado.')
                  : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: filtered.length,
                    separatorBuilder:
                        (_, __) => Divider(
                          height: 1,
                          indent: 72,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.06),
                        ),
                    itemBuilder: (context, i) {
                      final g = filtered[i];
                      return _ChatListTile(
                        id: g.id,
                        name: g.title,
                        subtitle: _lastMessages[g.id] ?? '',
                        imageUrl: g.imageUrl,
                        isGroup: true,
                        lastTime: _lastMessageTimes[g.id],
                        unreadCount: _unreadCounts[g.id] ?? 0,
                        badge:
                            g.subtitle.isNotEmpty &&
                                    _selectedMissionFilter == null
                                ? g.subtitle
                                : null,
                        onTap: () async {
                          _markAsRead(g.id);
                          await Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (_, __, ___) => ChatDetailPage(chat: g),
                              transitionDuration: Duration.zero,
                              reverseTransitionDuration: Duration.zero,
                            ),
                          );
                          _markAsRead(g.id);
                        },
                      );
                    },
                  ),
        ),
      ],
    );
  }

  void _showMissionFilterSheet(List<String> missions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => _MissionFilterSheet(
            missions: missions,
            missionInfoMap: _missionInfoMap,
            selectedMission: _selectedMissionFilter,
            onSelect: (m) {
              setState(() => _selectedMissionFilter = m);
              Navigator.pop(ctx);
            },
          ),
    );
  }

  // ─── Empty ────────────────────────────────────────────────────────────────────

  Widget _buildEmpty(String msg) {
    return Center(
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
    );
  }
}

// ─── Filter button ────────────────────────────────────────────────────────────

class _FilterButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isActive
            ? AppColors.primary
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color:
              isActive
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isActive
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.expand_more_rounded, size: 14, color: color),
          ],
        ),
      ),
    );
  }
}

// ─── Mission filter BottomSheet ───────────────────────────────────────────────

class _MissionFilterSheet extends StatelessWidget {
  final List<String> missions;
  final Map<String, _MissionInfo> missionInfoMap;
  final String? selectedMission;
  final void Function(String?) onSelect;

  const _MissionFilterSheet({
    required this.missions,
    required this.missionInfoMap,
    required this.selectedMission,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        16,
        AppSpacing.md,
        MediaQuery.of(context).padding.bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Filtrar por missão',
            style: AppTextStyles.h3.copyWith(fontSize: 17),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.all_inbox_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  title: const Text('Todas as missões'),
                  trailing:
                      selectedMission == null
                          ? const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.primary,
                          )
                          : null,
                  onTap: () => onSelect(null),
                ),
                const Divider(height: 1),
                ...missions.map((m) {
                  final info = missionInfoMap[m];
                  final logoUrl = info?.logo;
                  final isSelected = selectedMission == m;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.08),
                      backgroundImage:
                          logoUrl != null
                              ? CachedNetworkImageProvider(logoUrl)
                              : null,
                      child:
                          logoUrl == null
                              ? Icon(
                                Icons.location_on_outlined,
                                size: 20,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.45),
                              )
                              : null,
                    ),
                    title: Text(
                      m,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppColors.primary : null,
                      ),
                    ),
                    trailing:
                        isSelected
                            ? const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primary,
                            )
                            : null,
                    onTap: () => onSelect(isSelected ? null : m),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable chat tile ───────────────────────────────────────────────────────

class _ChatListTile extends StatelessWidget {
  final String id;
  final String name;
  final String subtitle;
  final String? imageUrl;
  final bool isGroup;
  final DateTime? lastTime;
  final String? badge;
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
    this.badge,
    this.unreadCount = 0,
  });

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    if (now.day == date.day &&
        now.month == date.month &&
        now.year == date.year) {
      return DateFormat('HH:mm').format(date);
    } else if (now.difference(date).inDays < 2 && now.day != date.day) {
      return 'Ontem';
    } else {
      return DateFormat('dd/MM').format(date);
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
          vertical: 12,
        ),
        child: Row(
          children: [
            // Avatar with unread badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[200],
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
                            color: Colors.grey[500],
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
                          _formatTime(lastTime!),
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
                      if (badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge!,
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
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

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agrobravo/features/documents/presentation/cubit/documents_cubit.dart';
import 'package:agrobravo/features/documents/presentation/cubit/documents_state.dart';
import 'package:agrobravo/core/components/documents_alert_card.dart';
import 'package:agrobravo/core/components/app_header.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:agrobravo/core/di/injection.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/features/itinerary/domain/entities/itinerary_group.dart';
import 'package:agrobravo/features/itinerary/domain/entities/itinerary_item.dart';
import 'package:agrobravo/features/itinerary/domain/repositories/itinerary_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:agrobravo/features/home/presentation/widgets/new_post_bottom_sheet.dart';
import 'package:agrobravo/core/tokens/app_spacing.dart';
import 'package:go_router/go_router.dart';
import 'package:agrobravo/features/home/presentation/widgets/reminder_modal.dart';
import 'package:agrobravo/features/home/domain/repositories/dashboard_actions_repository.dart';
import 'package:agrobravo/core/formatters/centavos_input_formatter.dart';
import 'package:agrobravo/core/components/app_text_field.dart';
import 'package:agrobravo/core/constants/translations.dart';

class GuideDashboardPage extends StatefulWidget {
  final String groupId;
  final VoidCallback onSwitchGroup;
  final ValueChanged<int>? onTabChange;
  final ValueChanged<String>? onNavigateToEvent;

  const GuideDashboardPage({
    super.key,
    required this.groupId,
    required this.onSwitchGroup,
    this.onTabChange,
    this.onNavigateToEvent,
  });

  @override
  State<GuideDashboardPage> createState() => _GuideDashboardPageState();
}

class _GuideDashboardPageState extends State<GuideDashboardPage> {
  ItineraryGroupEntity? _group;
  List<ItineraryItemEntity> _upcomingEvents = [];
  List<Map<String, dynamic>> _travelers = [];
  List<Map<String, dynamic>> _guides = [];
  List<Map<String, dynamic>> _filteredTravelers = [];
  List<Map<String, dynamic>> _filteredGuides = [];
  List<String> _requiredDocTypes = [];
  bool _isLoading = true;
  int _selectedMembersTab = 0;

  Map<String, dynamic> _getTravelerDocStatus(List? docs) {
    final hasExpired =
        docs != null &&
        docs.any((d) => d['status']?.toString().toUpperCase() == 'EXPIRADO');
    if (hasExpired) {
      return {
        'label': 'Documento vencido',
        'color': Colors.orangeAccent[700]!,
        'icon': Icon(
          Icons.warning_amber_rounded,
          color: Colors.orangeAccent[700],
          size: 24,
        ),
        'hasAlert': true,
      };
    }

    if (_requiredDocTypes.isNotEmpty) {
      final userDocTypes =
          (docs ?? [])
              .where(
                (d) =>
                    d['status']?.toString().toUpperCase() == 'APROVADO' ||
                    d['status']?.toString().toUpperCase() == 'PENDENTE',
              )
              .map((d) => d['tipo']?.toString().toUpperCase() ?? '')
              .toSet();

      final missingRequired = _requiredDocTypes.any(
        (req) => !userDocTypes.contains(req),
      );
      if (missingRequired) {
        return {
          'label': 'Documentos pendentes',
          'color': Colors.redAccent,
          'icon': const Icon(
            Icons.highlight_off_rounded,
            color: Colors.redAccent,
            size: 28,
          ),
          'hasAlert': true,
        };
      }
    }

    final hasPendingApproval =
        docs != null &&
        docs.any((d) => d['status']?.toString().toUpperCase() == 'PENDENTE');
    if (hasPendingApproval) {
      return {
        'label': 'Aguardando aprovação',
        'color': Colors.amber,
        'icon': const Icon(Icons.circle, color: Colors.amber, size: 10),
        'hasAlert': true,
      };
    }

    return {
      'label': 'Documentação em dia',
      'color': AppColors.primary,
      'icon': const Icon(
        Icons.check_circle_outline_rounded,
        color: AppColors.primary,
        size: 28,
      ),
      'hasAlert': false,
    };
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final itineraryRepo = getIt<ItineraryRepository>();
      final supabase = getIt<SupabaseClient>();

      // Wrap futures to catch individual errors
      final groupFuture = itineraryRepo.getGroupDetails(widget.groupId);
      final itineraryFuture = itineraryRepo.getItinerary(widget.groupId);
      final countFuture = supabase
          .from('gruposParticipantes')
          .count(CountOption.exact)
          .eq('grupo_id', widget.groupId);
      final financeFuture =
          supabase
              .from('grupos')
              .select('orcamento_total, valor_adicionado')
              .eq('id', widget.groupId)
              .maybeSingle();
      final transactionsFuture = supabase
          .from('transacoes_financeiras')
          .select('valor_gasto')
          .eq('grupo_id', widget.groupId);

      final results = await Future.wait<dynamic>([
        groupFuture,
        itineraryFuture,
        countFuture,
        financeFuture,
        transactionsFuture,
      ]);

      if (mounted) {
        setState(() {
          // 1. Group Details
          final groupRes =
              results[0] as dartz.Either<Exception, ItineraryGroupEntity>;
          _group = groupRes.fold((l) {
            debugPrint('Erro ao carregar detalhes do grupo: $l');
            return null;
          }, (r) => r);

          // 2. Itinerary
          final itineraryRes =
              results[1] as dartz.Either<Exception, List<ItineraryItemEntity>>;
          final itinerary = itineraryRes.fold((l) {
            debugPrint('Erro ao carregar itinerário: $l');
            return <ItineraryItemEntity>[];
          }, (r) => r);

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final tomorrow = today.add(const Duration(days: 1));
          _upcomingEvents =
              itinerary
                  .where((e) {
                    if (e.startDateTime == null) return false;
                    final start = e.startDateTime!;
                    // Apenas hoje
                    if (start.isBefore(today) || !start.isBefore(tomorrow)) {
                      return false;
                    }
                    // Não concluído: evento ainda não terminou
                    final end =
                        e.endDateTime ?? start.add(const Duration(hours: 1));
                    return now.isBefore(end);
                  })
                  .toList();

          // 3. Traveler Count (exibição removida do card)
          final _ = results[2];

          // 4 & 5. Finances
          final groupFinanceRes = results[3] as Map<String, dynamic>?;
          final transactionsRes = results[4] as List<dynamic>?;

          double totalBudget = 0.0;
          if (groupFinanceRes != null) {
            final orcamento =
                double.tryParse(
                  groupFinanceRes['orcamento_total']?.toString() ?? '0',
                ) ??
                0.0;
            final adicionado =
                double.tryParse(
                  groupFinanceRes['valor_adicionado']?.toString() ?? '0',
                ) ??
                0.0;
            totalBudget = orcamento + adicionado;
          }

          double totalSpent = 0.0;
          if (transactionsRes != null) {
            for (var t in transactionsRes) {
              totalSpent +=
                  double.tryParse(t['valor_gasto']?.toString() ?? '0') ?? 0.0;
            }
          }

          _isLoading = false;
        });

        // Load Members separately
        _loadMembers(supabase);
      }
    } catch (e, stack) {
      debugPrint('Erro CRÍTICO ao carregar dados do dashboard: $e');
      debugPrint(stack.toString());
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '--:--';
    return DateFormat('HH:mm').format(dt);
  }

  Future<void> _loadMembers(SupabaseClient supabase) async {
    try {
      // 0. Fetch required documents for the group's mission
      try {
        final groupRes = await supabase
            .from('grupos')
            .select('missao_id, missoes:missao_id (documentos_exigidos)')
            .eq('id', widget.groupId)
            .maybeSingle();

        if (groupRes != null && groupRes['missoes'] != null) {
          final docsList = groupRes['missoes']['documentos_exigidos'] as List?;
          if (docsList != null) {
            _requiredDocTypes =
                docsList.map((e) => e.toString().toUpperCase()).toList();
          }
        }
      } catch (e) {
        debugPrint('Erro ao buscar documentos_exigidos da missão: $e');
      }

      // 1. Fetch Travelers
      final participantsRes = await supabase
          .from('gruposParticipantes')
          .select('user_id')
          .eq('grupo_id', widget.groupId);

      final travelerIds =
          (participantsRes as List).map((e) => e['user_id']).toList();

      if (travelerIds.isNotEmpty) {
        final usersRes = await supabase
            .from('users')
            .select()
            .inFilter('id', travelerIds);
        final docsRes = await supabase
            .from('documentos')
            .select('user_id, status, tipo, nome_documento, foto_doc')
            .inFilter('user_id', travelerIds);

        _travelers =
            usersRes
                .map((user) {
                  final userId = user['id'];
                  final userDocs =
                      docsRes.where((d) => d['user_id'] == userId).toList();
                  return {'user': user, 'documentos': userDocs};
                })
                .toList()
                .cast<Map<String, dynamic>>();
      } else {
        _travelers = [];
      }

      // 2. Fetch Guides
      final leadersRes = await supabase
          .from('lideresGrupo')
          .select('lider_id')
          .eq('grupo_id', widget.groupId);

      final leaderIds = (leadersRes as List).map((e) => e['lider_id']).toList();

      if (leaderIds.isNotEmpty) {
        final guidesUsersRes = await supabase
            .from('users')
            .select()
            .inFilter('id', leaderIds);
        _guides =
            guidesUsersRes
                .map((user) {
                  return {'user': user};
                })
                .toList()
                .cast<Map<String, dynamic>>();
      } else {
        _guides = [];
      }

      if (mounted) {
        setState(() {
          _filteredTravelers = _travelers;
          _filteredGuides = _guides;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar membros: $e');
    }
  }

  void _onSearch(String query) {
    setState(() {
      _filteredTravelers =
          _travelers.where((t) {
            final name = t['user']?['nome']?.toString().toLowerCase() ?? '';
            return name.contains(query.toLowerCase());
          }).toList();
      _filteredGuides =
          _guides.where((g) {
            final name = g['user']?['nome']?.toString().toLowerCase() ?? '';
            return name.contains(query.toLowerCase());
          }).toList();
    });
  }

  IconData _getIconForType(ItineraryType type) {
    switch (type) {
      case ItineraryType.food:
        return Icons.restaurant;
      case ItineraryType.hotel:
        return Icons.hotel;
      case ItineraryType.visit:
        return Icons.precision_manufacturing;
      case ItineraryType.leisure:
        return Icons.beach_access;
      case ItineraryType.transfer:
        return Icons.directions_bus;
      case ItineraryType.flight:
        return Icons.flight;
      default:
        return Icons.event;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const HeaderSpacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BlocBuilder<DocumentsCubit, DocumentsState>(
                  builder: (context, state) {
                    if (state.hasPendingDocuments) {
                      return const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: DocumentsAlertCard(),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildMainCard(context),
                ),
                const SizedBox(height: 24),
                if (_upcomingEvents.isNotEmpty) ...[
                  _buildUpcomingEvents(context),
                  const SizedBox(height: 24),
                ],
                _buildQuickActions(context),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildMembersSection(context),
                ),
              ],
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildMainCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).cardColor,
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                  child: ClipOval(
                    child:
                        _group?.logo != null
                            ? Image.network(
                              _group!.logo!,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.group,
                                        color: AppColors.primary,
                                        size: 32,
                                      ),
                            )
                            : const Icon(
                              Icons.group,
                              color: AppColors.primary,
                              size: 32,
                            ),
                  ),
                ),
                Positioned(
                  bottom: -8,
                  left: -20,
                  right: -20,
                  child: Center(
                    child: GestureDetector(
                      onTap: widget.onSwitchGroup,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Theme.of(context).cardColor,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.sync, size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Trocar',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('Grupo', 'Group'),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _group?.name ?? context.t('Grupo sem nome', 'Unnamed group'),
                    style: AppTextStyles.h3.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _group?.missionLocation ?? context.t('Itinerário active', 'Active itinerary'),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.grey,
                            fontSize: 13,
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


  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            context.t('Ações rápidas', 'Quick actions'),
            style: AppTextStyles.bodyMedium.copyWith(
              color:
                  Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withOpacity(0.7) ??
                  Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _buildActionItem(
                  context,
                  context.t('Lembrete', 'Reminder'),
                  Icons.notifications_active_outlined,
                  AppColors.primary,
                  () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder:
                        (context) => ReminderModal(groupId: widget.groupId),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionItem(
                  context,
                  context.t('Incidente', 'Incident'),
                  Icons.warning_amber_rounded,
                  AppColors.primary,
                  () => context.push('/incident-list/${widget.groupId}').then((_) => _loadData()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionItem(
                  context,
                  context.t('Gastos', 'Expenses'),
                  Icons.output_rounded,
                  AppColors.primary,
                  () => context.push('/expense-list/${widget.groupId}').then((_) => _loadData()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionItem(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingEvents(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            context.t('Próximos eventos', 'Upcoming events'),
            style: AppTextStyles.bodyMedium.copyWith(
              color:
                  Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withOpacity(0.7) ??
                  Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (_upcomingEvents.isEmpty)
                  Container(
                    width: 240,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Center(child: Text(context.t('Nenhum evento agendado', 'No scheduled events'))),
                  )
                else
                  ..._upcomingEvents.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _buildEventItem(
                        time: _formatTime(e.startDateTime),
                        type: e.type.name,
                        title: e.name,
                        loc: e.location ?? 'Sem local',
                        icon: _getIconForType(e.type),
                        onTap: () => widget.onNavigateToEvent?.call(e.id),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEventItem({
    required String time,
    required String type,
    required String title,
    required String loc,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 190,
        height: 145,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.015),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: AppColors.primary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: AppTextStyles.h3.copyWith(
                        fontSize: 17,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.north_east_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              type,
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.grey[500],
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
            Text(
              title,
              style: AppTextStyles.h3.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: Colors.grey[400],
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    loc,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.grey[500],
                      fontSize: 12,
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
    );
  }

  Widget _buildMembersSection(BuildContext context) {
    bool hasTravelerAlert = _travelers.any((t) {
      final docs = t['documentos'] as List?;
      final statusInfo = _getTravelerDocStatus(docs);
      return statusInfo['hasAlert'] == true;
    });

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.t('Integrantes', 'Members'),
              style: AppTextStyles.bodyMedium.copyWith(
                color:
                    Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color?.withOpacity(0.7) ??
                    Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04), // Softer shadow
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, left: 20, right: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedMembersTab = 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _selectedMembersTab == 0
                                    ? AppColors.primary
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                context.t('Viajantes', 'Travelers'),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: _selectedMembersTab == 0
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                  fontSize: 15,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              if (hasTravelerAlert) ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.amber,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedMembersTab = 1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _selectedMembersTab == 1
                                    ? AppColors.primary
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              context.t('Guias', 'Guides'),
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: _selectedMembersTab == 1
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                                fontSize: 15,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: AppTextField(
                  onChanged: _onSearch,
                  textStyle: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  hint: context.t('Buscar por nome', 'Search by name'),
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary.withOpacity(0.7),
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
              ),
              _selectedMembersTab == 0
                  ? _buildMembersList(_filteredTravelers, true)
                  : _buildMembersList(_filteredGuides, false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMembersList(
    List<Map<String, dynamic>> members,
    bool isTraveler,
  ) {
    if (members.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text(
            context.t('Nenhum integrante encontrado', 'No members found'),
            style: AppTextStyles.bodySmall.copyWith(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: members.length,
      separatorBuilder:
          (context, index) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: Theme.of(context).dividerColor),
          ),
      itemBuilder: (context, index) {
        final item = members[index];
        final user = item['user'] as Map<String, dynamic>?;
        final name = user?['nome'] ?? 'Sem nome';
        final avatar = user?['foto'];
        final company = user?['empresa'] ?? 'Independente';

        String statusLabel = 'Documentação em dia';
        Color statusColor = AppColors.primary;
        Widget trailingWidget = const Icon(
          Icons.check_circle_outline_rounded,
          color: AppColors.primary,
          size: 28,
        );

        if (isTraveler) {
          final docs = item['documentos'] as List?;
          final statusInfo = _getTravelerDocStatus(docs);
          statusLabel = statusInfo['label'] as String;
          statusColor = statusInfo['color'] as Color;
          trailingWidget = statusInfo['icon'] as Widget;
        }

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showMemberDetails(context, item, isTraveler),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage:
                        avatar != null ? NetworkImage(avatar) : null,
                    backgroundColor: Theme.of(context).dividerColor,
                    child:
                        avatar == null
                            ? const Icon(Icons.person, color: Colors.grey)
                            : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          name,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          statusLabel,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          company,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.grey[500],
                            fontSize: 13,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailingWidget,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMemberDetails(
    BuildContext context,
    Map<String, dynamic> item,
    bool isTraveler,
  ) {
    final user = item['user'];
    final name = user?['nome'] ?? 'Sem nome';
    final avatar = user?['foto'] ?? user?['avatar_url'];
    final company = user?['empresa'] ?? 'Independente';

    // Status Logic Logic (duplicated for display purposes, could be refactored)
    String statusLabel = 'Confirmado';
    Color statusColor = AppColors.primary;

    if (isTraveler) {
      final docs = item['documentos'] as List?;
      final hasPending =
          docs != null &&
          docs.any((d) => d['status']?.toString().toUpperCase() == 'PENDENTE');
      final hasExpired =
          docs != null &&
          docs.any((d) => d['status']?.toString().toUpperCase() == 'EXPIRADO');

      if (hasExpired) {
        statusLabel = 'Documento expirado!';
        statusColor = Colors.orangeAccent[700]!;
      } else if (hasPending) {
        statusLabel = 'Aguardando documento!';
        statusColor = Colors.amber;
      } else if (docs == null || docs.isEmpty) {
        statusLabel = 'Pendente';
        statusColor = Colors.redAccent;
      }
    }

    final foodPrefs = user?['preferencias_alimentares'] as List?;
    final medicalRest = user?['restricoes_medicas'] as List?;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Detalhes do integrante',
                        style: AppTextStyles.h2.copyWith(fontSize: 22),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundImage:
                            (avatar != null && avatar.isNotEmpty)
                                ? NetworkImage(avatar)
                                : null,
                        backgroundColor: Theme.of(context).dividerColor,
                        child:
                            (avatar == null || avatar.isEmpty)
                                ? const Icon(
                                  Icons.person,
                                  color: Colors.grey,
                                  size: 32,
                                )
                                : null,
                        onBackgroundImageError:
                            (avatar != null && avatar.isNotEmpty)
                                ? (_, __) {}
                                : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: AppTextStyles.h3.copyWith(fontSize: 18),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              company,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                statusLabel,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildDetailRow(
                    'Restrições Alimentares',
                    foodPrefs?.join(', ') ?? 'Nenhuma',
                    Icons.restaurant,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    'Restrições Médicas',
                    medicalRest?.join(', ') ?? 'Nenhuma',
                    Icons.medical_services_outlined,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        context.push(
                          '/member-details',
                          extra: {...item, 'groupName': _group?.name ?? ''},
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusLg,
                          ),
                        ),
                      ),
                      child: const Text('Ver mais detalhes'),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[400]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value.isEmpty ? 'Nenhuma' : value,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class RegisterExpenseDialog extends StatefulWidget {
  final String groupId;
  final DashboardActionsRepository repository;
  final Map<String, dynamic>? expenseToEdit;

  const RegisterExpenseDialog({
    required this.groupId,
    required this.repository,
    this.expenseToEdit,
  });

  @override
  State<RegisterExpenseDialog> createState() => RegisterExpenseDialogState();
}

class RegisterExpenseDialogState extends State<RegisterExpenseDialog> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'Refeição';
  String _selectedCurrency = 'BRL';
  List<String> _attachedFilePaths = [];
  List<String> _existingReceiptUrls = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.expenseToEdit != null) {
      final expense = widget.expenseToEdit!;
      final local = expense['local'] ?? '';
      if (local.endsWith(' (USD)')) {
        _selectedCurrency = 'USD';
        _descriptionController.text = local.substring(0, local.length - 6);
      } else {
        _selectedCurrency = 'BRL';
        _descriptionController.text = local;
      }
      _selectedCategory = expense['categoria'] ?? 'Refeição';
      _existingReceiptUrls = List<String>.from(expense['comprovantes_urls'] as List? ?? []);

      final amount = double.tryParse(expense['valor_gasto']?.toString() ?? '0') ?? 0.0;
      _amountController.text = CentavosInputFormatter(isUsd: _selectedCurrency == 'USD').formatter.format(amount);
    }
  }

  final List<String> _categories = [
    'Refeição',
    'Transporte',
    'Hospedagem',
    'Passeio',
    'Imprevisto',
    'Outros',
  ];

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Refeição':
        return Icons.restaurant;
      case 'Transporte':
        return Icons.directions_car;
      case 'Hospedagem':
        return Icons.hotel;
      case 'Passeio':
        return Icons.camera_alt;
      case 'Imprevisto':
        return Icons.warning_amber;
      case 'Outros':
        return Icons.more_horiz;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Barra de arrastar (Drag Handle)
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.expenseToEdit != null ? context.t('Editar gasto', 'Edit expense') : context.t('Registrar gasto', 'Register expense'),
                      style: AppTextStyles.h2.copyWith(fontSize: 22),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                AppTextField(
                  label: context.t('Valor do gasto', 'Expense amount'),
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    CentavosInputFormatter(isUsd: _selectedCurrency == 'USD'),
                  ],
                  textStyle: AppTextStyles.h1.copyWith(
                    fontSize: 32,
                    color: AppColors.primary,
                  ),
                  hintStyle: AppTextStyles.h1.copyWith(
                    fontSize: 32,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
                  ),
                  hint: _selectedCurrency == 'USD' ? '\$ 0.00' : 'R\$ 0,00',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 14, right: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCurrency,
                            alignment: Alignment.center,
                            isDense: true,
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'BRL',
                                child: Text('BRL'),
                              ),
                              DropdownMenuItem(
                                value: 'USD',
                                child: Text('USD'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null && val != _selectedCurrency) {
                                final digitsOnly = _amountController.text.replaceAll(RegExp(r'[^\d]'), '');
                                final amount = (double.tryParse(digitsOnly) ?? 0.0) / 100;
                                setState(() {
                                  _selectedCurrency = val;
                                  if (digitsOnly.isNotEmpty) {
                                    _amountController.text = CentavosInputFormatter(isUsd: _selectedCurrency == 'USD').formatter.format(amount);
                                  }
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 1,
                          height: 24,
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  context.t('Categoria', 'Category'),
                  style: AppTextStyles.bodySmall.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        _categories
                            .map(
                              (cat) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  showCheckmark: false,
                                  avatar: Icon(
                                    _getCategoryIcon(cat),
                                    size: 18,
                                    color:
                                        _selectedCategory == cat
                                            ? AppColors.primary
                                            : Colors.grey,
                                  ),
                                  label: Text(
                                    cat == 'Refeição'
                                        ? context.t('Refeição', 'Meal')
                                        : cat == 'Transporte'
                                            ? context.t('Transporte', 'Transportation')
                                            : cat == 'Hospedagem'
                                                ? context.t('Hospedagem', 'Accommodation')
                                                : cat == 'Passeio'
                                                    ? context.t('Passeio', 'Tour')
                                                    : cat == 'Imprevisto'
                                                        ? context.t('Imprevisto', 'Unexpected')
                                                        : context.t('Outros', 'Others'),
                                  ),
                                  selected: _selectedCategory == cat,
                                  onSelected:
                                      (val) =>
                                          setState(() => _selectedCategory = cat),
                                  selectedColor: AppColors.primary.withOpacity(0.2),
                                  labelStyle: TextStyle(
                                    color:
                                        _selectedCategory == cat
                                            ? AppColors.primary
                                            : Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                    fontWeight:
                                        _selectedCategory == cat
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                  ),
                                  backgroundColor: Theme.of(
                                    context,
                                  ).dividerColor.withOpacity(0.03),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusMd,
                                    ),
                                  ),
                                  side: BorderSide.none,
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ),
                const SizedBox(height: 24),
                AppTextField(
                  label: context.t('Descrição / Local', 'Description / Location'),
                  controller: _descriptionController,
                  hint: context.t('Ex: Almoço no aeroporto', 'e.g., Lunch at the airport'),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t('Comprovante(s)', 'Receipt(s)'),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                          if (_existingReceiptUrls.isNotEmpty)
                            Column(
                              children: _existingReceiptUrls.map((url) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.radiusMd,
                                      ),
                                      border: Border.all(
                                        color: AppColors.primary.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.description_outlined,
                                          size: 20,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            context.t('Comprovante salvo', 'Saved receipt'),
                                            style: AppTextStyles.bodySmall.copyWith(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => setState(
                                            () => _existingReceiptUrls.remove(url),
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 18,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          if (_attachedFilePaths.isNotEmpty)
                            Column(
                              children: _attachedFilePaths.map((path) {
                                final fileName = path.split('/').last;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.radiusMd,
                                      ),
                                      border: Border.all(
                                        color: AppColors.primary.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.description_outlined,
                                          size: 20,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            fileName,
                                            style: AppTextStyles.bodySmall.copyWith(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap:
                                              () => setState(
                                                () => _attachedFilePaths.remove(path),
                                              ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 18,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final picker = ImagePicker();
                              final isCamera = await showModalBottomSheet<bool>(
                                context: context,
                                backgroundColor: Colors.transparent,
                                builder:
                                    (context) => NewPostBottomSheet(
                                      onSourceSelected:
                                          (camera) =>
                                              Navigator.pop(context, camera),
                                    ),
                              );
     
                              if (isCamera != null) {
                                final source =
                                    isCamera
                                        ? ImageSource.camera
                                        : ImageSource.gallery;
                                try {
                                  final image = await picker.pickImage(
                                    source: source,
                                  );
                                  if (image != null) {
                                    setState(() {
                                      _attachedFilePaths.add(image.path);
                                    });
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          context.t('Erro ao selecionar arquivo.', 'Error selecting file.'),
                                        ),
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                            icon: const Icon(Icons.attach_file_rounded, size: 20),
                            label: Text((_attachedFilePaths.isEmpty && _existingReceiptUrls.isEmpty) ? context.t('Anexar Comprovante', 'Attach Receipt') : context.t('Adicionar outro anexo', 'Add another attachment')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMd,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          if (_amountController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(context.t('Informe um valor válido', 'Please enter a valid amount'))),
                            );
                            return;
                          }
    
                          final digitsOnly = _amountController.text.replaceAll(RegExp(r'[^\d]'), '');
                          final amount = (double.tryParse(digitsOnly) ?? 0.0) / 100;
                          
                          if (amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(context.t('Informe um valor válido', 'Please enter a valid amount'))),
                            );
                            return;
                          }
    
                          setState(() => _isLoading = true);
                          
                          final rawDescription = _descriptionController.text.trim();
                          final finalDescription = _selectedCurrency == 'USD'
                              ? '$rawDescription (USD)'
                              : rawDescription;
    
                          final result = widget.expenseToEdit != null
                              ? await widget.repository.updateExpense(
                                  id: widget.expenseToEdit!['id'],
                                  groupId: widget.groupId,
                                  amount: amount,
                                  category: _selectedCategory,
                                  description: finalDescription,
                                  existingReceiptUrls: _existingReceiptUrls,
                                  newLocalReceiptPaths: _attachedFilePaths,
                                )
                              : await widget.repository.registerExpense(
                                  groupId: widget.groupId,
                                  amount: amount,
                                  category: _selectedCategory,
                                  description: finalDescription,
                                  receiptPaths: _attachedFilePaths,
                                );
    
                          if (mounted) {
                            setState(() => _isLoading = false);
                            
                            result.fold(
                              (failure) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${context.t('Erro', 'Error')}: ${failure.toString().replaceAll('Exception: ', '')}')),
                                );
                              },
                              (_) {
                                Navigator.pop(context, true);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      widget.expenseToEdit != null
                                          ? context.t('Gasto atualizado com sucesso!', 'Expense updated successfully!')
                                          : context.t('Gasto registrado com sucesso!', 'Expense registered successfully!'),
                                    ),
                                  ),
                                );
                              },
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          widget.expenseToEdit != null ? context.t('Salvar alterações', 'Save changes') : context.t('Confirmar Registro', 'Confirm Registration'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
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
import 'package:agrobravo/features/home/presentation/widgets/report_modal.dart';
import 'package:agrobravo/features/home/presentation/widgets/incident_modal.dart';
import 'package:agrobravo/features/chat/presentation/pages/individual_chat_page.dart';
import 'package:agrobravo/features/chat/domain/entities/chat_entity.dart';

class GuideDashboardPage extends StatefulWidget {
  final String groupId;
  final VoidCallback onSwitchGroup;
  final ValueChanged<int>? onTabChange;

  const GuideDashboardPage({
    super.key,
    required this.groupId,
    required this.onSwitchGroup,
    this.onTabChange,
  });

  @override
  State<GuideDashboardPage> createState() => _GuideDashboardPageState();
}

class _GuideDashboardPageState extends State<GuideDashboardPage> {
  ItineraryGroupEntity? _group;
  List<ItineraryItemEntity> _upcomingEvents = [];
  int _travelerCount = 0;
  double _groupBalance = 0.0;
  List<Map<String, dynamic>> _travelers = [];
  List<Map<String, dynamic>> _guides = [];
  List<Map<String, dynamic>> _filteredTravelers = [];
  List<Map<String, dynamic>> _filteredGuides = [];
  bool _isLoading = true;

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
          _upcomingEvents =
              itinerary
                  .where(
                    (e) =>
                        e.startDateTime != null &&
                        (e.startDateTime!.isAfter(
                          now.subtract(const Duration(minutes: 30)),
                        )),
                  )
                  .take(5)
                  .toList();

          // 3. Traveler Count
          final countRes = results[2];
          if (countRes is int) {
            _travelerCount = countRes;
          } else if (countRes is PostgrestResponse) {
            _travelerCount = countRes.count ?? 0;
          } else {
            _travelerCount = 0;
          }

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

          _groupBalance = totalBudget - totalSpent;
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
            .select('user_id, status, tipo, nome_documento')
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

  Future<void> _openBackofficeChat(BuildContext context) async {
    try {
      final supabase = getIt<SupabaseClient>();

      // Search for the Backoffice/Support user
      // You might want to adjust the query based on how the backoffice user is identified
      // e.g., by email, specific ID, or role.
      final response =
          await supabase
              .from('users')
              .select()
              .ilike(
                'nome',
                '%Suporte%',
              ) // Assuming name contains 'Suporte' or similar
              .limit(1)
              .maybeSingle();

      if (response != null) {
        final guide = GuideEntity(
          id: response['id'],
          name: response['nome'] ?? 'Suporte AgroBravo',
          role: 'Suporte',
          avatarUrl: response['foto'],
        );

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => IndividualChatPage(guide: guide),
            ),
          );
        }
      } else {
        // Fallback to Chat Tab if user not found
        widget.onTabChange?.call(2);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contato de suporte não encontrado.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error opening backoffice chat: $e');
      widget.onTabChange?.call(2);
    }
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
      color: const Color(0xFFF2F4F7),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildMainCard(context),
                  ),
                  const SizedBox(height: 24),
                  _buildQuickActions(context),
                  const SizedBox(height: 24),
                  _buildUpcomingEvents(context),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildMembersSection(context),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Padding(
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
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade100),
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
                              color: const Color(0xFF00B289),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white, width: 2),
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
                        'Grupo',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _group?.name ?? 'Grupo sem nome',
                        style: AppTextStyles.h3.copyWith(fontSize: 18),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 16,
                            color: const Color(0xFF00B289),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _group?.missionLocation ?? 'Itinerário ativo',
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
                _buildAvatarStackCompact(),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saldo do grupo',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        NumberFormat.simpleCurrency(
                          locale: 'pt_BR',
                        ).format(_groupBalance),
                        style: AppTextStyles.h2.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _showRegisterExpenseModal(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Registrar gasto',
                        style: AppTextStyles.button.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.output_rounded, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRegisterExpenseModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => const Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(horizontal: 16),
            child: _RegisterExpenseDialog(),
          ),
    );
  }

  Widget _buildAvatarStackCompact() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$_travelerCount',
          style: AppTextStyles.h3.copyWith(
            fontSize: 20,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'viajantes',
          style: AppTextStyles.bodySmall.copyWith(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Ações rápidas',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildActionItem(
                  context,
                  'Itinerário',
                  Icons.explore_outlined,
                  AppColors.primary,
                  () => widget.onTabChange?.call(1),
                ),
                _buildActionItem(
                  context,
                  'Lembrete',
                  Icons.notifications_active_outlined,
                  AppColors.primary,
                  () => showDialog(
                    context: context,
                    builder:
                        (context) => ReminderModal(groupId: widget.groupId),
                  ),
                ),
                _buildActionItem(
                  context,
                  'Relatório',
                  Icons.assignment_outlined,
                  AppColors.primary,
                  () => showDialog(
                    context: context,
                    builder: (context) => const ReportModal(),
                  ),
                ),
                _buildActionItem(
                  context,
                  'Incidente',
                  Icons.warning_amber_rounded,
                  AppColors.primary,
                  () => showDialog(
                    context: context,
                    builder: (context) => const IncidentModal(),
                  ),
                ),
                _buildActionItem(
                  context,
                  'Backoffice',
                  Icons.chat_bubble_outline_rounded,
                  AppColors.primary,
                  () => _openBackofficeChat(context),
                ),
              ],
            ),
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
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
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
            'Próximos eventos',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Center(child: Text('Nenhum evento agendado')),
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
  }) {
    return Container(
      width: 190,
      height: 145,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
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
                  Icon(icon, color: const Color(0xFF00B289), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    time,
                    style: AppTextStyles.h3.copyWith(
                      fontSize: 18,
                      color: const Color(0xFF00B289),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFF00B289),
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
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
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
    );
  }

  Widget _buildMembersSection(BuildContext context) {
    bool hasTravelerAlert = _travelers.any((t) {
      final docs = t['documentos'] as List?;
      return docs != null &&
          docs.any((d) => d['status']?.toString().toUpperCase() == 'PENDENTE');
    });

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Integrantes',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(maxHeight: 500),
          decoration: BoxDecoration(
            color: Colors.white,
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
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, left: 20, right: 20),
                  child: TabBar(
                    labelColor: AppColors.textPrimary,
                    unselectedLabelColor: AppColors.textPrimary,
                    labelStyle: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    unselectedLabelStyle: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w400,
                      fontSize: 16,
                    ),
                    indicatorColor: AppColors.primary,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorWeight: 3,
                    dividerColor: Colors.transparent,
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Viajantes'),
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
                      const Tab(text: 'Guias'),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: TextField(
                    onChanged: _onSearch,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nome',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary.withOpacity(0.7),
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusLg,
                        ),
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusLg,
                        ),
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusLg,
                        ),
                        borderSide: BorderSide(
                          color: AppColors.primary.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                    ),
                  ),
                ),

                Expanded(
                  // Use Expanded to fill remaining height
                  child: TabBarView(
                    children: [
                      _buildMembersList(_filteredTravelers, true),
                      _buildMembersList(_filteredGuides, false),
                    ],
                  ),
                ),
              ],
            ),
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
        child: Text(
          'Nenhum integrante encontrado',
          style: AppTextStyles.bodySmall.copyWith(color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: members.length,
      separatorBuilder:
          (context, index) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: Colors.grey.shade100),
          ),
      itemBuilder: (context, index) {
        final item = members[index];
        final user = item['user'] as Map<String, dynamic>?;
        final name = user?['nome'] ?? 'Sem nome';
        final avatar = user?['foto'];
        final company = user?['empresa'] ?? 'Independente';

        String statusLabel = 'Confirmado';
        Color statusColor = const Color(0xFF00B289);
        Widget trailingWidget = const Icon(
          Icons.check_circle_outline_rounded,
          color: Color(0xFF00B289),
          size: 28,
        );

        if (isTraveler) {
          final docs = item['documentos'] as List?;
          final hasPending =
              docs != null &&
              docs.any(
                (d) => d['status']?.toString().toUpperCase() == 'PENDENTE',
              );
          final hasExpired =
              docs != null &&
              docs.any(
                (d) => d['status']?.toString().toUpperCase() == 'EXPIRADO',
              );

          if (hasExpired) {
            statusLabel = 'Documento expirado!';
            statusColor = Colors.orangeAccent[700]!;
            trailingWidget = Icon(
              Icons.warning_amber_rounded,
              color: Colors.orangeAccent[700],
              size: 24,
            );
          } else if (hasPending) {
            statusLabel = 'Aguardando documento!';
            statusColor = Colors.amber;
            trailingWidget = const Icon(
              Icons.circle,
              color: Colors.amber,
              size: 10,
            );
          } else if (docs == null || docs.isEmpty) {
            statusLabel = 'Pendente';
            statusColor = Colors.redAccent;
            trailingWidget = const Icon(
              Icons.highlight_off_rounded,
              color: Colors.redAccent,
              size: 28,
            );
          }
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
                    backgroundColor: Colors.grey[200],
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
                            color: AppColors.textPrimary,
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
    Color statusColor = const Color(0xFF00B289);

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
                color: Colors.white,
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
                        backgroundColor: Colors.grey[200],
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
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RegisterExpenseDialog extends StatefulWidget {
  const _RegisterExpenseDialog();

  @override
  State<_RegisterExpenseDialog> createState() => _RegisterExpenseDialogState();
}

class _RegisterExpenseDialogState extends State<_RegisterExpenseDialog> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'Refeição';
  String? _attachedFileName;

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
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Registrar gasto',
                  style: AppTextStyles.h2.copyWith(fontSize: 22),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Valor do gasto',
              style: AppTextStyles.bodySmall.copyWith(color: Colors.grey),
            ),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: AppTextStyles.h1.copyWith(
                fontSize: 32,
                color: AppColors.primary,
              ),
              decoration: const InputDecoration(
                prefixText: r'R$ ',
                border: InputBorder.none,
                hintText: '0,00',
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Categoria',
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
                              avatar: Icon(
                                _getCategoryIcon(cat),
                                size: 18,
                                color:
                                    _selectedCategory == cat
                                        ? AppColors.primary
                                        : Colors.grey,
                              ),
                              label: Text(cat),
                              selected: _selectedCategory == cat,
                              onSelected:
                                  (val) =>
                                      setState(() => _selectedCategory = cat),
                              selectedColor: AppColors.primary.withOpacity(0.2),
                              labelStyle: TextStyle(
                                color:
                                    _selectedCategory == cat
                                        ? AppColors.primary
                                        : Colors.black,
                                fontWeight:
                                    _selectedCategory == cat
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                              ),
                              backgroundColor: Colors.grey.shade100,
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
            Text(
              'Descrição / Local',
              style: AppTextStyles.bodySmall.copyWith(color: Colors.grey),
            ),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                hintText: 'Ex: Almoço no aeroporto',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Comprovante',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_attachedFileName != null)
                        Container(
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
                                  _attachedFileName!,
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
                                      () => _attachedFileName = null,
                                    ),
                                child: const Icon(
                                  Icons.close,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
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
                                    _attachedFileName = image.name;
                                  });
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Erro ao selecionar arquivo.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          icon: const Icon(Icons.attach_file_rounded, size: 20),
                          label: const Text('Anexar Comprovante'),
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
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Gasto registrado com sucesso!'),
                  ),
                );
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
              child: const Text(
                'Confirmar Registro',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

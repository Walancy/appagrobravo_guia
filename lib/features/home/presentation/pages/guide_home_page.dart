import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agrobravo/core/di/injection.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/core/components/app_header.dart';
import 'package:agrobravo/features/home/presentation/cubit/guide_home_cubit.dart';
import 'package:agrobravo/features/itinerary/domain/entities/itinerary_group.dart';
import 'package:agrobravo/features/home/presentation/widgets/guide_mission_card.dart';
import 'package:agrobravo/features/home/presentation/widgets/groups_list_modal.dart';
import 'package:agrobravo/core/components/empty_mission_state.dart';

class GuideHomePage extends StatelessWidget {
  final Function(String)? onGroupSelected;
  const GuideHomePage({super.key, this.onGroupSelected});

  static const _filters = [
    {'label': 'Todas', 'value': null},
    {'label': 'Ativa', 'value': 'ATIVA'},
    {'label': 'Planejada', 'value': 'PLANEJADA'},
    {'label': 'Concluída', 'value': 'CONCLUIDA'},
  ];

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<GuideHomeCubit>()..loadMissions(),
      child: BlocBuilder<GuideHomeCubit, GuideHomeState>(
        builder: (context, state) {
          return state.maybeWhen(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (msg) => Center(child: Text(msg)),
            loaded: (missions, activeFilter) {
              final cubit = context.read<GuideHomeCubit>();
              return Column(
                children: [
                  // Espaço abaixo da AppBar (mesmo height que o HeaderSpacer usa)
                  const HeaderSpacer(),
                  // Filter chips bar — agora visível abaixo da AppBar
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filters.length,
                      separatorBuilder: (_, _x) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final f = _filters[i];
                        final fValue = f['value'];
                        final isSelected = activeFilter == fValue;
                        return FilterChip(
                          label: Text(f['label'] as String),
                          selected: isSelected,
                          onSelected: (_) => cubit.setStatusFilter(
                            isSelected ? null : fValue as String?,
                          ),
                          showCheckmark: false,
                          labelStyle: AppTextStyles.bodySmall.copyWith(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                          backgroundColor:
                              Theme.of(context).colorScheme.surfaceContainerHighest,
                          selectedColor: const Color(0xFF00B289),
                          side: BorderSide.none,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Mission list
                  Expanded(
                    child: missions.isEmpty
                        ? EmptyMissionState(
                            icon: Icons.assignment_outlined,
                            title: 'Nenhuma missão encontrada',
                            description: activeFilter == null
                                ? 'Você não possui missões ativas vinculadas à sua conta no momento.'
                                : 'Nenhuma missão com status "${_filters.firstWhere((f) => f['value'] == activeFilter)['label']}" encontrada.',
                            actionLabel: 'Recarregar',
                            onActionPressed: () => cubit.loadMissions(),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
                            itemCount: missions.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 4, 16, 12),
                                  child: Text(
                                    'Selecione uma missão',
                                    style: AppTextStyles.h2.copyWith(
                                      fontSize: 16,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                );
                              }

                              final guideMission = missions[index - 1];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: GuideMissionCard(
                                  guideMission: guideMission,
                                  onViewGroups: () => _showGroupsModal(
                                      context, guideMission.groups),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          );
        },
      ),
    );
  }


  void _showGroupsModal(
    BuildContext context,
    List<ItineraryGroupEntity> groups,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: GroupsListModal(
              groups: groups,
              onGroupSelected: (groupId) {
                Navigator.pop(context);
                onGroupSelected?.call(groupId);
              },
            ),
          ),
    );
  }
}


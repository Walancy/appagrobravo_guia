import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agrobravo/core/di/injection.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/core/components/app_header.dart';
import 'package:agrobravo/features/home/presentation/cubit/guide_home_cubit.dart';
import 'package:agrobravo/features/itinerary/domain/entities/itinerary_group.dart';
import 'package:agrobravo/features/home/presentation/widgets/guide_mission_card.dart';
import 'package:agrobravo/features/home/presentation/widgets/groups_list_modal.dart';

class GuideHomePage extends StatelessWidget {
  final Function(String)? onGroupSelected;
  const GuideHomePage({super.key, this.onGroupSelected});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<GuideHomeCubit>()..loadMissions(),
      child: BlocBuilder<GuideHomeCubit, GuideHomeState>(
        builder: (context, state) {
          return state.maybeWhen(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (msg) => Center(child: Text(msg)),
            loaded: (missions) {
              if (missions.isEmpty) {
                return const Center(child: Text("Nenhuma missão encontrada."));
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                itemCount: missions.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return const HeaderSpacer();
                  }
                  if (index == 1) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 0, bottom: 12.0),
                      child: Text(
                        "Selecione uma missão",
                        style: AppTextStyles.h2.copyWith(
                          fontSize: 16,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    );
                  }

                  final guideMission = missions[index - 2];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: GuideMissionCard(
                      guideMission: guideMission,
                      onViewGroups:
                          () => _showGroupsModal(context, guideMission.groups),
                    ),
                  );
                },
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
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            child: GroupsListModal(
              groups: groups,
              onGroupSelected: (groupId) {
                Navigator.pop(context); // Close dialog
                onGroupSelected?.call(groupId);
              },
            ),
          ),
    );
  }
}

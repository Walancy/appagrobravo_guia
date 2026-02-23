import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agrobravo/core/di/injection.dart';

import 'package:agrobravo/core/tokens/app_spacing.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/features/home/presentation/cubit/guide_home_cubit.dart';
import 'package:agrobravo/features/itinerary/domain/entities/itinerary_group.dart';

class GroupSwitchModal extends StatefulWidget {
  final Function(String) onGroupSelected;

  const GroupSwitchModal({super.key, required this.onGroupSelected});

  @override
  State<GroupSwitchModal> createState() => _GroupSwitchModalState();
}

class _GroupSwitchModalState extends State<GroupSwitchModal> {
  String? _selectedMissionId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<GuideHomeCubit>()..loadMissions(),
      child: Dialog(
        backgroundColor: Theme.of(context).cardColor,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380, maxHeight: 500),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Trocar Grupo',
                      style: AppTextStyles.h3.copyWith(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.grey),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Flexible(
                  child: BlocBuilder<GuideHomeCubit, GuideHomeState>(
                    builder: (context, state) {
                      return state.maybeWhen(
                        loading:
                            () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                        error: (msg) => Center(child: Text(msg)),
                        loaded: (missions) {
                          if (missions.isEmpty) {
                            return const Center(
                              child: Text("Nenhuma missão encontrada."),
                            );
                          }

                          final selectedMission =
                              _selectedMissionId == null
                                  ? missions.first
                                  : missions.firstWhere(
                                    (m) => m.mission.id == _selectedMissionId,
                                    orElse: () => missions.first,
                                  );

                          final groups = selectedMission.groups;

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Missão',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    value:
                                        _selectedMissionId ??
                                        missions.first.mission.id,
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Theme.of(
                                        context,
                                      ).dividerColor.withOpacity(0.05),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusLg,
                                        ),
                                        borderSide: BorderSide(
                                          color: Theme.of(
                                            context,
                                          ).dividerColor.withOpacity(0.1),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusLg,
                                        ),
                                        borderSide: BorderSide(
                                          color: Theme.of(
                                            context,
                                          ).dividerColor.withOpacity(0.1),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusLg,
                                        ),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF00B289),
                                        ),
                                      ),
                                    ),
                                    isExpanded: true,
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: Colors.grey,
                                    ),
                                    selectedItemBuilder: (
                                      BuildContext context,
                                    ) {
                                      return missions.map((guideMission) {
                                        return Row(
                                          children: [
                                            if (guideMission.mission.logo !=
                                                    null &&
                                                guideMission
                                                    .mission
                                                    .logo!
                                                    .isNotEmpty)
                                              CircleAvatar(
                                                radius: 14,
                                                backgroundImage: NetworkImage(
                                                  guideMission.mission.logo!,
                                                ),
                                              )
                                            else
                                              CircleAvatar(
                                                radius: 14,
                                                backgroundColor:
                                                    Colors.grey[100],
                                                child: const Icon(
                                                  Icons.public,
                                                  size: 16,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                guideMission.mission.name,
                                                style: AppTextStyles.bodyMedium
                                                    .copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          Theme.of(context)
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.color,
                                                    ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList();
                                    },
                                    items:
                                        missions.map((guideMission) {
                                          return DropdownMenuItem<String>(
                                            value: guideMission.mission.id,
                                            child: Row(
                                              children: [
                                                if (guideMission.mission.logo !=
                                                        null &&
                                                    guideMission
                                                        .mission
                                                        .logo!
                                                        .isNotEmpty)
                                                  CircleAvatar(
                                                    radius: 14,
                                                    backgroundImage:
                                                        NetworkImage(
                                                          guideMission
                                                              .mission
                                                              .logo!,
                                                        ),
                                                  )
                                                else
                                                  CircleAvatar(
                                                    radius: 14,
                                                    backgroundColor:
                                                        Colors.grey[100],
                                                    child: const Icon(
                                                      Icons.public,
                                                      size: 16,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    guideMission.mission.name,
                                                    style: AppTextStyles
                                                        .bodyMedium
                                                        .copyWith(
                                                          color:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .bodyMedium
                                                                  ?.color,
                                                        ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedMissionId = val;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Flexible(
                                child:
                                    groups.isEmpty
                                        ? const Padding(
                                          padding: EdgeInsets.all(20.0),
                                          child: Text(
                                            "Nenhum grupo nesta missão.",
                                          ),
                                        )
                                        : ListView.separated(
                                          shrinkWrap: true,
                                          itemCount: groups.length,
                                          separatorBuilder:
                                              (_, __) =>
                                                  const SizedBox(height: 12),
                                          itemBuilder: (context, index) {
                                            final group = groups[index];
                                            return _buildGroupItem(
                                              context,
                                              group,
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupItem(BuildContext context, ItineraryGroupEntity group) {
    return GestureDetector(
      onTap: () => widget.onGroupSelected(group.id),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
                image:
                    group.logo != null && group.logo!.isNotEmpty
                        ? DecorationImage(
                          image: NetworkImage(group.logo!),
                          fit: BoxFit.cover,
                        )
                        : null,
              ),
              child:
                  group.logo == null || group.logo!.isEmpty
                      ? Icon(Icons.group, color: Colors.grey[400], size: 20)
                      : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                  if (group.missionLocation != null)
                    Text(
                      group.missionLocation!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

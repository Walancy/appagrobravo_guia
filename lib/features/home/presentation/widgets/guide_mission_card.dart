import 'package:flutter/material.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/features/itinerary/domain/entities/guide_mission.dart';
import 'package:agrobravo/core/tokens/assets.gen.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GuideMissionCard extends StatelessWidget {
  final GuideMission guideMission;
  final VoidCallback onViewGroups;

  const GuideMissionCard({
    super.key,
    required this.guideMission,
    required this.onViewGroups,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mission = guideMission.mission;
    final groupsCount = guideMission.groups.length;

    // Calculate duration
    int? duration;
    if (mission.startDate != null && mission.endDate != null) {
      duration = mission.endDate!.difference(mission.startDate!).inDays;
    }

    return Container(
      decoration: BoxDecoration(color: theme.colorScheme.surface),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.background,
                  image:
                      mission.logo != null
                          ? DecorationImage(
                            image: NetworkImage(mission.logo!),
                            fit: BoxFit.cover,
                          )
                          : null,
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child:
                    mission.logo == null
                        ? Icon(Icons.public, color: AppColors.primary)
                        : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Missão',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.grey[500],
                        fontSize: 11,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 0),
                    Text(
                      mission.name,
                      style: AppTextStyles.h3.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 16,
                          color: const Color(0xFF00B289),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          mission.location ?? 'Destino não informado',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (duration != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Dias de viagem',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.grey[500],
                        fontSize: 11,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 0),
                    Text(
                      '$duration dias',
                      style: AppTextStyles.h3.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: theme.dividerColor.withOpacity(0.5)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  SizedBox(
                    height: 28,
                    child: Stack(
                      children: List.generate(
                        groupsCount > 3 ? 3 : groupsCount,
                        (index) {
                          final groupLogo = guideMission.groups[index].logo;
                          return Padding(
                            padding: EdgeInsets.only(left: index * 18.0),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.cardColor,
                                border: Border.all(
                                  color: theme.colorScheme.surface,
                                  width: 2,
                                ),
                                image:
                                    groupLogo != null
                                        ? DecorationImage(
                                          image: NetworkImage(groupLogo),
                                          fit: BoxFit.cover,
                                        )
                                        : null,
                              ),
                              child:
                                  groupLogo == null
                                      ? Container(
                                        padding: const EdgeInsets.all(4),
                                        child: SvgPicture.asset(
                                          Assets.images.logoColorida,
                                        ),
                                      )
                                      : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$groupsCount grupos',
                    style: AppTextStyles.h3.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onViewGroups,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B289),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Ver grupos',
                    style: AppTextStyles.button.copyWith(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

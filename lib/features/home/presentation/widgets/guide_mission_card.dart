import 'package:flutter/material.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/features/itinerary/domain/entities/guide_mission.dart';
import 'package:agrobravo/core/constants/translations.dart';

class GuideMissionCard extends StatelessWidget {
  final GuideMission guideMission;
  final VoidCallback onViewGroups;

  const GuideMissionCard({
    super.key,
    required this.guideMission,
    required this.onViewGroups,
  });

  static const _statusConfig = <String, Map<String, dynamic>>{
    'ATIVA': {'label': 'Ativa', 'color': AppColors.primary},
    'PLANEJADA': {'label': 'Planejada', 'color': Color(0xFF3B82F6)},
    'CONCLUIDA': {'label': 'Concluída', 'color': Color(0xFF9CA3AF)},
    'CANCELADA': {'label': 'Cancelada', 'color': Color(0xFFEF4444)},
  };

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

    final statusKey = mission.status?.toUpperCase();
    final statusCfg = _statusConfig[statusKey];
    final statusLabel = statusCfg?['label'] as String?;
    final statusColor =
        statusCfg?['color'] as Color? ?? const Color(0xFFF59E0B);

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
                      context.t('Missão', 'Mission'),
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
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          mission.location ?? context.t('Destino não informado', 'Destination not informed'),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Status badge
                  if (statusLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        statusLabel,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  if (duration != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      context.t('Dias de viagem', 'Travel days'),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.grey[500],
                        fontSize: 11,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 0),
                    Text(
                      context.t('$duration dias', '$duration days'),
                      style: AppTextStyles.h3.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: theme.dividerColor.withOpacity(0.03)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      height: 28,
                      child: Stack(
                        children: List.generate(
                          groupsCount > 3 ? 3 : groupsCount,
                          (index) {
                            final group = guideMission.groups[index];
                            final groupLogo = group.logo;
                            final initials = group.name.isNotEmpty
                                ? group.name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join()
                                : '?';
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
                                child: groupLogo == null
                                    ? Center(
                                        child: Text(
                                          initials,
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
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
                      context.t('$groupsCount grupos', '$groupsCount groups'),
                      style: AppTextStyles.h3.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onViewGroups,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    context.t('Ver grupos', 'View groups'),
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


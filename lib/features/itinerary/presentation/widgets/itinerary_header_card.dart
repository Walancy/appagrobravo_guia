import 'package:flutter/material.dart';
import '../../../../core/tokens/app_text_styles.dart';
import '../../domain/entities/itinerary_group.dart';
import 'day_slider.dart';

class ItineraryHeaderCard extends StatelessWidget {
  final ItineraryGroupEntity group;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onTrocar;

  const ItineraryHeaderCard({
    super.key,
    required this.group,
    required this.selectedDate,
    required this.onDateSelected,
    required this.onTrocar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        // removed boxShadow
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Logo
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
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
                          ? Icon(Icons.group, color: Colors.grey[400])
                          : null,
                ),
                const SizedBox(width: 12),
                // Group Info
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
                        group.name,
                        style: AppTextStyles.h3.copyWith(fontSize: 18),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 14,
                            color: Color(0xFF00B289),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              group.missionLocation ?? 'Itinerário',
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
                // Trocar Button
                GestureDetector(
                  onTap: onTrocar,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00B289),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.sync, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Trocar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Day Slider container
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.hardEdge, // Clip content
            child: DaySlider(
              startDate: group.startDate,
              endDate: group.endDate,
              selectedDate: selectedDate,
              onDateSelected: onDateSelected,
            ),
          ),
        ],
      ),
    );
  }
}

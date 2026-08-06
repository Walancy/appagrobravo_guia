import 'package:flutter/material.dart';
import '../../../../core/tokens/app_colors.dart';
import '../../../../core/tokens/app_text_styles.dart';
import '../../domain/entities/itinerary_item.dart';

class ItineraryFilters {
  final Set<ItineraryType> types;

  const ItineraryFilters({this.types = const {}});

  bool get isActive => types.isNotEmpty;

  int get count => types.length;

  ItineraryFilters copyWith({
    Set<ItineraryType>? types,
  }) {
    return ItineraryFilters(
      types: types ?? this.types,
    );
  }
}

class ItineraryFilterModal extends StatefulWidget {
  final ItineraryFilters initialFilters;

  const ItineraryFilterModal({
    super.key,
    required this.initialFilters,
  });

  @override
  State<ItineraryFilterModal> createState() => _ItineraryFilterModalState();
}

class _ItineraryFilterModalState extends State<ItineraryFilterModal> {
  late Set<ItineraryType> _selectedTypes;

  @override
  void initState() {
    super.initState();
    _selectedTypes = Set.from(widget.initialFilters.types);
  }

  void _toggleType(ItineraryType type) {
    setState(() {
      if (_selectedTypes.contains(type)) {
        _selectedTypes.remove(type);
      } else {
        _selectedTypes.add(type);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    'Filtros',
                    style: AppTextStyles.h3.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Text(
                'Tipo de evento',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ItineraryType.values
                    .where((t) => t != ItineraryType.other)
                    .map((type) {
                      final isSelected = _selectedTypes.contains(type);
                      return FilterChip(
                        selected: isSelected,
                        avatar: Icon(
                          _getTypeIcon(type),
                          size: 16,
                          color: isSelected ? Colors.white : AppColors.primary,
                        ),
                        label: Text(_getTypeLabel(type)),
                        labelStyle: AppTextStyles.bodySmall.copyWith(
                          color: isSelected
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        backgroundColor:
                            Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.shade100,
                        selectedColor: AppColors.primary,
                        onSelected: (_) => _toggleType(type),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : Theme.of(context).dividerColor.withOpacity(0.03),
                          ),
                        ),
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                      );
                    })
                    .toList(),
              ),

              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context, const ItineraryFilters());
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Limpar',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(
                          context,
                          ItineraryFilters(types: _selectedTypes),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Aplicar',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTypeIcon(ItineraryType type) {
    switch (type) {
      case ItineraryType.flight:
        return Icons.flight;
      case ItineraryType.visit:
        return Icons.location_on;
      case ItineraryType.hotel:
        return Icons.hotel;
      case ItineraryType.food:
        return Icons.restaurant;
      case ItineraryType.leisure:
        return Icons.pool;
      case ItineraryType.transfer:
        return Icons.directions_bus;
      case ItineraryType.returnType:
        return Icons.swap_horiz_rounded;
      default:
        return Icons.event;
    }
  }

  String _getTypeLabel(ItineraryType type) {
    switch (type) {
      case ItineraryType.flight:
        return 'Voo';
      case ItineraryType.visit:
        return 'Visita';
      case ItineraryType.hotel:
        return 'Hotel';
      case ItineraryType.food:
        return 'Alimentação';
      case ItineraryType.leisure:
        return 'Lazer';
      case ItineraryType.transfer:
        return 'Transfer';
      case ItineraryType.returnType:
        return 'Retorno';
      default:
        return 'Outro';
    }
  }

}

import 'package:flutter/material.dart';
import '../../../../core/tokens/app_colors.dart';
import '../../../../core/tokens/app_text_styles.dart';
import '../../../../core/widgets/date_time_picker_sheet.dart';
import '../../domain/entities/itinerary_item.dart';

class ItineraryFilters {
  final Set<ItineraryType> types;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;

  const ItineraryFilters({this.types = const {}, this.startTime, this.endTime});

  bool get isActive => types.isNotEmpty || startTime != null || endTime != null;

  int get count =>
      types.length + (startTime != null ? 1 : 0) + (endTime != null ? 1 : 0);

  ItineraryFilters copyWith({
    Set<ItineraryType>? types,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    bool clearStartTime = false,
    bool clearEndTime = false,
  }) {
    return ItineraryFilters(
      types: types ?? this.types,
      startTime: clearStartTime ? null : (startTime ?? this.startTime),
      endTime: clearEndTime ? null : (endTime ?? this.endTime),
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
  TimeOfDay? _selectedStartTime;
  TimeOfDay? _selectedEndTime;

  @override
  void initState() {
    super.initState();
    _selectedTypes = Set.from(widget.initialFilters.types);
    _selectedStartTime = widget.initialFilters.startTime;
    _selectedEndTime = widget.initialFilters.endTime;
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

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hora início',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: _pickStartTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _selectedStartTime != null
                                      ? _selectedStartTime!.format(context)
                                      : 'Selecionar',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hora fim',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: _pickEndTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time_filled,
                                  size: 16,
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _selectedEndTime != null
                                      ? _selectedEndTime!.format(context)
                                      : 'Selecionar',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                          ItineraryFilters(
                            types: _selectedTypes,
                            startTime: _selectedStartTime,
                            endTime: _selectedEndTime,
                          ),
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

  Future<void> _pickStartTime() async {
    final now = DateTime.now();
    final init = _selectedStartTime != null
        ? DateTime(now.year, now.month, now.day, _selectedStartTime!.hour, _selectedStartTime!.minute)
        : DateTime(now.year, now.month, now.day, 0, 0);
    final picked = await DateTimePickerSheet.show(
      context,
      initial: init,
    );
    if (picked != null) {
      setState(() => _selectedStartTime = TimeOfDay(hour: picked.hour, minute: picked.minute));
    }
  }

  Future<void> _pickEndTime() async {
    final now = DateTime.now();
    final init = _selectedEndTime != null
        ? DateTime(now.year, now.month, now.day, _selectedEndTime!.hour, _selectedEndTime!.minute)
        : DateTime(now.year, now.month, now.day, 23, 59);
    final picked = await DateTimePickerSheet.show(
      context,
      initial: init,
    );
    if (picked != null) {
      setState(() => _selectedEndTime = TimeOfDay(hour: picked.hour, minute: picked.minute));
    }
  }
}

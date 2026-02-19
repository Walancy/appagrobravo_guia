import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/tokens/app_colors.dart';
import '../../domain/entities/itinerary_group.dart';
import 'package:agrobravo/features/itinerary/domain/entities/itinerary_item.dart';
import '../../../../core/tokens/app_text_styles.dart';
import '../cubit/itinerary_cubit.dart';
import '../widgets/itinerary_list.dart';
import '../widgets/itinerary_header_card.dart';
import '../widgets/itinerary_filter_modal.dart';
import '../widgets/group_switch_modal.dart';
import 'package:agrobravo/core/components/app_header.dart';
import 'package:agrobravo/core/components/itinerary_shimmer.dart';

/// Standalone Widget to be used as a Tab
class ItineraryTab extends StatelessWidget {
  final String? groupId;
  final VoidCallback?
  onSwitchGroup; // Keep for backward compatibility if needed, or remove
  final Function(String)? onGroupChanged;

  const ItineraryTab({
    super.key,
    this.groupId,
    this.onSwitchGroup,
    this.onGroupChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = GetIt.I<ItineraryCubit>();
        if (groupId != null) {
          cubit.loadItinerary(groupId!);
        } else {
          cubit.loadUserItinerary();
        }
        return cubit;
      },
      child: Scaffold(
        // Inner scaffold to handle background and body
        body: BlocBuilder<ItineraryCubit, ItineraryState>(
          builder: (context, state) {
            return state.maybeWhen(
              loading: () => const ItineraryShimmer(),
              error:
                  (msg) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('Erro: $msg', textAlign: TextAlign.center),
                    ),
                  ),
              loaded: (group, items, travelTimes, pendingDocs) {
                return ItineraryContent(
                  group: group,
                  items: items,
                  travelTimes: travelTimes,
                  pendingDocs: pendingDocs,
                  onSwitchGroup: onSwitchGroup ?? () {},
                  onGroupChanged: onGroupChanged ?? (_) {},
                );
              },
              orElse: () => const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
  }
}

class ItineraryContent extends StatefulWidget {
  final ItineraryGroupEntity group;
  final List<ItineraryItemEntity> items;
  final List<Map<String, dynamic>> travelTimes;
  final List<String> pendingDocs;
  final VoidCallback onSwitchGroup;
  final Function(String) onGroupChanged;

  const ItineraryContent({
    super.key,
    required this.group,
    required this.items,
    required this.travelTimes,
    required this.pendingDocs,
    required this.onSwitchGroup,
    required this.onGroupChanged,
  });

  @override
  State<ItineraryContent> createState() => _ItineraryContentState();
}

class _ItineraryContentState extends State<ItineraryContent> {
  DateTime? _selectedDate;
  ItineraryFilters _filters = const ItineraryFilters();

  @override
  void initState() {
    super.initState();
    // Default to first day if valid range
    // Default to current date if valid range
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (widget.group.startDate.year > 0) {
      if (today.isAfter(
            widget.group.startDate.subtract(const Duration(days: 1)),
          ) &&
          today.isBefore(widget.group.endDate.add(const Duration(days: 1)))) {
        _selectedDate = today;
      } else {
        _selectedDate = widget.group.startDate;
      }
    }
    // Normalize _selectedDate to start of day
    if (_selectedDate != null) {
      _selectedDate = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
      );
    }
  }

  void _showFilterModal() async {
    // Generate dates between start and end
    final availableDates = List.generate(
      widget.group.endDate.difference(widget.group.startDate).inDays + 1,
      (i) => widget.group.startDate.add(Duration(days: i)),
    );

    final result = await showDialog<ItineraryFilters>(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: ItineraryFilterModal(
              initialFilters: _filters,
              availableDates: availableDates,
            ),
          ),
    );

    if (result != null) {
      setState(() {
        _filters = result;
        if (result.date != null) {
          // Normalize selected date from filter modal
          _selectedDate = DateTime(
            result.date!.year,
            result.date!.month,
            result.date!.day,
          );
        }
      });
    }
  }

  void _showSwitchModal() {
    showDialog(
      context: context,
      builder:
          (context) => GroupSwitchModal(
            onGroupSelected: (groupId) {
              Navigator.pop(context);
              widget.onGroupChanged(groupId);
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF2F4F7), // Match home background
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HeaderSpacer(),
          //removed sizedbox height 4 to stick to header spacer if needed, but header card has margin top

          // Header Card with Group Info and Day Slider
          ItineraryHeaderCard(
            group: widget.group,
            selectedDate: _selectedDate,
            onDateSelected: (date) {
              setState(() {
                // Normalize selected date from slider
                _selectedDate = DateTime(date.year, date.month, date.day);
                // If filter had a different date, we clear it or sync it
                if (_filters.date != null &&
                    !_isSameDay(_filters.date!, _selectedDate!)) {
                  _filters = _filters.copyWith(date: _selectedDate);
                }
              });
            },
            onTrocar: _showSwitchModal,
          ),

          const SizedBox(height: 16),

          // Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _filters.isActive
                      ? '${_filters.count} filtros aplicados'
                      : 'Sem filtros aplicados',
                  style: AppTextStyles.bodySmall.copyWith(
                    color:
                        _filters.isActive
                            ? AppColors.primary
                            : Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.6),
                    fontWeight:
                        _filters.isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                GestureDetector(
                  onTap: _showFilterModal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10, // Increased for better tap area
                    ),
                    decoration: BoxDecoration(
                      color:
                          _filters.isActive
                              ? AppColors.primary.withOpacity(0.1)
                              : (Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF1E1E1E)
                                  : const Color(0xFFF2F4F7)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            _filters.isActive
                                ? AppColors.primary
                                : Theme.of(
                                  context,
                                ).dividerColor.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.filter_list,
                          size: 16,
                          color:
                              _filters.isActive
                                  ? AppColors.primary
                                  : Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Filtrar',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color:
                                _filters.isActive
                                    ? AppColors.primary
                                    : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // List
          Expanded(
            child: ItineraryList(
              items: widget.items,
              travelTimes: widget.travelTimes,
              selectedDate: _selectedDate,
              groupId: widget.group.id,
              filters: _filters,
              pendingDocs: widget.pendingDocs,
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

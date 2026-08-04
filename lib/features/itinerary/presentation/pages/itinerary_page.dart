import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/tokens/app_colors.dart';
import '../../../../core/tokens/app_text_styles.dart';
import '../../domain/entities/itinerary_group.dart';
import '../../domain/entities/itinerary_item.dart';
import '../cubit/itinerary_cubit.dart';
import '../widgets/itinerary_header_card.dart';
import '../widgets/itinerary_list.dart';

class ItineraryPage extends StatelessWidget {
  final String groupId;

  const ItineraryPage({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => GetIt.I<ItineraryCubit>()..loadItinerary(groupId),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'Itinerário',
            style: AppTextStyles.h3.copyWith(color: AppColors.surface),
          ),
          backgroundColor: AppColors.primary,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: BlocBuilder<ItineraryCubit, ItineraryState>(
          builder: (context, state) {
            return state.maybeWhen(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (msg) => Center(child: Text('${context.t('Erro', 'Error')}: $msg')),
              loaded: (group, items, travelTimes, pendingDocs) {
                final isEnded = group.endDate.isBefore(DateTime.now());
                final displayPendingDocs = isEnded ? <String>[] : pendingDocs;

                return _ItineraryContent(
                  group: group,
                  items: items,
                  travelTimes: travelTimes,
                  pendingDocs: displayPendingDocs,
                  isEnded: isEnded,
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

class _ItineraryContent extends StatefulWidget {
  final ItineraryGroupEntity group;
  final List<ItineraryItemEntity> items;
  final List<Map<String, dynamic>> travelTimes;
  final List<String> pendingDocs;
  final bool isEnded;

  const _ItineraryContent({
    required this.group,
    required this.items,
    required this.travelTimes,
    required this.pendingDocs,
    required this.isEnded,
  });

  @override
  State<_ItineraryContent> createState() => _ItineraryContentState();
}

class _ItineraryContentState extends State<_ItineraryContent> {
  DateTime? _selectedDate;
  late PageController _pageController;
  late List<DateTime> _days;

  @override
  void initState() {
    super.initState();
    _days = _getDaysInBetween(widget.group.startDate, widget.group.endDate);

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
    // Normalize
    if (_selectedDate != null) {
      _selectedDate = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
      );
    }

    final initialPage = _selectedDate != null
        ? _days.indexWhere(
            (d) =>
                d.year == _selectedDate!.year &&
                d.month == _selectedDate!.month &&
                d.day == _selectedDate!.day,
          )
        : 0;

    _pageController = PageController(initialPage: initialPage < 0 ? 0 : initialPage);
  }

  List<DateTime> _getDaysInBetween(DateTime start, DateTime end) {
    if (end.isBefore(start)) return [start];
    return List.generate(
      end.difference(start).inDays + 1,
      (i) => start.add(Duration(days: i)),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onDateSelected(DateTime date) {
    final idx = _days.indexWhere(
      (d) =>
          d.year == date.year &&
          d.month == date.month &&
          d.day == date.day,
    );
    setState(() => _selectedDate = date);
    if (idx >= 0 && _pageController.hasClients) {
      _pageController.animateToPage(
        idx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.isEnded)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.grey[800],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Missão encerrada',
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ItineraryHeaderCard(
          group: widget.group,
          selectedDate: _selectedDate,
          onDateSelected: _onDateSelected,
          onTrocar: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const ClampingScrollPhysics(),
            itemCount: _days.length,
            onPageChanged: (index) {
              setState(() => _selectedDate = _days[index]);
            },
            itemBuilder: (context, index) {
              return ItineraryList(
                items: widget.items,
                travelTimes: widget.travelTimes,
                selectedDate: _days[index],
                pendingDocs: widget.pendingDocs,
                groupId: widget.group.id,
              );
            },
          ),
        ),
      ],
    );
  }
}

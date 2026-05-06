import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/itinerary_item.dart';
import '../../../../core/tokens/app_colors.dart';
import 'itinerary_cards.dart';
import '../cubit/itinerary_cubit.dart';

import 'itinerary_filter_modal.dart';

class ItineraryList extends StatefulWidget {
  final List<ItineraryItemEntity> items;
  final List<Map<String, dynamic>> travelTimes;
  final DateTime? selectedDate;
  final ItineraryFilters? filters;
  final List<String> pendingDocs;
  final String groupId;
  final String? scrollToItemId;

  const ItineraryList({
    super.key,
    required this.items,
    required this.travelTimes,
    required this.selectedDate,
    required this.groupId,
    this.filters,
    this.pendingDocs = const [],
    this.scrollToItemId,
  });

  @override
  State<ItineraryList> createState() => _ItineraryListState();
}

class _ItineraryListState extends State<ItineraryList> {
  final _scrollController = ScrollController();
  final Map<String, GlobalKey> _itemKeys = {};

  @override
  void initState() {
    super.initState();
    if (widget.scrollToItemId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToItem(widget.scrollToItemId!);
      });
    }
  }

  @override
  void didUpdateWidget(covariant ItineraryList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scrollToItemId != null &&
        widget.scrollToItemId != oldWidget.scrollToItemId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToItem(widget.scrollToItemId!);
      });
    }
  }

  void _scrollToItem(String itemId) {
    final key = _itemKeys[itemId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.2,
      );
    }
  }

  GlobalKey _keyForItem(String itemId) {
    return _itemKeys.putIfAbsent(itemId, () => GlobalKey());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filter items
    final displayedItemsFull =
        widget.items.where((item) {
          // 1. Filter by Date (selectedDate from header slider)
          if (widget.selectedDate != null && item.startDateTime != null) {
            if (!_isSameDay(item.startDateTime!, widget.selectedDate!)) {
              return false;
            }
          }

          // 2. Filter by Type
          if (widget.filters != null && widget.filters!.types.isNotEmpty) {
            if (!widget.filters!.types.contains(item.type)) return false;
          }

          // 3. Filter by time range
          final startTime = widget.filters?.startTime;
          final endTime = widget.filters?.endTime;
          if ((startTime != null || endTime != null) &&
              item.startDateTime != null) {
            final itemTime = TimeOfDay.fromDateTime(item.startDateTime!);
            final itemMinutes = itemTime.hour * 60 + itemTime.minute;
            final effectiveStart = startTime ?? const TimeOfDay(hour: 0, minute: 0);
            final effectiveEnd = endTime ?? const TimeOfDay(hour: 23, minute: 59);
            final startMinutes = effectiveStart.hour * 60 + effectiveStart.minute;
            final endMinutes = effectiveEnd.hour * 60 + effectiveEnd.minute;
            if (itemMinutes < startMinutes || itemMinutes > endMinutes) {
              return false;
            }
          }

          return true;
        }).toList();

    // 1. Sort the FULL filtered list
    final displayedItems = List<ItineraryItemEntity>.from(displayedItemsFull);
    displayedItems.sort(_sortLogic);

    // Filter items for logical neighbors logic needs the FULL sorted list
    final fullItemsSorted = List<ItineraryItemEntity>.from(widget.items);
    fullItemsSorted.sort(_sortLogic);

    if (displayedItems.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          await context.read<ItineraryCubit>().loadUserItinerary();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            alignment: Alignment.center,
            child: const Text("Nenhum evento corresponde aos filtros."),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await context.read<ItineraryCubit>().loadUserItinerary();
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        itemCount: displayedItems.length,
        itemBuilder: (context, index) {
          final item = displayedItems[index];
          final bool isLast = index == displayedItems.length - 1;
          final bool nextIsExtra =
              !isLast &&
              (displayedItems[index + 1].type == ItineraryType.transfer ||
                  displayedItems[index + 1].type == ItineraryType.returnType);

          // Determine if we should show the "Next day" tag
          bool showNextDayTag = false;
          if (item.type == ItineraryType.transfer) {
            final globalIndex = fullItemsSorted.indexOf(item);
            if (globalIndex > 0) {
              final prevItem = fullItemsSorted[globalIndex - 1];
              // If it follows a flight from a different day
              if (prevItem.type == ItineraryType.flight &&
                  prevItem.startDateTime != null &&
                  item.startDateTime != null &&
                  !_isSameDay(prevItem.startDateTime!, item.startDateTime!)) {
                showNextDayTag = true;
              }
            }
          }

          Widget card;
          String? statusLabel;
          Color? statusColor;

          if (item.startDateTime != null) {
            final now = DateTime.now();
            final start = item.startDateTime!;
            // Approx end if not set (1 hour)
            final end = item.endDateTime ?? start.add(const Duration(hours: 1));

            if (now.isAfter(start) && now.isBefore(end)) {
              statusLabel = 'Acontecendo agora';
              statusColor = AppColors.primary;
            } else if (now.isBefore(start) &&
                start.difference(now).inMinutes < 60 &&
                start.day == now.day) {
              statusLabel = 'Em breve';
              statusColor = Colors.orange;
            }
          }

          if (item.type == ItineraryType.flight) {
            card = FlightCard(item: item, pendingDocs: widget.pendingDocs);
          } else if (item.type == ItineraryType.transfer) {
            card = TransferCard(item: item, showNextDayTag: showNextDayTag);
          } else {
            card = GenericEventCard(item: item, groupId: widget.groupId);
          }

          if (statusLabel != null) {
            card = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 8, left: 20),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusLabel.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                card,
              ],
            );
          }

          // Try to find travel time:
          String? travelDuration;

          if (item.type == ItineraryType.transfer) {
            travelDuration =
                (item.travelTime != null && item.travelTime!.isNotEmpty)
                    ? item.travelTime
                    : item.durationString;
          } else {
            final bool nextIsTransfer =
                !isLast &&
                displayedItems[index + 1].type == ItineraryType.transfer;

            if (!isLast && !nextIsTransfer) {
              final nextItem = displayedItems[index + 1];
              travelDuration = nextItem.travelTime;

              if (travelDuration == null || travelDuration.isEmpty) {
                try {
                  final travel = widget.travelTimes.firstWhere(
                    (t) =>
                        t['id_origem'].toString() == item.id.toString() &&
                        t['id_destino'].toString() == nextItem.id.toString(),
                  );
                  travelDuration = travel['tempo_deslocamento'];
                } catch (_) {}
              }
            }
          }

          return Stack(
            key: _keyForItem(item.id),
            children: [
              // Timeline line
              if (!isLast)
                Positioned(
                  left: 30,
                  top: 50,
                  bottom: -2,
                  child: Container(
                    width: 2,
                    child: CustomPaint(
                      painter: DashedLineVerticalPainter(
                        color: const Color(0xFF00BFA5).withOpacity(0.5),
                      ),
                    ),
                  ),
                ),

              Column(
                children: [
                  card,
                  if (travelDuration != null)
                    TravelTimeWidget(duration: travelDuration),
                  if (!isLast && travelDuration == null && !nextIsExtra)
                    const TravelTimeWidget(duration: null),
                  if (!isLast && travelDuration == null && nextIsExtra)
                    const SizedBox(height: 10),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  int _sortLogic(ItineraryItemEntity a, ItineraryItemEntity b) {
    if (a.startDateTime == null || b.startDateTime == null) return 0;
    final dateCompare = a.startDateTime!.compareTo(b.startDateTime!);
    if (dateCompare != 0) return dateCompare;

    final bool isAExtra =
        a.type == ItineraryType.transfer || a.type == ItineraryType.returnType;
    final bool isBExtra =
        b.type == ItineraryType.transfer || b.type == ItineraryType.returnType;

    if (isAExtra && !isBExtra) return 1;
    if (!isAExtra && isBExtra) return -1;
    return 0;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class DashedLineVerticalPainter extends CustomPainter {
  final Color color;
  DashedLineVerticalPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;

    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + 5), paint);
      startY += 10;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

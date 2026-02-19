import 'package:flutter/material.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/core/di/injection.dart';
import 'package:agrobravo/features/itinerary/domain/repositories/itinerary_repository.dart';

class ChecklistBottomSheet extends StatefulWidget {
  final String eventName;
  final String? eventLocation;
  final IconData eventIcon;
  final String groupId;
  final String eventId;

  const ChecklistBottomSheet({
    super.key,
    required this.eventName,
    this.eventLocation,
    this.eventIcon = Icons.event_outlined,
    required this.groupId,
    required this.eventId,
  });

  @override
  State<ChecklistBottomSheet> createState() => _ChecklistBottomSheetState();
}

class _ChecklistBottomSheetState extends State<ChecklistBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allTravelers = [];
  List<Map<String, dynamic>> _filteredTravelers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadParticipants();
    _searchController.addListener(_filterTravelers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadParticipants() async {
    final repo = getIt<ItineraryRepository>();

    final results = await Future.wait([
      repo.getGroupParticipants(widget.groupId),
      repo.getEventAttendance(widget.eventId),
    ]);

    if (!mounted) return;

    final participantsResult =
        results[0] as dartz.Either<Exception, List<Map<String, dynamic>>>;
    final attendanceResult =
        results[1] as dartz.Either<Exception, List<String>>;

    participantsResult.fold(
      (error) {
        setState(() {
          _error = error.toString();
          _isLoading = false;
        });
      },
      (participants) {
        final presentUserIds = attendanceResult.getOrElse(() => []);

        final updatedParticipants =
            participants.map((p) {
              return {...p, 'isChecked': presentUserIds.contains(p['userId'])};
            }).toList();

        setState(() {
          _allTravelers = updatedParticipants;
          _filteredTravelers = updatedParticipants;
          _isLoading = false;
        });
      },
    );
  }

  void _filterTravelers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTravelers =
          _allTravelers.where((t) {
            final name = (t['name'] as String? ?? '').toLowerCase();
            return name.contains(query);
          }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Constraint height to 70% of screen
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Checklist',
                        style: AppTextStyles.h2.copyWith(fontSize: 24),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Gerencie a presença de viajantes na atividade',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Event Info
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    widget.eventIcon,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.eventName,
                        style: AppTextStyles.h3.copyWith(fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.eventLocation != null)
                        Text(
                          widget.eventLocation!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Search
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nome',
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.grey,
                ),
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
            const SizedBox(height: 24),

            // Content
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                      ? Center(child: Text('Erro: $_error'))
                      : _filteredTravelers.isEmpty
                      ? const Center(child: Text('Nenhum viajante encontrado.'))
                      : GridView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 24,
                              childAspectRatio: 0.7,
                            ),
                        itemCount: _filteredTravelers.length,
                        itemBuilder: (context, index) {
                          final traveler = _filteredTravelers[index];
                          return _buildTravelerItem(traveler);
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTravelerItem(Map<String, dynamic> traveler) {
    final isChecked = traveler['isChecked'] == true;
    final avatarUrl = traveler['avatar'];
    final name = traveler['name'] ?? 'Viajante';
    final role = traveler['role'] ?? 'Participante';

    return GestureDetector(
      onTap: () async {
        final newCheckedValue = !isChecked;
        final userId = traveler['userId'];

        if (userId == null) return;

        setState(() {
          traveler['isChecked'] = newCheckedValue;
        });

        // Background update
        final result = await getIt<ItineraryRepository>().updateAttendance(
          widget.eventId,
          userId,
          newCheckedValue,
        );

        result.fold((failure) {
          // Revert on failure
          if (mounted) {
            setState(() {
              traveler['isChecked'] = isChecked;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao atualizar presença: $failure')),
            );
          }
        }, (_) => null);
      },
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[200],
                  border: Border.all(
                    color: isChecked ? AppColors.primary : Colors.transparent,
                    width: isChecked ? 3 : 0,
                  ),
                  image:
                      avatarUrl != null && avatarUrl.isNotEmpty
                          ? DecorationImage(
                            image: NetworkImage(avatarUrl),
                            fit: BoxFit.cover,
                          )
                          : null,
                ),
                child:
                    (avatarUrl == null || avatarUrl.isEmpty)
                        ? Icon(Icons.person, size: 40, color: Colors.grey[400])
                        : (isChecked
                            ? Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.4),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            )
                            : null),
              ),
              if (isChecked && avatarUrl != null && avatarUrl.isNotEmpty)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.check, color: Colors.white, size: 32),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            role,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.grey,
              fontSize: 10,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

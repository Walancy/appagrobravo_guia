import 'package:flutter/material.dart';
import '../../../../core/tokens/app_colors.dart';
import '../../../../core/tokens/app_spacing.dart';
import '../../../../core/tokens/app_text_styles.dart';
import 'package:get_it/get_it.dart';
import '../../domain/repositories/itinerary_repository.dart';
import '../../domain/entities/menu_item.dart';

class EventMenuBottomSheet extends StatefulWidget {
  final String eventId;
  final String eventName;
  final IconData eventIcon;

  const EventMenuBottomSheet({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.eventIcon,
  });

  @override
  State<EventMenuBottomSheet> createState() => _EventMenuBottomSheetState();
}

class _EventMenuBottomSheetState extends State<EventMenuBottomSheet> {
  final _repository = GetIt.I<ItineraryRepository>();
  List<MenuItemEntity>? _menuItems;
  List<MenuItemEntity>? _filteredItems;
  bool _isLoading = true;
  String? _error;

  String? _selectedCategory;
  bool _showVegetarian = false;
  bool _showVegan = false;
  bool _showNonAlcoholic = false;

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    final result = await _repository.getMenu(widget.eventId);
    if (!mounted) return;

    result.fold(
      (error) {
        setState(() {
          _error = 'Erro ao carregar o cardápio';
          _isLoading = false;
        });
      },
      (items) {
        setState(() {
          _menuItems = items;
          _filteredItems = items;
          _isLoading = false;
        });
      },
    );
  }

  void _applyFilters() {
    if (_menuItems == null) return;

    setState(() {
      _filteredItems =
          _menuItems!.where((item) {
            bool match = true;
            if (_selectedCategory != null && _selectedCategory != 'Todos') {
              if (item.type != _selectedCategory) match = false;
            }
            if (_showVegetarian && !item.isVegetarian) match = false;
            if (_showVegan && !item.isVegan) match = false;
            if (_showNonAlcoholic && item.isAlcoholic) match = false;
            return match;
          }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.lg,
      ),
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(widget.eventIcon, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Cardápio - ${widget.eventName}',
                  style: AppTextStyles.h3.copyWith(fontSize: 18),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Filters
          if (_menuItems != null && _menuItems!.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Vegetariano'),
                    selected: _showVegetarian,
                    onSelected: (selected) {
                      _showVegetarian = selected;
                      _applyFilters();
                    },
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Vegano'),
                    selected: _showVegan,
                    onSelected: (selected) {
                      _showVegan = selected;
                      _applyFilters();
                    },
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Sem álcool'),
                    selected: _showNonAlcoholic,
                    onSelected: (selected) {
                      _showNonAlcoholic = selected;
                      _applyFilters();
                    },
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Content
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                      child: Text(_error!, style: AppTextStyles.bodyMedium),
                    )
                    : _filteredItems == null || _filteredItems!.isEmpty
                    ? Center(
                      child: Text(
                        'Nenhum item do cardápio encontrado.',
                        style: AppTextStyles.bodyMedium,
                      ),
                    )
                    : ListView.builder(
                      itemCount: _filteredItems!.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems![index];
                        return _buildMenuItem(item);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(MenuItemEntity item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.namePt,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (item.isVegetarian)
                const Icon(Icons.eco, color: Colors.green, size: 16),
              if (item.isVegan)
                const Icon(Icons.spa, color: Colors.green, size: 16),
            ],
          ),
          if (item.descriptionPt != null && item.descriptionPt!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.descriptionPt!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
          if (item.nameEn != null && item.nameEn!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.nameEn!,
              style: AppTextStyles.bodySmall.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (item.descriptionEn != null && item.descriptionEn!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.descriptionEn!,
              style: AppTextStyles.bodySmall.copyWith(
                fontStyle: FontStyle.italic,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

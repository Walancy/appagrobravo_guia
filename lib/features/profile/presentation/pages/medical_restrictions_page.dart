import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/tokens/app_spacing.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/core/components/app_header.dart';
import 'package:agrobravo/core/components/medical_shimmer.dart';
import 'package:agrobravo/core/constants/translations.dart';
import 'package:agrobravo/core/di/injection.dart';
import 'package:agrobravo/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:agrobravo/features/profile/presentation/cubit/profile_state.dart';

class MedicalRestrictionsPage extends StatefulWidget {
  const MedicalRestrictionsPage({super.key});

  @override
  State<MedicalRestrictionsPage> createState() =>
      _MedicalRestrictionsPageState();
}

class _MedicalRestrictionsPageState extends State<MedicalRestrictionsPage> {
  List<String> _tags = [];
  bool _isInitialized = false;
  late final ProfileCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = getIt<ProfileCubit>()..loadProfile();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  void _addTag(String text) {
    if (text.isEmpty) return;
    if (!_tags.contains(text)) {
      setState(() {
        _tags.add(text);
      });
      _saveTags();
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
    _saveTags();
  }

  void _saveTags() {
    _cubit.updateMedicalRestrictions(_tags);
  }

  List<String> _getCategories(BuildContext context) {
    return [
      context.t('Condição médica', 'Medical condition'),
      context.t('Uso de medicamento', 'Medication use'),
      context.t('Alergia', 'Allergy'),
      context.t('Restrição alimentar', 'Dietary restriction'),
      context.t('Mobilidade', 'Mobility'),
      context.t('Fobia', 'Phobia'),
      context.t('Outro', 'Other'),
    ];
  }

  void _showAddInformationSheet(BuildContext providerContext) {
    String? selectedCategory;
    final descriptionController = TextEditingController();

    showModalBottomSheet(
      context: providerContext,
      isScrollControlled: true,
      backgroundColor: Theme.of(providerContext).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            final categories = _getCategories(context);
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.lg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedCategory == null
                          ? context.t('Selecione uma categoria', 'Select a category')
                          : context.t('Adicione a descrição', 'Add the description'),
                      style: AppTextStyles.h3.copyWith(
                        color: Theme.of(sheetContext).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (selectedCategory == null)
                      ...categories.map(
                        (category) => ListTile(
                          title: Text(
                            category,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Theme.of(sheetContext).colorScheme.onSurface,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: Theme.of(
                              sheetContext,
                            ).colorScheme.onSurface.withOpacity(0.5),
                          ),
                          onTap: () {
                            setStateSheet(() {
                              selectedCategory = category;
                            });
                          },
                        ),
                      ),
                    if (selectedCategory != null)
                      ...[
                        Text(
                          context.t(
                            'Categoria: $selectedCategory',
                            'Category: $selectedCategory',
                          ),
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          controller: descriptionController,
                          autofocus: true,
                          style: TextStyle(
                            color: Theme.of(sheetContext).colorScheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: context.t(
                              'Escreva a descrição...',
                              'Write the description...',
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusLg,
                              ),
                            ),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              final desc = descriptionController.text.trim();
                              if (desc.isNotEmpty) {
                                _addTag('$selectedCategory: $desc');
                                Navigator.pop(sheetContext);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.md,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusLg,
                                ),
                              ),
                            ),
                            child: Text(
                              context.t('Adicionar', 'Add'),
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () {
                              setStateSheet(() {
                                selectedCategory = null;
                                descriptionController.clear();
                              });
                            },
                            child: Text(
                              context.t(
                                'Voltar para categorias',
                                'Back to categories',
                              ),
                              style: TextStyle(
                                color: Theme.of(
                                  sheetContext,
                                ).colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      descriptionController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppHeader(
          mode: HeaderMode.back,
          title: context.t('Condições médicas', 'Medical conditions'),
        ),
        body: BlocConsumer<ProfileCubit, ProfileState>(
          listener: (context, state) {
            state.maybeWhen(
              loaded: (profile, _, __, ___, ____, _____, ______, _______) {
                if (!_isInitialized) {
                  setState(() {
                    _tags = List<String>.from(
                      profile.medicalRestrictions ?? [],
                    );
                    _isInitialized = true;
                  });
                }
              },
              error: (message) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: AppColors.error,
                  ),
                );
              },
              orElse: () {},
            );
          },
          builder: (context, state) {
            return state.maybeWhen(
              loaded: (profile, _, __, ___, ____, _____, ______, _______) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t(
                          'Adicione informações importantes para sua viagem, como condições médicas, uso contínuo de medicamentos, alergias, restrições alimentares, limitações de mobilidade ou fobias.\n\nSe necessário, leve medicação extra e prescrição médica durante a viagem.',
                          'Add important information for your trip, such as medical conditions, ongoing medication use, allergies, dietary restrictions, mobility limitations or phobias.\n\nIf necessary, bring extra medication and a medical prescription during the trip.',
                        ),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showAddInformationSheet(context),
                          icon: const Icon(
                            Icons.add_circle_outline,
                            color: AppColors.primary,
                          ),
                          label: Text(
                            context.t('Adicionar informação', 'Add information'),
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusLg,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _tags.length,
                          itemBuilder: (context, index) {
                            final tag = _tags[index];
                            final parts = tag.split(': ');
                            final category = parts.length > 1
                                ? parts.first
                                : context.t('Outro', 'Other');
                            final description = parts.length > 1
                                ? parts.sublist(1).join(': ')
                                : tag;

                            return Card(
                              elevation: 0,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.05),
                              margin: const EdgeInsets.only(
                                bottom: AppSpacing.md,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMd,
                                ),
                              ),
                              child: ListTile(
                                title: Text(
                                  category,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    description,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: AppColors.error,
                                  ),
                                  onPressed: () => _removeTag(tag),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: Center(
                          child: Text(
                            context.t(
                              'Suas informações são salvas automaticamente.',
                              'Your information is saved automatically.',
                            ),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              orElse: () => const MedicalShimmer(),
            );
          },
        ),
      ),
    );
  }
}

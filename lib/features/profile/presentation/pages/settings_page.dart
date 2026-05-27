import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/tokens/app_spacing.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/core/components/app_header.dart';
import 'package:agrobravo/core/di/injection.dart';
import 'package:agrobravo/core/cubits/theme_cubit.dart';
import 'package:agrobravo/core/cubits/language_cubit.dart';
import 'package:agrobravo/core/constants/translations.dart';
import 'package:agrobravo/features/profile/domain/entities/profile_entity.dart';
import 'package:agrobravo/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:agrobravo/features/profile/presentation/cubit/profile_state.dart';
import 'package:agrobravo/features/auth/domain/repositories/auth_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:agrobravo/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:agrobravo/features/auth/presentation/cubit/auth_state.dart';
import 'package:agrobravo/features/documents/presentation/cubit/documents_cubit.dart';
import 'package:agrobravo/features/documents/presentation/cubit/documents_state.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => getIt<ProfileCubit>()..loadProfile()),
        BlocProvider(
          create: (context) => getIt<DocumentsCubit>()..loadDocuments(),
        ),
      ],
      child: Scaffold(
        appBar: AppHeader(
          mode: HeaderMode.back,
          title: context.t('Configurações', 'Settings'),
        ),
        body: BlocBuilder<ProfileCubit, ProfileState>(
          builder: (context, state) {
            return state.when(
              initial: () => const Center(child: CircularProgressIndicator()),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (message) {
                final fakeProfile = ProfileEntity(
                  id: '',
                  name: 'Usuário',
                  avatarUrl: null,
                  coverUrl: null,
                  jobTitle: 'Informações indisponíveis',
                  bio: null,
                  missionName: null,
                  email: null,
                  phone: null,
                  cpf: null,
                  ssn: null,
                  zipCode: null,
                  state: null,
                  city: null,
                  street: null,
                  number: null,
                  neighborhood: null,
                  complement: null,
                  birthDate: null,
                  nationality: null,
                  passport: null,
                  foodPreferences: const [],
                  medicalRestrictions: const [],
                  connectionsCount: 0,
                  postsCount: 0,
                  missionsCount: 0,
                  isGuide: false,
                );
                return _buildSettingsContent(context, fakeProfile, hasError: true);
              },
              loaded: (profile, _, isMe, __, ___, ____, _____, ______) {
                return _buildSettingsContent(context, profile);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSettingsContent(BuildContext context, ProfileEntity profile, {bool hasError = false}) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildUserHeader(context, profile, hasError: hasError),
        Divider(
          height: 1,
          color: Theme.of(context).dividerColor.withOpacity(0.5),
        ),
        BlocBuilder<DocumentsCubit, DocumentsState>(
          builder: (context, state) {
            return _buildOption(
              context,
              icon: Icons.description_outlined,
              title: context.t('Meus documentos', 'My documents'),
              onTap: hasError
                  ? () => _showOfflineWarning(context)
                  : () => context.push('/documents'),
              hasBadge: state.hasPendingAction,
            );
          },
        ),
        _buildOption(
          context,
          icon: Icons.person_outline,
          title: context.t('Dados da conta', 'Account details'),
          onTap: hasError
              ? () => _showOfflineWarning(context)
              : () => context.push('/account-data'),
        ),
        _buildOption(
          context,
          icon: Icons.restaurant_menu_outlined,
          title: context.t('Preferências alimentares', 'Food preferences'),
          onTap: hasError
              ? () => _showOfflineWarning(context)
              : () => context.push('/food-preferences'),
        ),
        _buildOption(
          context,
          icon: Icons.medical_services_outlined,
          title: context.t('Restrições médicas', 'Medical restrictions'),
          onTap: hasError
              ? () => _showOfflineWarning(context)
              : () => context.push('/medical-restrictions'),
        ),
        BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, mode) {
            final systemIsDark =
                MediaQuery.platformBrightnessOf(context) ==
                Brightness.dark;
            final isDark =
                mode == ThemeMode.dark ||
                (mode == ThemeMode.system && systemIsDark);
            return _buildOption(
              context,
              icon:
                  isDark ? Icons.dark_mode : Icons.light_mode,
              title: isDark ? context.t('Modo Escuro', 'Dark Mode') : context.t('Modo Claro', 'Light Mode'),
              trailing: Switch(
                value: isDark,
                onChanged: (value) {
                  context.read<ThemeCubit>().setThemeMode(
                    value ? ThemeMode.dark : ThemeMode.light,
                  );
                },
                activeColor: AppColors.primary,
              ),
              onTap: () {
                context.read<ThemeCubit>().setThemeMode(
                  isDark ? ThemeMode.light : ThemeMode.dark,
                );
              },
            );
          },
        ),
        BlocBuilder<LanguageCubit, Locale>(
          builder: (context, locale) {
            final isEnglish = locale.languageCode == 'en';
            return _buildOption(
              context,
              icon: Icons.language,
              title: context.t('Idioma', 'Language'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isEnglish ? 'English' : 'Português',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ],
              ),
              onTap: () {
                _showLanguageSelector(context, locale.languageCode);
              },
            );
          },
        ),
        _buildOption(
          context,
          icon: Icons.notifications_none_outlined,
          title: context.t('Preferências de notificações', 'Notification settings'),
          onTap: hasError
              ? () => _showOfflineWarning(context)
              : () => context.push('/notification-preferences'),
        ),
        _buildOption(
          context,
          icon: Icons.privacy_tip_outlined,
          title: context.t('Política de privacidade', 'Privacy policy'),
          onTap: () => context.push('/privacy-policy'),
        ),
        _buildOption(
          context,
          icon: Icons.info_outline,
          title: context.t('Sobre nós', 'About us'),
          onTap: () => context.push('/about-us'),
        ),
        _buildOption(
          context,
          icon: Icons.logout,
          title: context.t('Sair da conta', 'Log out'),
          isDestructive: true,
          onTap: () async {
            await getIt<AuthCubit>().logout();
            if (context.mounted) context.go('/');
          },
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  void _showLanguageSelector(BuildContext context, String currentLanguageCode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
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
                Text(
                  context.t('Selecione o idioma', 'Select language'),
                  style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Português'),
                  trailing: currentLanguageCode == 'pt'
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () {
                    context.read<LanguageCubit>().setLanguage('pt');
                    Navigator.pop(context);
                  },
                ),
                Divider(height: 1, color: Theme.of(context).dividerColor),
                ListTile(
                  title: const Text('English'),
                  trailing: currentLanguageCode == 'en'
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () {
                    context.read<LanguageCubit>().setLanguage('en');
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showOfflineWarning(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t(
          'Este recurso está temporariamente indisponível devido a falha de conexão.',
          'This feature is temporarily unavailable due to a connection failure.',
        )),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Widget _buildUserHeader(BuildContext context, ProfileEntity profile, {bool hasError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Row(
        children: [
          ClipOval(
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.1)
                        : AppColors.backgroundLight,
              ),
              child:
                  profile.avatarUrl != null
                      ? CachedNetworkImage(
                        imageUrl: profile.avatarUrl!,
                        fit: BoxFit.cover,
                        placeholder:
                            (context, url) =>
                                const CircularProgressIndicator(),
                        errorWidget:
                            (context, url, error) => const Icon(
                              Icons.person,
                              size: 50,
                              color: Colors.grey,
                            ),
                      )
                      : const Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.grey,
                      ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: AppTextStyles.h2.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                if (hasError)
                  Text(
                    context.t('Erro ao carregar dados online', 'Failed to load online data'),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else ...[
                  Builder(builder: (context) {
                    final authState = getIt<AuthCubit>().state;
                    final isAdmin = authState.maybeWhen(
                      authenticated: (user) =>
                          user.roles.contains('COLABORADOR') ||
                          user.roles.contains('MASTER'),
                      orElse: () => false,
                    );
                    if (!isAdmin &&
                        profile.missionName != null &&
                        profile.missionName!.isNotEmpty) {
                      return Text(
                        profile.missionName!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                          height: 1.2,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                  if (profile.email != null && profile.email!.isNotEmpty)
                    Text(
                      profile.email!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                        height: 1.2,
                      ),
                    ),
                  if (profile.phone != null && profile.phone!.isNotEmpty)
                    Text(
                      profile.phone!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                        height: 1.2,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
    bool hasBadge = false,
    Widget? trailing,
  }) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 4,
          ),
          leading: Icon(
            icon,
            color:
                isDestructive
                    ? AppColors.error
                    : Theme.of(context).colorScheme.onSurface,
            size: 24,
          ),
          title: Row(
            children: [
              Text(
                title,
                style: AppTextStyles.bodyLarge.copyWith(
                  color:
                      isDestructive
                          ? AppColors.error
                          : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (hasBadge) ...[
                const SizedBox(width: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    context.t('Pendente', 'Pending'),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.error,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          trailing:
              trailing ??
              Icon(
                Icons.chevron_right,
                size: 20,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
          onTap: onTap,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 64, right: AppSpacing.lg),
          child: Divider(
            height: 1,
            color: Theme.of(context).dividerColor.withOpacity(0.3),
          ),
        ),
      ],
    );
  }
}

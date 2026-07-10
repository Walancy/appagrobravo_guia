import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:agrobravo/core/tokens/app_spacing.dart';
import 'package:agrobravo/core/di/injection.dart';
import 'package:agrobravo/core/constants/translations.dart';
import 'package:agrobravo/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:agrobravo/features/profile/presentation/cubit/profile_state.dart';
import 'package:agrobravo/features/profile/presentation/widgets/profile_header_cover.dart';
import 'package:agrobravo/features/profile/presentation/widgets/profile_header_stats.dart';
import 'package:agrobravo/features/profile/presentation/widgets/profile_info.dart';
import 'package:agrobravo/features/profile/presentation/widgets/profile_actions.dart';
import 'package:agrobravo/features/profile/presentation/widgets/profile_post_grid.dart';
import 'package:agrobravo/features/home/presentation/widgets/new_post_bottom_sheet.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:go_router/go_router.dart';

import 'package:agrobravo/core/components/app_header.dart';
import 'package:agrobravo/core/components/image_source_bottom_sheet.dart';
import 'package:agrobravo/core/components/image_cropper_modal.dart';
import 'package:agrobravo/core/components/profile_shimmer.dart';
import 'package:shimmer/shimmer.dart';
import 'package:agrobravo/features/home/domain/repositories/feed_repository.dart';
import 'package:agrobravo/features/home/domain/entities/mission_entity.dart';
import 'package:agrobravo/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:agrobravo/features/auth/presentation/cubit/auth_state.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SocialProfilePage extends StatefulWidget {
  final String? userId;
  final bool hideAppBar;
  const SocialProfilePage({super.key, this.userId, this.hideAppBar = false});

  @override
  State<SocialProfilePage> createState() => _SocialProfilePageState();
}

class _SocialProfilePageState extends State<SocialProfilePage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _postsKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToPosts() {
    if (_postsKey.currentContext != null) {
      Scrollable.ensureVisible(
        _postsKey.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showMissionsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(context.t('Minhas Missões', 'My Missions'), style: AppTextStyles.h3),
            ),
            const Divider(),
            Expanded(
              child: FutureBuilder<dartz.Either<Exception, List<MissionEntity>>>(
                future: getIt<FeedRepository>().getUserMissions(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _MissionsShimmer();
                  }

                  final result = snapshot.data;
                  final missions =
                      result?.fold((l) => <MissionEntity>[], (r) => r) ?? [];

                  if (missions.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.flag_outlined,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            context.t('Nenhuma missão encontrada', 'No missions found'),
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: missions.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final mission = missions[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).dividerColor.withValues(alpha: 0.03),
                          ),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: mission.logo != null
                                  ? CachedNetworkImage(
                                      imageUrl: mission.logo!,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: Colors.grey[200],
                                        child: const Icon(
                                          Icons.image,
                                          size: 20,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                            color: Colors.grey[200],
                                            child: const Icon(
                                              Icons.broken_image,
                                              size: 20,
                                              color: Colors.grey,
                                            ),
                                          ),
                                    )
                                  : Container(
                                      width: 50,
                                      height: 50,
                                      color: AppColors.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      child: const Icon(
                                        Icons.flag,
                                        color: AppColors.primary,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mission.name,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<ProfileCubit>()..loadProfile(widget.userId),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: widget.hideAppBar
            ? null
            : AppHeader(mode: HeaderMode.back, title: context.t('Perfil', 'Profile')),
        body: BlocBuilder<ProfileCubit, ProfileState>(
          builder: (context, state) {
            return state.maybeMap(
              loading: (_) => const ProfileShimmer(),
              error: (s) => Center(child: Text(s.message)),
              loaded: (s) {
                final profile = s.profile;
                final posts = s.posts;
                final isMe = s.isMe;
                final isEditing = s.isEditing;

                final authState = getIt<AuthCubit>().state;
                final isAdmin = authState.maybeWhen(
                  authenticated: (user) =>
                      user.roles.contains('COLABORADOR') ||
                      user.roles.contains('MASTER'),
                  orElse: () => false,
                );

                // ── Pick e crop — a imagem fica pendente (preview local) e só é
                //    enviada ao servidor quando o usuário toca em "Salvar".
                Future<void> pickImage(bool isAvatar) async {
                  // 1. Escolher fonte
                  final source = await showModalBottomSheet<ImageSource>(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (context) => ImageSourceBottomSheet(
                      title: isAvatar
                          ? context.t('Alterar foto de perfil', 'Change profile photo')
                          : context.t('Alterar capa', 'Change cover'),
                    ),
                  );
                  if (source == null || !mounted) return;

                  // 2. Selecionar imagem
                  final picker = ImagePicker();
                  final XFile? pickedFile;
                  try {
                    pickedFile = await picker.pickImage(source: source);
                  } catch (_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.t(
                            'Este dispositivo não suporta o uso da câmera.',
                            'This device does not support camera use.',
                          )),
                        ),
                      );
                    }
                    return;
                  }
                  if (pickedFile == null || !mounted) return;

                  // 3. Abrir modal de crop
                  final croppedBytes = await ImageCropperModal.show(
                    context,
                    imageProvider: FileImage(File(pickedFile.path)),
                    cropShape: isAvatar
                        ? CropShape.circle
                        : CropShape.rectangle169,
                  );
                  if (croppedBytes == null || !mounted) return;

                  // 4. Marca como pendente (NÃO envia ainda). O upload só
                  //    acontece em saveChanges(), ao tocar em "Salvar".
                  final cubit = context.read<ProfileCubit>();
                  if (isAvatar) {
                    cubit.setPendingAvatar(croppedBytes);
                  } else {
                    cubit.setPendingCover(croppedBytes);
                  }
                }

                Future<void> handleNewPost(BuildContext context) async {
                  final picker = ImagePicker();
                  final isCamera = await showModalBottomSheet<bool>(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (context) => NewPostBottomSheet(
                      onSourceSelected: (camera) =>
                          Navigator.pop(context, camera),
                    ),
                  );

                  if (isCamera != null) {
                    final source = isCamera
                        ? ImageSource.camera
                        : ImageSource.gallery;
                    try {
                      final image = await picker.pickImage(source: source);
                      if (image != null && context.mounted) {
                        final result = await context.push<bool>(
                          '/create-post',
                          extra: [image],
                        );
                        if (result == true && context.mounted) {
                          context.read<ProfileCubit>().loadProfile();
                        }
                      }
                    } catch (_) {}
                  }
                }

                return SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!widget.hideAppBar) const HeaderSpacer(),
                      ProfileHeaderCover(
                        coverUrl: profile.coverUrl,
                        avatarUrl: profile.avatarUrl,
                        pendingAvatar: s.pendingAvatar,
                        pendingCover: s.pendingCover,
                        isMe: isMe,
                        isEditing: isEditing,
                        isUploadingAvatar: s.isUpdatingAvatar,
                        isUploadingCover: s.isUpdatingCover,
                        onUpdateAvatar: () => pickImage(true),
                        onUpdateCover: () => pickImage(false),
                        statsWidget: Opacity(
                          opacity: isEditing ? 0.3 : 1.0,
                          child: ProfileHeaderStats(
                            connections: profile.connectionsCount,
                            posts: profile.postsCount,
                            missions: isAdmin ? 0 : profile.missionsCount,
                            onConnectionsTap: () {
                              context.push('/connections/${profile.id}');
                            },
                            onPostsTap: _scrollToPosts,
                            onMissionsTap:
                                isAdmin ? () {} : _showMissionsModal,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Opacity(
                        opacity: isEditing ? 0.3 : 1.0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ProfileInfo(
                              name: profile.name,
                              jobTitle: profile.jobTitle,
                              bio: profile.bio,
                              missionName: profile.missionName,
                              isGuide: profile.isGuide,
                              isAdmin: isAdmin,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ProfileActions(
                        isMe: isMe,
                        connectionStatus: profile.connectionStatus,
                        isEditing: isEditing,
                        isUploadingAvatar: s.isUpdatingAvatar,
                        isUploadingCover: s.isUpdatingCover,
                        onConnect: () => context
                            .read<ProfileCubit>()
                            .requestConnection(profile.id),
                        onCancelRequest: () => context
                            .read<ProfileCubit>()
                            .cancelConnection(profile.id),
                        onAccept: () => context
                            .read<ProfileCubit>()
                            .acceptConnection(profile.id),
                        onReject: () => context
                            .read<ProfileCubit>()
                            .rejectConnection(profile.id),
                        onDisconnect: () => context
                            .read<ProfileCubit>()
                            .removeConnection(profile.id),
                        onEditProfile: () =>
                            context.read<ProfileCubit>().toggleEditing(),
                        onSave: () =>
                            context.read<ProfileCubit>().saveChanges(),
                        onPublish: () => handleNewPost(context),
                        phone: profile.phone,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Opacity(
                        key: _postsKey,
                        opacity: isEditing ? 0.3 : 1.0,
                        child: ProfilePostGrid(posts: posts),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
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

class _MissionsShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlight = isDark ? Colors.grey[700]! : Colors.grey[100]!;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Shimmer.fromColors(
          baseColor: base,
          highlightColor: highlight,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

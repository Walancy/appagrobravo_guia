import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agrobravo/core/components/documents_alert_card.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/constants/translations.dart';
import 'package:agrobravo/core/components/custom_confirm_bottom_sheet.dart';

import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/core/di/injection.dart';
import 'package:agrobravo/features/home/presentation/cubit/feed_cubit.dart';
import 'package:agrobravo/features/home/presentation/cubit/feed_state.dart';
import 'package:agrobravo/features/home/presentation/widgets/post_card.dart';
import 'package:agrobravo/features/home/presentation/widgets/comments_bottom_sheet.dart';
import 'package:agrobravo/features/home/presentation/widgets/new_post_bottom_sheet.dart';
import 'package:agrobravo/core/components/app_header.dart';
import 'package:agrobravo/features/chat/presentation/pages/chat_page.dart';
import 'package:agrobravo/features/notifications/presentation/widgets/notification_detail_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:agrobravo/features/home/domain/repositories/feed_repository.dart';
import 'package:agrobravo/features/itinerary/presentation/pages/itinerary_tab.dart';
import 'package:agrobravo/features/itinerary/presentation/cubit/itinerary_cubit.dart';
import 'package:agrobravo/features/profile/presentation/pages/profile_tab.dart';
import 'package:agrobravo/features/documents/presentation/cubit/documents_cubit.dart';
import 'package:agrobravo/features/documents/presentation/cubit/documents_state.dart';
import 'package:agrobravo/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:agrobravo/features/notifications/presentation/cubit/notifications_state.dart';
import 'package:agrobravo/features/home/presentation/widgets/itinerary_microcards.dart';
import 'package:agrobravo/features/home/domain/entities/mission_entity.dart';
import 'package:agrobravo/features/home/presentation/widgets/mission_alert_dialog.dart';
import 'package:agrobravo/features/itinerary/presentation/widgets/emergency_modal.dart';
import 'package:agrobravo/features/home/presentation/pages/guide_home_page.dart';
import 'package:agrobravo/features/home/presentation/pages/guide_dashboard_page.dart';
import 'package:agrobravo/features/home/presentation/pages/community_tab.dart';
import 'package:agrobravo/core/components/feed_shimmer.dart';
import 'package:agrobravo/core/components/empty_mission_state.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  final int initialTab;
  final String? initialGroupId;
  final String? popupTitle;
  final String? popupBody;

  const HomePage({
    super.key,
    this.initialTab = 0,
    this.initialGroupId,
    this.popupTitle,
    this.popupBody,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  String? _selectedGroupId;
  String? _itineraryScrollToItemId;
  String? _lastShownTitle;
  String? _lastShownBody;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab;
    _selectedGroupId = widget.initialGroupId;
    _restoreLastGroup();
    WidgetsBinding.instance.addPostFrameCallback((_) {

      final documentsCubit = context.read<DocumentsCubit>();
      documentsCubit.state.maybeMap(
        initial: (_) => documentsCubit.loadDocuments(),
        orElse: () {},
      );

      final notificationsCubit = context.read<NotificationsCubit>();
      notificationsCubit.state.maybeMap(
        initial: (_) => notificationsCubit.loadNotifications(),
        orElse: () {},
      );

      final itineraryCubit = context.read<ItineraryCubit>();
      itineraryCubit.state.maybeMap(
        initial: (_) => itineraryCubit.loadUserItinerary(),
        orElse: () {},
      );

      // Show notification modal if query params are present
      if (widget.popupTitle != null && widget.popupTitle!.isNotEmpty) {
        _showNotificationDialog(
          widget.popupTitle!,
          widget.popupBody ?? '',
        );
      }
    });
  }

  Future<void> _restoreLastGroup() async {
    // Se já tem groupId via rota, salvar e usar ele
    if (widget.initialGroupId != null) {
      _saveLastGroup(widget.initialGroupId!);
      return;
    }
    // Caso contrário, restaurar o último grupo salvo
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('last_selected_group_id');
      if (saved != null && mounted) {
        setState(() {
          _selectedGroupId = saved;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.read<ItineraryCubit>().loadItinerary(saved);
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _saveLastGroup(String groupId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_selected_group_id', groupId);
    } catch (_) {}
  }

  Future<void> _clearLastGroup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_selected_group_id');
    } catch (_) {}
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      _selectedIndex = widget.initialTab;
    }
    if (widget.initialGroupId != oldWidget.initialGroupId) {
      _selectedGroupId = widget.initialGroupId;
      if (_selectedGroupId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.read<ItineraryCubit>().loadItinerary(_selectedGroupId!);
          }
        });
      }
    }

    if (widget.popupTitle != null &&
        widget.popupTitle!.isNotEmpty &&
        (widget.popupTitle != oldWidget.popupTitle ||
            widget.popupBody != oldWidget.popupBody)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showNotificationDialog(
          widget.popupTitle!,
          widget.popupBody ?? '',
        );
      });
    }
  }

  void _showNotificationDialog(String title, String body) {
    if (_lastShownTitle == title && _lastShownBody == body) return;
    _lastShownTitle = title;
    _lastShownBody = body;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'NotificationDetail',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return NotificationDetailDialog(
          title: title,
          body: body,
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: CurvedAnimation(
            parent: anim1,
            curve: Curves.easeOutBack,
          ).value,
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    ).then((_) {
      if (mounted) {
        context.go('/home?tab=$_selectedIndex${_selectedGroupId != null ? '&groupId=$_selectedGroupId' : ''}');
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _showMissionAlert(BuildContext context, MissionEntity mission) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (dialogContext) => MissionAlertDialog(
            mission: mission,
            onDismiss: (permanently) {
              context.read<FeedCubit>().acknowledgeMissionAlert(
                mission.id,
                permanently: permanently,
              );
              context.read<DocumentsCubit>().dismissAlert();
            },
            onDocumentsTap: () {
              Navigator.pop(dialogContext);
              context.push('/documents');
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<FeedCubit>()..loadFeed(),
      child: BlocListener<DocumentsCubit, DocumentsState>(
        listener: (context, state) {
          state.maybeMap(
            loaded: (s) {
              if (_selectedGroupId != null && s.hasPendingAction && s.mission != null) {
                _showMissionAlert(context, s.mission!);
              }
            },
            orElse: () {},
          );
        },
        child: Builder(
          builder: (context) {
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
                statusBarIconBrightness:
                    Theme.of(context).brightness == Brightness.dark
                        ? Brightness.light
                        : Brightness.dark,
                systemNavigationBarIconBrightness:
                    Theme.of(context).brightness == Brightness.dark
                        ? Brightness.light
                        : Brightness.dark,
                systemNavigationBarDividerColor: Colors.transparent,
                systemNavigationBarContrastEnforced: false,
              ),
              child: Scaffold(
                extendBodyBehindAppBar: true,
                appBar: _buildHeader(context),
                body: _buildBody(context),
                bottomNavigationBar: _buildBottomNav(),
              ),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildHeader(BuildContext context) {
    return AppHeader(
      mode: HeaderMode.home,
      logo: Image.asset('assets/images/logo_colorida.png', height: 32),
      actions: [
        if (_selectedIndex == 3)
          BlocBuilder<FeedCubit, FeedState>(
            builder: (context, state) {
              final canPost = state.maybeWhen(
                loaded: (_, canPost, __) => canPost,
                orElse: () => false,
              );

              return IconButton(
                onPressed: canPost ? () => _handleNewPost(context) : null,
                icon: Icon(
                  Icons.add_circle_outline_rounded,
                  size: 28,
                  color:
                      canPost
                          ? Theme.of(context).colorScheme.onSurface
                          : Colors.grey,
                ),
              );
            },
          ),
        BlocBuilder<NotificationsCubit, NotificationsState>(
          builder: (context, state) {
            final hasUnread = state.hasUnread;
            return IconButton(
              onPressed: () => context.push('/notifications'),
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 28,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  if (hasUnread)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        if (_selectedIndex == 1)
          IconButton(
            onPressed: () => _showEmergencyModal(context),
            icon: const Icon(
              Icons.emergency_outlined,
              size: 28,
              color: Colors.red,
            ),
          ),
      ],
    );
  }

  void _showEmergencyModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const EmergencyModal(),
    );
  }

  Widget _buildBody(BuildContext context) {
    return IndexedStack(
      index: _selectedIndex,
      children: [
        // Tab 0
        Builder(
          builder: (context) {
            if (_selectedGroupId != null) {
              return GuideDashboardPage(
                groupId: _selectedGroupId!,
                onSwitchGroup: () {
                  setState(() {
                    _selectedGroupId = null;
                    // Se estava numa tab que requer grupo, volta para home
                    if (_selectedIndex == 1 || _selectedIndex == 2) {
                      _selectedIndex = 0;
                    }
                  });
                  _clearLastGroup();
                },
                onTabChange: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                onNavigateToEvent: (itemId) {
                  setState(() {
                    _itineraryScrollToItemId = itemId;
                    _selectedIndex = 1;
                  });
                },
              );
            }
            return GuideHomePage(
              onGroupSelected: (groupId) {
                setState(() {
                  _selectedGroupId = groupId;
                  _selectedIndex = 0;
                });
                _saveLastGroup(groupId);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    context.read<ItineraryCubit>().loadItinerary(groupId);
                    context.read<FeedCubit>().state.maybeMap(
                      loaded: (s) {
                        if (s.missionToAlert != null) {
                          _showMissionAlert(context, s.missionToAlert!);
                        }
                      },
                      orElse: () {},
                    );
                  }
                });
              },
            );
          },
        ),
        // Tab 1
        Builder(
          builder: (context) {
            if (_selectedGroupId == null) {
              return EmptyMissionState(
                icon: Icons.explore_off_outlined,
                title: context.t('Nenhum itinerário ativo', 'No active itinerary'),
                description: context.t(
                  'Selecione uma missão na aba Início para visualizar o itinerário.',
                  'Select a mission on the Home tab to view the itinerary.',
                ),
                actionLabel: context.t('Selecionar Missão', 'Select Mission'),
                onActionPressed: () => setState(() => _selectedIndex = 0),
              );
            }
            return ItineraryTab(
              key: ValueKey(_selectedGroupId),
              groupId: _selectedGroupId,
              scrollToItemId: _itineraryScrollToItemId,
              onSwitchGroup: () {
                setState(() {
                  _selectedGroupId = null;
                  _selectedIndex = 0;
                });
              },
              onGroupChanged: (groupId) {
                setState(() {
                  _selectedGroupId = groupId;
                });
              },
            );
          },
        ),
        // Tab 2
        Builder(
          builder: (context) {
            if (_selectedGroupId == null) {
              return EmptyMissionState(
                icon: Icons.chat_bubble_outline_rounded,
                title: context.t('Nenhum chat ativo', 'No active chat'),
                description: context.t(
                  'Selecione uma missão na aba Início para conversar com os viajantes e guias.',
                  'Select a mission on the Home tab to chat with travelers and guides.',
                ),
                actionLabel: context.t('Selecionar Missão', 'Select Mission'),
                onActionPressed: () => setState(() => _selectedIndex = 0),
              );
            }
            return ChatPage(groupId: _selectedGroupId);
          },
        ),
        // Tab 3
        CommunityTab(feedWidget: _buildFeedWidget(context)),
        // Tab 4
        const ProfileTab(),
      ],
    );
  }

  Widget _buildFeedWidget(BuildContext context) {
    return BlocBuilder<FeedCubit, FeedState>(
      builder: (context, state) {
        return state.when(
          initial: () => const SizedBox.shrink(),
          loading: () => const FeedShimmer(),
          error: (message) => Center(child: Text(message)),
          loaded: (posts, _, __) {
            if (posts.isEmpty) {
              return RefreshIndicator(
                onRefresh: () => context.read<FeedCubit>().loadFeed(),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              BlocBuilder<DocumentsCubit, DocumentsState>(
                                builder: (context, state) {
                                  if (state.hasPendingDocuments) {
                                    return const Padding(
                                      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                                      child: DocumentsAlertCard(),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                              ItineraryMicrocards(
                                onSeeAll: () => setState(() => _selectedIndex = 1),
                              ),
                              Expanded(
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 40,
                                      vertical: 32,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 90,
                                          height: 90,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.dynamic_feed_outlined,
                                            size: 38,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        Text(
                                          context.t(
                                            'Nenhuma publicação ainda',
                                            'No posts yet',
                                          ),
                                          style: AppTextStyles.h3.copyWith(
                                            color: Theme.of(context).colorScheme.onSurface,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          context.t(
                                            'As publicações do grupo aparecerão aqui.',
                                            'Group posts will appear here.',
                                          ),
                                          style: AppTextStyles.bodyMedium.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.5),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () => context.read<FeedCubit>().loadFeed(),
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8),
                itemCount: posts.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return BlocBuilder<DocumentsCubit, DocumentsState>(
                      builder: (context, state) {
                        if (state.hasPendingDocuments) {
                          return const Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: DocumentsAlertCard(),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    );
                  }
                  if (index == 1) {
                    return ItineraryMicrocards(
                      onSeeAll: () => setState(() => _selectedIndex = 1),
                    );
                  }

                  final post = posts[index - 2];
                  final currentUserId =
                      getIt<FeedRepository>().getCurrentUserId();
                  final isOwner = post.userId == currentUserId;

                  return PostCard(
                    post: post,
                    isOwner: isOwner,
                    onLike: () => context.read<FeedCubit>().toggleLike(post.id),
                    onComment: () => _showComments(context, post.id),
                    onDelete: () => _confirmDeletePost(context, post.id),
                    onProfileTap: () => context.push('/profile/${post.userId}'),
                    onEdit: () async {
                      final result = await context.push<bool>(
                        '/create-post',
                        extra: {
                          'initialImages':
                              post.images, // Not really used for edit as we pass the whole post, but signature requires list
                          'postToEdit': post,
                        },
                      );
                      if (result == true && context.mounted) {
                        context.read<FeedCubit>().loadFeed();
                      }
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showComments(BuildContext context, String postId) {
    final feedCubit = context.read<FeedCubit>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => CommentsBottomSheet(
            postId: postId,
            onCommentChanged: () => feedCubit.incrementCommentCount(postId),
          ),
    );
  }

  Future<void> _handleNewPost(BuildContext context) async {
    final picker = ImagePicker();
    final isCamera = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => NewPostBottomSheet(
            onSourceSelected: (camera) => Navigator.pop(context, camera),
          ),
    );

    if (isCamera != null) {
      final source = isCamera ? ImageSource.camera : ImageSource.gallery;
      try {
        final image = await picker.pickImage(source: source);
        if (!mounted) return;

        if (image != null) {
          if (context.mounted) {
            final result = await context.push<bool>(
              '/create-post',
              extra: [image],
            );
            if (result == true && context.mounted) {
              context.read<FeedCubit>().loadFeed();
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.t('Este dispositivo não suporta o uso da câmera.', 'This device does not support camera usage.')),
            ),
          );
        }
      }
    }
  }

  void _confirmDeletePost(BuildContext context, String postId) async {
    final feedCubit = context.read<FeedCubit>();
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const CustomConfirmBottomSheet(
        title: 'Excluir Publicação',
        message: 'Tem certeza que deseja excluir esta publicação?',
        confirmLabel: 'Excluir',
        cancelLabel: 'Cancelar',
        confirmColor: Colors.red,
      ),
    );

    if (confirm == true) {
      feedCubit.deletePost(postId);
    }
  }

  Widget _buildBottomNav() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasGroup = _selectedGroupId != null;
    return Container(
      padding: EdgeInsets.fromLTRB(
        0,
        10,
        0,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: isDark
            ? Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.onSurface.withValues(
                    alpha: 0.03,
                  ),
                  width: 1,
                ),
              )
            : null,
        boxShadow: !isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -3),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            0,
            Icons.home_outlined,
            Icons.home_rounded,
            context.t('Início', 'Home'),
          ),
          if (hasGroup)
            _buildNavItem(
              1,
              Icons.explore_outlined,
              Icons.explore_rounded,
              context.t('Itinerário', 'Itinerary'),
            ),
          if (hasGroup)
            _buildNavItem(
              2,
              Icons.chat_bubble_outline_rounded,
              Icons.chat_bubble_rounded,
              context.t('Chats', 'Chats'),
            ),
          _buildNavItem(
            3,
            Icons.group_outlined,
            Icons.group,
            context.t('Comunidade', 'Community'),
          ),
          BlocBuilder<DocumentsCubit, DocumentsState>(
            builder: (context, state) {
              return _buildNavItem(
                4,
                Icons.badge_outlined,
                Icons.badge,
                context.t('Meus dados', 'My data'),
                hasBadge: state.hasPendingAction,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label, {
    bool hasBadge = false,
  }) {
    final isSelected = _selectedIndex == index;
    final color = isSelected
        ? AppColors.primary
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedIndex = index;
          _itineraryScrollToItemId = null;
        }),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(isSelected ? activeIcon : icon, color: color, size: 24),
                if (hasBadge)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              height: 3,
              width: isSelected ? 18.0 : 0.0,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:agrobravo/core/components/app_header.dart';
import 'package:agrobravo/core/components/notifications_shimmer.dart';
import 'package:agrobravo/core/constants/translations.dart';
import 'package:agrobravo/core/di/injection.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/tokens/app_spacing.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/features/home/domain/repositories/feed_repository.dart';
import 'package:agrobravo/features/notifications/domain/entities/notification_entity.dart';
import 'package:agrobravo/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:agrobravo/features/notifications/presentation/cubit/notifications_state.dart';

/// Agrupa notificações por período: Hoje / Ontem / Esta semana / Mais antigas.
class _NotificationGroup {
  final String label;
  final List<NotificationEntity> items;
  _NotificationGroup(this.label, this.items);
}

List<_NotificationGroup> _groupNotifications(
  BuildContext context,
  List<NotificationEntity> notifications,
) {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final yesterdayStart = todayStart.subtract(const Duration(days: 1));
  final weekStart = todayStart.subtract(const Duration(days: 7));

  final today = <NotificationEntity>[];
  final yesterday = <NotificationEntity>[];
  final thisWeek = <NotificationEntity>[];
  final older = <NotificationEntity>[];

  for (final n in notifications) {
    final d = n.createdAt;
    if (!d.isBefore(todayStart)) {
      today.add(n);
    } else if (!d.isBefore(yesterdayStart)) {
      yesterday.add(n);
    } else if (!d.isBefore(weekStart)) {
      thisWeek.add(n);
    } else {
      older.add(n);
    }
  }

  return [
    if (today.isNotEmpty)
      _NotificationGroup(context.t('Hoje', 'Today'), today),
    if (yesterday.isNotEmpty)
      _NotificationGroup(context.t('Ontem', 'Yesterday'), yesterday),
    if (thisWeek.isNotEmpty)
      _NotificationGroup(context.t('Esta semana', 'This week'), thisWeek),
    if (older.isNotEmpty)
      _NotificationGroup(context.t('Mais antigas', 'Older'), older),
  ];
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<NotificationsCubit>()..loadNotifications(),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppHeader(
          mode: HeaderMode.back,
          title: context.t('Notificações', 'Notifications'),
          actions: [
            BlocBuilder<NotificationsCubit, NotificationsState>(
              builder: (context, state) {
                return state.maybeWhen(
                  loaded: (notifications) {
                    if (notifications.isEmpty) return const SizedBox.shrink();
                    final hasUnread = notifications.any((n) => !n.isRead);
                    if (!hasUnread) return const SizedBox.shrink();

                    return TextButton.icon(
                      onPressed: () =>
                          context.read<NotificationsCubit>().markAllAsRead(),
                      icon: const Icon(Icons.done_all_rounded, size: 16),
                      label: Text(
                        context.t('Marcar lidas', 'Mark read'),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                );
              },
            ),
          ],
        ),
        body: BlocBuilder<NotificationsCubit, NotificationsState>(
          builder: (context, state) {
            return state.when(
              initial: () => const NotificationsShimmer(),
              loading: () => const NotificationsShimmer(),
              error: (message) => Center(
                child: Text(
                  message,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
                ),
              ),
              loaded: (notifications) {
                if (notifications.isEmpty) {
                  return _buildEmptyState(context);
                }

                final groups = _groupNotifications(context, notifications);
                final followRequests = notifications
                    .where((n) => n.type == NotificationType.follow)
                    .toList();

                return RefreshIndicator(
                  onRefresh: () =>
                      context.read<NotificationsCubit>().loadNotifications(),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (followRequests.isNotEmpty)
                        SliverToBoxAdapter(
                          child: _FollowRequestsSummary(
                            followRequests: followRequests,
                          ),
                        ),
                      for (final group in groups) ...[
                        SliverToBoxAdapter(
                          child: _SectionHeader(label: group.label),
                        ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return _NotificationItem(
                                notification: group.items[index],
                              );
                            },
                            childCount: group.items.length,
                          ),
                        ),
                      ],
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 40),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => context.read<NotificationsCubit>().loadNotifications(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_off_outlined,
                      size: 36,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.35),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.t('Nenhuma notificação', 'No notifications'),
                    style: AppTextStyles.h3.copyWith(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.t(
                      'Você está em dia com todas as suas notificações.',
                      'You are all caught up with your notifications.',
                    ),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.45),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Header de Seção ─────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1.2,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(
              thickness: 1,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.06),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card de Solicitações de Conexão Agrupadas ────────────────────────────────
class _FollowRequestsSummary extends StatelessWidget {
  final List<NotificationEntity> followRequests;
  const _FollowRequestsSummary({required this.followRequests});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final currentUserId = getIt<FeedRepository>().getCurrentUserId();
            if (currentUserId != null) {
              context.push('/connections/$currentUserId?initialIndex=1');
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: followRequests[0].userAvatar != null
                      ? NetworkImage(followRequests[0].userAvatar!)
                      : null,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                  child: followRequests[0].userAvatar == null
                      ? const Icon(
                          Icons.person,
                          size: 20,
                          color: AppColors.primary,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('Solicitações de conexão', 'Connection requests'),
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        followRequests.length == 1
                            ? followRequests[0].userName
                            : '${followRequests[0].userName} e outros ${followRequests.length - 1}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${followRequests.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Item de Notificação Individal ────────────────────────────────────────────
class _NotificationItem extends StatelessWidget {
  final NotificationEntity notification;
  const _NotificationItem({required this.notification});

  String _formatTime(BuildContext context, DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return context.t('Agora mesmo', 'Just now');
    if (diff.inMinutes < 60) {
      return context.t('Há ${diff.inMinutes} min', '${diff.inMinutes}m ago');
    }
    if (diff.inHours < 24) {
      return context.t('Há ${diff.inHours} h', '${diff.inHours}h ago');
    }
    if (diff.inDays == 1) return context.t('Ontem', 'Yesterday');
    if (diff.inDays < 7) {
      return context.t('Há ${diff.inDays} dias', '${diff.inDays}d ago');
    }
    final weeks = (diff.inDays / 7).floor();
    return context.t('Há $weeks sem', '${weeks}w ago');
  }

  void _handleTap(BuildContext context) {
    if (!notification.isRead) {
      context.read<NotificationsCubit>().markAsRead(notification.id);
    }

    if (notification.targetRoute != null && notification.targetRoute!.isNotEmpty) {
      final route = notification.targetRoute!;
      if (route.startsWith('/')) {
        try {
          context.push(route);
          return;
        } catch (_) {}
      }
    }

    if (notification.type == NotificationType.follow) {
      final currentUserId = getIt<FeedRepository>().getCurrentUserId();
      if (currentUserId != null) {
        context.push('/connections/$currentUserId?initialIndex=1');
      }
    } else if (notification.type == NotificationType.like ||
        notification.type == NotificationType.comment ||
        notification.type == NotificationType.mention) {
      if (notification.postId != null && notification.postOwnerId != null) {
        context.go('/user-feed/${notification.postOwnerId}?postId=${notification.postId}');
      }
    } else if (notification.type == NotificationType.documentApproved ||
        notification.type == NotificationType.documentRejected ||
        notification.type == NotificationType.documentPending) {
      context.go('/documents');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUnread = !notification.isRead;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: isUnread
            ? (isDark
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.primary.withValues(alpha: 0.05))
            : (isDark
                ? Theme.of(context).colorScheme.surface
                : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread
              ? AppColors.primary.withValues(alpha: 0.25)
              : (isDark
                  ? Colors.white10
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06)),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _handleTap(context),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LeadingIconWidget(notification: notification),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.35,
                          ),
                          children: [
                            TextSpan(
                              text: notification.userName,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const TextSpan(text: ' '),
                            TextSpan(text: notification.message),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatTime(context, notification.createdAt),
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 11,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isUnread)
                  Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(top: 4, left: 8),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Ícone ou Avatar de Contexto ─────────────────────────────────────────────
class _LeadingIconWidget extends StatelessWidget {
  final NotificationEntity notification;
  const _LeadingIconWidget({required this.notification});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color bgColor;
    Color iconColor;

    switch (notification.type) {
      case NotificationType.documentApproved:
        icon = Icons.check_circle_rounded;
        bgColor = Colors.green.withValues(alpha: 0.12);
        iconColor = Colors.green.shade600;
        break;
      case NotificationType.documentRejected:
        icon = Icons.cancel_rounded;
        bgColor = AppColors.error.withValues(alpha: 0.12);
        iconColor = AppColors.error;
        break;
      case NotificationType.documentPending:
        icon = Icons.pending_rounded;
        bgColor = Colors.orange.withValues(alpha: 0.12);
        iconColor = Colors.orange.shade700;
        break;
      case NotificationType.guideAlert:
        icon = Icons.campaign_rounded;
        bgColor = AppColors.primary.withValues(alpha: 0.12);
        iconColor = AppColors.primary;
        break;
      case NotificationType.like:
        icon = Icons.favorite_rounded;
        bgColor = Colors.pink.withValues(alpha: 0.12);
        iconColor = Colors.pink.shade400;
        break;
      case NotificationType.comment:
        icon = Icons.chat_bubble_rounded;
        bgColor = Colors.blue.withValues(alpha: 0.12);
        iconColor = Colors.blue.shade500;
        break;
      case NotificationType.mention:
        icon = Icons.alternate_email_rounded;
        bgColor = Colors.purple.withValues(alpha: 0.12);
        iconColor = Colors.purple.shade400;
        break;
      default:
        icon = Icons.notifications_rounded;
        bgColor = AppColors.secondary.withValues(alpha: 0.12);
        iconColor = AppColors.secondary;
    }

    if (notification.userAvatar != null && notification.userAvatar!.isNotEmpty) {
      return Stack(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage(notification.userAvatar!),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 1.5,
                ),
              ),
              child: Icon(icon, size: 10, color: iconColor),
            ),
          ),
        ],
      );
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: iconColor),
    );
  }
}

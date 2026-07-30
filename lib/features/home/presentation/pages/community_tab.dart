import 'package:flutter/material.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/core/components/app_header.dart';
import 'package:agrobravo/core/constants/translations.dart';
import 'package:agrobravo/features/profile/presentation/pages/social_profile_page.dart';
import 'package:agrobravo/features/home/domain/repositories/feed_repository.dart';
import 'package:agrobravo/core/di/injection.dart';

class CommunityTab extends StatefulWidget {
  final Widget feedWidget;

  const CommunityTab({super.key, required this.feedWidget});

  @override
  State<CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends State<CommunityTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentUserId = getIt<FeedRepository>().getCurrentUserId() ?? '';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        const HeaderSpacer(),
        Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.onSurface.withValues(
                  alpha: 0.03,
                ),
                width: 0.5,
              ),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
            indicatorColor: AppColors.primary,
            indicatorWeight: 2.5,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            labelStyle: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            unselectedLabelStyle: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
            tabs: [
              Tab(text: context.t('Feed', 'Feed')),
              Tab(text: context.t('Meu Perfil', 'My Profile')),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              widget.feedWidget,
              SocialProfilePage(userId: _currentUserId, hideAppBar: true),
            ],
          ),
        ),
      ],
    );
  }
}

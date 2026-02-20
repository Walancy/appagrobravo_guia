import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:agrobravo/core/tokens/app_spacing.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';

enum HeaderMode { home, back }

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final HeaderMode mode;
  final String? title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? logo;
  final VoidCallback? onTitleTap;

  const AppHeader({
    super.key,
    required this.mode,
    this.title,
    this.subtitle,
    this.actions,
    this.logo,
    this.onTitleTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
            border: Border(
              bottom: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: _buildContent(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (mode == HeaderMode.home) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          logo ?? const SizedBox.shrink(),
          if (actions != null) Row(children: actions!),
        ],
      );
    }

    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        if (logo != null) ...[const SizedBox(width: AppSpacing.sm), logo!],
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: GestureDetector(
            onTap: onTitleTap,
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: AppTextStyles.h3.copyWith(fontSize: 18),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
        if (actions != null) Row(children: actions!),
      ],
    );
  }

  @override
  Size get preferredSize {
    // Must include the device top inset (status bar) so Scaffold allocates the correct space.
    // We don't have BuildContext here, so we use a fixed 51 — the SafeArea inside handles
    // the actual top padding at render time. Scaffold reads this value to offset the body.
    return const Size.fromHeight(51);
  }
}

class HeaderSpacer extends StatelessWidget {
  final double extraHeight;

  const HeaderSpacer({super.key, this.extraHeight = 20});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return SizedBox(height: topPadding + extraHeight);
  }
}

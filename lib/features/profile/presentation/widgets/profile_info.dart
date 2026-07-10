import 'package:flutter/material.dart';

import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/tokens/app_spacing.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/core/tokens/assets.gen.dart';
import 'package:agrobravo/core/constants/translations.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ProfileInfo extends StatelessWidget {
  final String name;
  final String? jobTitle;
  final String? bio;
  final String? missionName;
  final bool isGuide;
  final bool isAdmin;

  const ProfileInfo({
    super.key,
    required this.name,
    this.jobTitle,
    this.bio,
    this.missionName,
    this.isGuide = false,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: AppTextStyles.h2.copyWith(fontSize: 22),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          // Tag de Admin / Guia oficial / Cargo
          if (isAdmin) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  context.t('Administrador', 'Administrator'),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                SvgPicture.asset(Assets.images.logoColoridaSvg, height: 16),
              ],
            ),
          ] else if (isGuide) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  context.t('Guia oficial', 'Official guide'),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                SvgPicture.asset(Assets.images.logoColoridaSvg, height: 16),
              ],
            ),
          ] else if (jobTitle != null && jobTitle!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              jobTitle!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          if (!isAdmin && missionName != null && missionName!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _InfoChip(
                  label: missionName!,
                  icon: Icons.flag_outlined,
                  color: AppColors.primary,
                ),
              ],
            ),
          ],

          if (bio != null && bio!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              bio!,
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _InfoChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 64,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

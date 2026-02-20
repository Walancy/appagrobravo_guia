import 'package:flutter/material.dart';

import 'package:agrobravo/core/tokens/app_spacing.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/core/tokens/assets.gen.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ProfileInfo extends StatelessWidget {
  final String name;
  final String? jobTitle;
  final String? bio;
  final String? missionName;
  final bool isGuide;

  const ProfileInfo({
    super.key,
    required this.name,
    this.jobTitle,
    this.bio,
    this.missionName,
    this.isGuide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nome
          Text(
            name,
            style: AppTextStyles.h2.copyWith(fontSize: 22),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          // Nome da Missão e Grupo
          if (missionName != null && missionName!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 1, bottom: 4),
              child: Text(
                missionName!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Cargo ou Tag de Guia
          if (isGuide)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  Text(
                    'Guia oficial',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SvgPicture.asset(Assets.images.logoColorida, height: 16),
                ],
              ),
            )
          else if (jobTitle != null && jobTitle!.isNotEmpty)
            Text(
              jobTitle!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

          const SizedBox(height: AppSpacing.xs),
        ],
      ),
    );
  }
}

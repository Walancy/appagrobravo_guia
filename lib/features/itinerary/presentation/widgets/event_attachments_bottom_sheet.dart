import 'package:flutter/material.dart';
import '../../../../core/tokens/app_colors.dart';
import '../../../../core/tokens/app_spacing.dart';
import '../../../../core/tokens/app_text_styles.dart';
import 'package:url_launcher/url_launcher.dart';

class EventAttachmentsBottomSheet extends StatelessWidget {
  final String eventName;
  final String? menuUrl;
  final List<String>? attachments;
  final IconData eventIcon;

  const EventAttachmentsBottomSheet({
    super.key,
    required this.eventName,
    this.menuUrl,
    this.attachments,
    required this.eventIcon,
  });

  @override
  Widget build(BuildContext context) {
    final hasMenu = menuUrl != null && menuUrl!.isNotEmpty;
    final hasAttachments = attachments != null && attachments!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
              Icon(eventIcon, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  eventName,
                  style: AppTextStyles.h3.copyWith(fontSize: 18),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (hasMenu) ...[
            _buildSection(
              context,
              title: 'Cardápio',
              items: [menuUrl!],
              icon: Icons.restaurant_menu,
              isMenu: true,
            ),
            if (hasAttachments) const SizedBox(height: 24),
          ],
          if (hasAttachments)
            _buildSection(
              context,
              title: 'Anexos',
              items: attachments!,
              icon: Icons.description_outlined,
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<String> items,
    required IconData icon,
    bool isMenu = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items.map((url) {
          final fileName = url.split('/').last.split('?').first;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isMenu ? Icons.restaurant : Icons.file_present_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isMenu ? 'Acessar Cardápio' : fileName,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.open_in_new_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

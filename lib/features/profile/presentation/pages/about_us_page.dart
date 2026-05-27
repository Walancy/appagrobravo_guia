import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/tokens/app_spacing.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/core/components/app_header.dart';
import 'package:agrobravo/core/constants/translations.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppHeader(mode: HeaderMode.back, title: context.t('Sobre nós', 'About us')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xxl),
            SvgPicture.asset('assets/images/logo_colorida.svg', height: 100),
            const SizedBox(height: AppSpacing.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: Text(
                context.t('Conexões que transformam o agro.', 'Connections that transform agribusiness.'),
                textAlign: TextAlign.center,
                style: AppTextStyles.h2.copyWith(color: AppColors.primary),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            _buildAboutContent(context),
            const SizedBox(height: AppSpacing.xxl),
            _buildValues(context),
            const SizedBox(height: AppSpacing.xxl),
            _buildVersionInfo(context),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          Text(
            context.t(
              'A AgroBravo Enterprises é uma plataforma de conexões estratégicas no agronegócio global. Com mais de 12 anos de história e presença em 5 continentes, conectamos o agronegócio entre Brasil, EUA, Ásia, América Latina e Europa.',
              'AgroBravo Enterprises is a platform for strategic connections in global agribusiness. With over 12 years of history and a presence on 5 continents, we connect agribusiness between Brazil, the USA, Asia, Latin America and Europe.',
            ),
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyLarge.copyWith(height: 1.6),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            context.t(
              'Nossa visão é construir pontes estratégicas para impulsionar o agronegócio além das fronteiras, proporcionando acesso exclusivo às tecnologias mais avançadas e networking de alto nível.',
              'Our vision is to build strategic bridges to drive agribusiness beyond borders, providing exclusive access to the most advanced technologies and high-level networking.',
            ),
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValues(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      color: AppColors.primary.withOpacity(0.05),
      child: Column(
        children: [
          _buildValueItem(
            context,
            Icons.public,
            context.t('Conexão Global', 'Global Connection'),
            context.t('Presença estratégica na Ásia, Europa, EUA e América Latina.', 'Strategic presence in Asia, Europe, the USA and Latin America.'),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildValueItem(
            context,
            Icons.lightbulb_outline,
            context.t('Expertise Técnica', 'Technical Expertise'),
            context.t('Conhecimento tático e inteligência de mercado aplicada ao campo.', 'Tactical knowledge and market intelligence applied to the field.'),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildValueItem(
            context,
            Icons.groups_outlined,
            context.t('Networking de Alto Nível', 'High-Level Networking'),
            context.t('Ecossistema completo de facilitação de negócios internacionais.', 'Complete ecosystem for facilitating international business.'),
          ),
        ],
      ),
    );
  }

  Widget _buildValueItem(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 28),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVersionInfo(BuildContext context) {
    return Column(
      children: [
        Text(
          'AgroBravo Mobile App',
          style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Versão 1.0.0 (Build 2026)',
          style: AppTextStyles.bodySmall.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          '© 2026 AgroBravo. ' + context.t('Todos os direitos reservados.', 'All rights reserved.'),
          style: AppTextStyles.bodySmall.copyWith(
            color: Colors.grey[400],
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

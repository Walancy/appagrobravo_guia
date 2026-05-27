import 'package:flutter/material.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/tokens/app_spacing.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/core/components/app_header.dart';
import 'package:agrobravo/core/constants/translations.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppHeader(
        mode: HeaderMode.back,
        title: context.t('Política de Privacidade', 'Privacy Policy'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t(
                'AgroBravo Enterprises - Compromisso com sua Privacidade',
                'AgroBravo Enterprises - Our Commitment to Your Privacy',
              ),
              style: AppTextStyles.h3.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              context.t(
                'A AgroBravo Enterprises, com sede em Ames, Iowa (EUA) e filial no Brasil, valoriza a confiança que você deposita em nós. Esta política descreve como tratamos suas informações pessoais.',
                'AgroBravo Enterprises, headquartered in Ames, Iowa (USA) with a branch in Brazil, values the trust you place in us. This policy describes how we handle your personal information.',
              ),
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            _buildSection(
              context,
              context.t('1. Coleta de Informações', '1. Information Collection'),
              context.t(
                'Coletamos informações quando você utiliza nossos serviços, preenche formulários ou participa de nossas missões. Isso inclui nome completo, e-mail, telefone, nome da empresa, informações de pagamento e detalhes necessários para logística de viagens (como passaporte e vistos).',
                'We collect information when you use our services, fill out forms, or participate in our missions. This includes full name, email, phone, company name, payment information and details required for travel logistics (such as passport and visas).',
              ),
            ),

            _buildSection(
              context,
              context.t('2. Uso dos Dados', '2. Data Use'),
              context.t(
                'Utilizamos seus dados para:\n• Processar e gerenciar missões técnicas e viagens.\n• Enviar atualizações sobre o mercado e novas oportunidades de negócios.\n• Prestar suporte personalizado durante eventos.\n• Cumprir obrigações legais e regulatórias.',
                'We use your data to:\n• Process and manage technical missions and trips.\n• Send market updates and new business opportunities.\n• Provide personalized support during events.\n• Comply with legal and regulatory obligations.',
              ),
            ),

            _buildSection(
              context,
              context.t('3. Compartilhamento e Proteção', '3. Sharing & Protection'),
              context.t(
                'Não compartilhamos informações com terceiros, exceto quando necessário para a prestação de serviços (parcerias logísticas, hotéis, órgãos governamentais) ou por obrigação legal. Adotamos práticas de criptografia e medidas de segurança para proteger sua privacidade.',
                'We do not share information with third parties, except when necessary for service delivery (logistics partners, hotels, government agencies) or by legal obligation. We adopt encryption practices and security measures to protect your privacy.',
              ),
            ),

            _buildSection(
              context,
              context.t('4. Aplicativo Móvel', '4. Mobile Application'),
              context.t(
                'Nosso aplicativo pode coletar fotos e vídeos fornecidos por você para funcionalidade social e registro de missões. Estes dados não são compartilhados com fins comerciais externos e você pode solicitar a eliminação de sua conta e dados a qualquer momento.',
                'Our application may collect photos and videos provided by you for social functionality and mission records. This data is not shared for external commercial purposes and you may request the deletion of your account and data at any time.',
              ),
            ),

            _buildSection(
              context,
              context.t('5. Seus Direitos', '5. Your Rights'),
              context.t(
                'Você tem o direito de acessar, retificar ou solicitar a exclusão de seus dados pessoais. Para exercer esses direitos, entre em contato conosco através dos canais de suporte no aplicativo.',
                'You have the right to access, rectify, or request the deletion of your personal data. To exercise these rights, contact us through the support channels in the application.',
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
            Center(
              child: Text(
                context.t(
                  'Última atualização: 22 de Abril de 2025',
                  'Last updated: April 22, 2025',
                ),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            content,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

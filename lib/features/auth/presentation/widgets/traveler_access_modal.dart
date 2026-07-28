import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';

void showTravelerAccessModal(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => const TravelerAccessDialog(),
  );
}

class TravelerAccessDialog extends StatelessWidget {
  const TravelerAccessDialog({super.key});

  static const String _iosAppUrl =
      'https://apps.apple.com/br/app/agrobravo/id6748480940';
  static const String _androidAppUrl =
      'https://play.google.com/store/apps/details?id=com.agrobravo.agrobravoapp';

  Future<void> _openStore() async {
    final urlString = defaultTargetPlatform == TargetPlatform.iOS
        ? _iosAppUrl
        : _androidAppUrl;
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final storeName = isIOS ? 'App Store' : 'Google Play Store';

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 10,
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Container do Ícone
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.card_travel_rounded,
                size: 38,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),

            // Título
            Text(
              'Conta de Viajante',
              style: AppTextStyles.h3.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Descrição
            Text(
              'Este aplicativo é exclusivo para a gestão de viagens por Guias AgroBravo.\n\nComo sua conta é de Viajante, utilize o app oficial para acessar seu roteiro, voos e documentos.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // Botão Principal (Baixar App na Loja)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _openStore();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(
                  isIOS ? Icons.apple : Icons.shop_rounded,
                  size: 22,
                ),
                label: Text(
                  'Baixar no $storeName',
                  style: AppTextStyles.button.copyWith(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Botão Secundário (Fechar)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Entendido',
                  style: AppTextStyles.button.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

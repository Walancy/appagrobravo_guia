import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/core/constants/translations.dart';

/// Exibe um BottomSheet para o usuário escolher em qual app de mapa
/// abrir uma localização textual (endereço ou nome do lugar).
class MapPickerSheet {
  MapPickerSheet._();

  static Future<void> show(
    BuildContext context, {
    required String location,
    String? destination,
    bool? isAsia,
  }) async {
    final query = Uri.encodeComponent(location);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isAsiaDestination = _checkIsAsia(location, destination, isAsia);

    final options = <_MapOption>[
      _MapOption(
        label: 'Google Maps',
        icon: Icons.map_rounded,
        color: const Color(0xFF4285F4),
        uri: Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$query',
        ),
        nativeUri: Platform.isIOS
            ? Uri.parse('comgooglemaps://?q=$query')
            : Uri.parse('geo:0,0?q=$query'),
      ),
      _MapOption(
        label: 'Apple Maps',
        icon: Icons.apple_rounded,
        color: const Color(0xFF000000),
        uri: Uri.parse('https://maps.apple.com/?q=$query'),
        iosOnly: true,
      ),
      if (isAsiaDestination)
        _MapOption(
          label: 'Baidu Maps',
          icon: Icons.navigation_rounded,
          color: const Color(0xFF3385FF),
          uri: Uri.parse(
            'baidumap://map/geocoder?src=webapp.location.picker&addr=$query',
          ),
          fallbackUri: Uri.parse(
            'https://map.baidu.com/search/$query/',
          ),
        ),
      _MapOption(
        label: 'Waze',
        icon: Icons.directions_car_rounded,
        color: const Color(0xFF33CCFF),
        uri: Uri.parse('waze://?q=$query'),
        fallbackUri: Uri.parse(
          'https://waze.com/ul?q=$query',
        ),
      ),
    ];

    final filtered =
        options.where((o) => !o.iosOnly || Platform.isIOS).toList();

    if (context.mounted) {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _MapPickerContent(
          options: filtered,
          location: location,
          isDark: isDark,
        ),
      );
    }
  }

  static bool _checkIsAsia(String? location, String? destination, bool? isAsiaParam) {
    if (isAsiaParam == true) return true;
    final combined = '${location ?? ''} ${destination ?? ''}'.toLowerCase();
    final keywords = [
      'asia', 'ásia', 'china', 'beijing', 'pequim', 'shanghai', 'xangai',
      'hong kong', 'guangzhou', 'shenzhen', 'chengdu', 'wuhan', 'xi\'an',
      'xian', 'tokyo', 'toquio', 'tóquio', 'japan', 'japão', 'korea', 'coreia', 'seoul'
    ];
    return keywords.any((k) => combined.contains(k));
  }
}

class _MapOption {
  final String label;
  final IconData icon;
  final Color color;
  final Uri uri;
  final Uri? nativeUri;
  final Uri? fallbackUri;
  final bool iosOnly;

  const _MapOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.uri,
    this.nativeUri,
    this.fallbackUri,
    this.iosOnly = false,
  });
}

class _MapPickerContent extends StatelessWidget {
  final List<_MapOption> options;
  final String location;
  final bool isDark;

  const _MapPickerContent({
    required this.options,
    required this.location,
    required this.isDark,
  });

  Future<void> _open(_MapOption option, BuildContext context) async {
    Navigator.of(context).pop();

    if (option.nativeUri != null &&
        await canLaunchUrl(option.nativeUri!)) {
      await launchUrl(option.nativeUri!,
          mode: LaunchMode.externalApplication);
      return;
    }

    if (await canLaunchUrl(option.uri)) {
      await launchUrl(option.uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (option.fallbackUri != null &&
        await canLaunchUrl(option.fallbackUri!)) {
      await launchUrl(option.fallbackUri!,
          mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.t('Abrir localização em', 'Open location in'),
            style: AppTextStyles.h3.copyWith(fontSize: 17),
          ),
          const SizedBox(height: 4),
          Text(
            location,
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.grey,
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          ...options.map(
            (opt) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => _open(opt, context),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.grey[200]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: opt.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(opt.icon, color: opt.color, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        opt.label,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

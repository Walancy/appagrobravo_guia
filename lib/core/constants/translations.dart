import 'package:flutter/material.dart';

extension TranslationExtension on BuildContext {
  /// Retorna o texto correspondente de acordo com o idioma do aplicativo.
  /// Se o idioma ativo for inglês (en), retorna [enText]. Caso contrário, [ptText].
  String t(String ptText, String enText) {
    try {
      final locale = Localizations.localeOf(this).languageCode;
      return locale == 'en' ? enText : ptText;
    } catch (_) {
      // Fallback para português em caso de erro ao obter local do contexto
      return ptText;
    }
  }
}

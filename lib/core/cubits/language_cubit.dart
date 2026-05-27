import 'dart:ui';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

@injectable
class LanguageCubit extends Cubit<Locale> {
  static const String _languageKey = 'app_language';

  LanguageCubit() : super(const Locale('pt')) {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString(_languageKey);
      if (lang != null) {
        emit(Locale(lang));
      } else {
        // Fallback para o idioma do celular
        final systemLocale = PlatformDispatcher.instance.locale.languageCode;
        if (systemLocale.startsWith('en')) {
          emit(const Locale('en'));
        } else {
          emit(const Locale('pt'));
        }
      }
    } catch (_) {
      emit(const Locale('pt'));
    }
  }

  Future<void> setLanguage(String langCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, langCode);
      emit(Locale(langCode));
    } catch (_) {
      emit(Locale(langCode));
    }
  }
}

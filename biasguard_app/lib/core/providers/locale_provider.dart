import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLocale { en, hi }

class LocaleNotifier extends StateNotifier<AppLocale> {
  LocaleNotifier() : super(AppLocale.en) {
    _loadLocale();
  }

  static const _key = 'app_locale';

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_key);
    if (val == 'hi') {
      state = AppLocale.hi;
    } else {
      state = AppLocale.en;
    }
  }

  Future<void> toggleLocale() async {
    final prefs = await SharedPreferences.getInstance();
    if (state == AppLocale.en) {
      state = AppLocale.hi;
      await prefs.setString(_key, 'hi');
    } else {
      state = AppLocale.en;
      await prefs.setString(_key, 'en');
    }
  }

  bool get isHindi => state == AppLocale.hi;
}

final localeProvider = StateNotifierProvider<LocaleNotifier, AppLocale>((ref) {
  return LocaleNotifier();
});

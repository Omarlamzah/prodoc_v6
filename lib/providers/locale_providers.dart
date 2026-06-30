// lib/providers/locale_providers.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Locale state
class LocaleState {
  final Locale locale;

  LocaleState(this.locale);
}

// Locale notifier
class LocaleNotifier extends Notifier<LocaleState> {
  static const String _localeKey = 'selected_locale';

  @override
  LocaleState build() {
    Future.microtask(() => _loadLocale());
    return LocaleState(const Locale('en', 'US'));
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final localeCode = prefs.getString(_localeKey);

    debugPrint('[LocaleProvider] Loading locale from storage: $localeCode');

    if (localeCode != null) {
      final parts = localeCode.split('_');
      if (parts.length == 2) {
        final loadedLocale = Locale(parts[0], parts[1]);
        state = LocaleState(loadedLocale);
        debugPrint(
            '[LocaleProvider] Loaded locale: ${loadedLocale.languageCode}_${loadedLocale.countryCode}');
      } else {
        final loadedLocale = Locale(parts[0]);
        state = LocaleState(loadedLocale);
        debugPrint(
            '[LocaleProvider] Loaded locale: ${loadedLocale.languageCode}');
      }
    } else {
      // Default to system locale or English
      state = LocaleState(const Locale('en', 'US'));
      debugPrint('[LocaleProvider] No saved locale, using default: en_US');
    }
  }

  Future<void> setLocale(Locale locale) async {
    debugPrint(
        '[LocaleProvider] setLocale called with: ${locale.languageCode}_${locale.countryCode}');
    debugPrint(
        '[LocaleProvider] Current state before change: ${state.locale.languageCode}_${state.locale.countryCode}');

    final prefs = await SharedPreferences.getInstance();
    final localeString = '${locale.languageCode}_${locale.countryCode ?? ''}';
    await prefs.setString(_localeKey, localeString);
    debugPrint(
        '[LocaleProvider] Saved locale to SharedPreferences: $localeString');

    // Update state after saving to ensure UI rebuilds
    state = LocaleState(locale);
    debugPrint(
        '[LocaleProvider] State updated to: ${state.locale.languageCode}_${state.locale.countryCode}');
    debugPrint(
        '[LocaleProvider] State change complete - UI should rebuild now');
  }

  Future<void> setLanguage(String languageCode) async {
    Locale newLocale;
    if (languageCode == 'fr') {
      newLocale = const Locale('fr', 'FR');
    } else if (languageCode == 'ar') {
      newLocale = const Locale('ar', 'SA');
    } else {
      newLocale = const Locale('en', 'US');
    }
    await setLocale(newLocale);
  }

  /// Check if this is the first launch (no locale has been saved yet)
  Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final localeCode = prefs.getString(_localeKey);
    return localeCode == null;
  }
}

// Locale provider
final localeProvider =
    NotifierProvider<LocaleNotifier, LocaleState>(LocaleNotifier.new);

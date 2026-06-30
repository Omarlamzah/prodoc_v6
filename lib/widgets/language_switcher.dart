// lib/widgets/language_switcher.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/locale_providers.dart';
import '../l10n/app_localizations.dart';

class LanguageSwitcherDialog extends ConsumerWidget {
  const LanguageSwitcherDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeState = ref.watch(localeProvider);
    final localizations = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(localizations?.language ?? 'Language'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<Locale>(
            title: Text(localizations?.english ?? 'English'),
            value: const Locale('en', 'US'),
            groupValue: localeState.locale,
            onChanged: (Locale? value) async {
              if (value != null) {
                debugPrint(
                    '[LanguageSwitcher] English selected: ${value.languageCode}_${value.countryCode}');
                debugPrint(
                    '[LanguageSwitcher] Current locale before change: ${localeState.locale.languageCode}_${localeState.locale.countryCode}');
                await ref.read(localeProvider.notifier).setLocale(value);
                debugPrint(
                    '[LanguageSwitcher] Locale change completed, closing dialog');
                if (context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
          ),
          RadioListTile<Locale>(
            title: Text(localizations?.french ?? 'French'),
            value: const Locale('fr', 'FR'),
            groupValue: localeState.locale,
            onChanged: (Locale? value) async {
              if (value != null) {
                debugPrint(
                    '[LanguageSwitcher] French selected: ${value.languageCode}_${value.countryCode}');
                debugPrint(
                    '[LanguageSwitcher] Current locale before change: ${localeState.locale.languageCode}_${localeState.locale.countryCode}');
                await ref.read(localeProvider.notifier).setLocale(value);
                debugPrint(
                    '[LanguageSwitcher] Locale change completed, closing dialog');
                if (context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
          ),
          RadioListTile<Locale>(
            title: Text(localizations?.arabic ?? 'Arabic'),
            value: const Locale('ar', 'SA'),
            groupValue: localeState.locale,
            onChanged: (Locale? value) async {
              if (value != null) {
                debugPrint(
                    '[LanguageSwitcher] Arabic selected: ${value.languageCode}_${value.countryCode}');
                debugPrint(
                    '[LanguageSwitcher] Current locale before change: ${localeState.locale.languageCode}_${localeState.locale.countryCode}');
                await ref.read(localeProvider.notifier).setLocale(value);
                debugPrint(
                    '[LanguageSwitcher] Locale change completed, closing dialog');
                if (context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

// Helper function to show language switcher dialog
void showLanguageSwitcher(BuildContext context) {
  debugPrint('[LanguageSwitcher] showLanguageSwitcher called');
  // Use the root navigator to ensure dialog shows even if drawer is closing
  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      debugPrint('[LanguageSwitcher] Dialog builder called');
      return const LanguageSwitcherDialog();
    },
    barrierDismissible: true,
  ).then((_) {
    debugPrint('[LanguageSwitcher] Dialog closed');
  });
}

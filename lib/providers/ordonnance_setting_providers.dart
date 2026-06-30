// lib/providers/ordonnance_setting_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/ordonnance_setting_model.dart';
import '../core/utils/result.dart';
import 'api_providers.dart';
import 'auth_providers.dart';

// Ordonnance Settings Provider
final ordonnanceSettingsProvider =
    FutureProvider.autoDispose<Result<OrdonnanceSettingModel>>(
  (ref) async {
    final authState = ref.watch(authProvider);

    if (authState.isAuth != true) {
      return const Failure('Not authenticated');
    }

    final ordonnanceSettingService =
        ref.watch(ordonnanceSettingServiceProvider);
    return await ordonnanceSettingService.getOrdonnanceSettings();
  },
);

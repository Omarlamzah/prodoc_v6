// lib/providers/service_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/service_service.dart';
import '../data/models/service_model.dart';
import '../core/utils/result.dart';
import 'api_providers.dart';
import 'auth_providers.dart';

// Services Provider
final servicesProvider = FutureProvider.autoDispose<Result<List<ServiceModel>>>((ref) async {
  final authState = ref.watch(authProvider);
  
  if (authState.isAuth != true) {
    return const Failure('Not authenticated');
  }
  
  final serviceService = ref.watch(serviceServiceProvider);
  return await serviceService.fetchServices();
});


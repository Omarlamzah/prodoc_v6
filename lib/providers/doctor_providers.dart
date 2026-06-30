// lib/providers/doctor_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/doctor_service.dart';
import '../data/models/doctor_model.dart';
import '../core/utils/result.dart';
import 'api_providers.dart';
import 'auth_providers.dart';

// Doctors Provider
final doctorsProvider = FutureProvider.autoDispose<Result<List<DoctorModel>>>((ref) async {
  final authState = ref.watch(authProvider);
  
  if (authState.isAuth != true) {
    return const Failure('Not authenticated');
  }
  
  final doctorService = ref.watch(doctorServiceProvider);
  return await doctorService.fetchDoctors();
});


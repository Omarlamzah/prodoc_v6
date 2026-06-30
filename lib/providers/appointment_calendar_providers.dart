// lib/providers/appointment_calendar_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/appointment_service.dart';
import '../data/models/appointment_model.dart';
import '../core/utils/result.dart';
import 'api_providers.dart';
import 'auth_providers.dart';

// Appointments by Date Provider
final appointmentsByDateProvider = FutureProvider.autoDispose
    .family<Result<List<AppointmentModel>>, AppointmentsByDateParams>((ref, params) async {
  final authState = ref.watch(authProvider);
  
  if (authState.isAuth != true) {
    return const Failure('Not authenticated');
  }
  
  final appointmentService = ref.watch(appointmentServiceProvider);
  return await appointmentService.fetchAppointmentsByDate(
    year: params.year,
    month: params.month,
  );
});

class AppointmentsByDateParams {
  final int year;
  final int month;

  AppointmentsByDateParams({required this.year, required this.month});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppointmentsByDateParams &&
          runtimeType == other.runtimeType &&
          year == other.year &&
          month == other.month;

  @override
  int get hashCode => year.hashCode ^ month.hashCode;
}


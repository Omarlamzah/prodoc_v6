// lib/providers/public_appointment_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/doctor_model.dart';
import '../data/models/service_model.dart';
import '../data/models/time_slot_model.dart';
import '../core/utils/result.dart';
import 'api_providers.dart';

// Public Doctors Provider (no auth required)
final publicDoctorsProvider = FutureProvider.autoDispose<Result<List<DoctorModel>>>((ref) async {
  final doctorService = ref.watch(doctorServiceProvider);
  return await doctorService.fetchPublicDoctors();
});

// Public Services Provider (no auth required)
final publicServicesProvider = FutureProvider.autoDispose<Result<List<ServiceModel>>>((ref) async {
  final serviceService = ref.watch(serviceServiceProvider);
  return await serviceService.fetchPublicServices();
});

// Public Time Slots Provider (no auth required)
final publicTimeSlotsProvider = FutureProvider.autoDispose
    .family<Result<List<TimeSlotModel>>, PublicTimeSlotsParams>((ref, params) async {
  final appointmentService = ref.watch(appointmentServiceProvider);
  return await appointmentService.getPublicAvailableTimeSlots(
    doctorId: params.doctorId,
    date: params.date,
  );
});

class PublicTimeSlotsParams {
  final int doctorId;
  final String date;

  PublicTimeSlotsParams({required this.doctorId, required this.date});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublicTimeSlotsParams &&
          runtimeType == other.runtimeType &&
          doctorId == other.doctorId &&
          date == other.date;

  @override
  int get hashCode => doctorId.hashCode ^ date.hashCode;
}

// Public Appointment Request Provider (no auth required)
final publicAppointmentRequestProvider =
    FutureProvider.autoDispose.family<Result<Map<String, dynamic>>, Map<String, dynamic>>(
  (ref, appointmentData) async {
    final appointmentService = ref.watch(appointmentServiceProvider);
    return await appointmentService.requestPublicAppointment(appointmentData);
  },
);


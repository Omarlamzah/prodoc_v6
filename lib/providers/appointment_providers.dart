// lib/providers/appointment_providers.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/appointment_model.dart';
import '../data/models/appointment_response_model.dart';
import '../data/models/time_slot_model.dart';
import '../data/models/appointment_request_model.dart';
import '../core/utils/result.dart';
import 'api_providers.dart';
import 'auth_providers.dart';

// Time Slots Provider
final timeSlotsProvider = FutureProvider.autoDispose
    .family<Result<List<TimeSlotModel>>, TimeSlotsParams>((ref, params) async {
  final authState = ref.watch(authProvider);

  if (authState.isAuth != true) {
    return const Failure('Not authenticated');
  }

  final appointmentService = ref.watch(appointmentServiceProvider);
  return await appointmentService.getAvailableTimeSlots(
    doctorId: params.doctorId,
    date: params.date,
  );
});

class TimeSlotsParams {
  final int doctorId;
  final String date;

  TimeSlotsParams({required this.doctorId, required this.date});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeSlotsParams &&
          runtimeType == other.runtimeType &&
          doctorId == other.doctorId &&
          date == other.date;

  @override
  int get hashCode => doctorId.hashCode ^ date.hashCode;
}

// Create Appointment Provider
final createAppointmentProvider = FutureProvider.autoDispose
    .family<Result<AppointmentResponseModel>, Map<String, dynamic>>(
  (ref, appointmentData) async {
    final authState = ref.watch(authProvider);

    if (authState.isAuth != true) {
      return const Failure('Not authenticated');
    }

    final appointmentService = ref.watch(appointmentServiceProvider);
    return await appointmentService.createAppointment(appointmentData);
  },
);

// Appointments List Provider
final appointmentsProvider = FutureProvider.autoDispose
    .family<Result<List<AppointmentModel>>, AppointmentsParams>(
        (ref, params) async {
  final authState = ref.watch(authProvider);

  if (authState.isAuth != true) {
    return const Failure('Not authenticated');
  }

  final appointmentService = ref.watch(appointmentServiceProvider);
  return await appointmentService.fetchAppointments(
    page: params.page,
    search: params.search,
    status: params.status,
    priority: params.priority,
    startDate: params.startDate,
    endDate: params.endDate,
  );
});

class AppointmentsParams {
  final int page;
  final String? search;
  final String? status;
  final String? priority;
  final String? startDate;
  final String? endDate;

  AppointmentsParams({
    this.page = 1,
    this.search,
    this.status,
    this.priority,
    this.startDate,
    this.endDate,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppointmentsParams &&
          runtimeType == other.runtimeType &&
          page == other.page &&
          search == other.search &&
          status == other.status &&
          priority == other.priority &&
          startDate == other.startDate &&
          endDate == other.endDate;

  @override
  int get hashCode =>
      page.hashCode ^
      search.hashCode ^
      status.hashCode ^
      priority.hashCode ^
      startDate.hashCode ^
      endDate.hashCode;
}

// Update Appointment Status Provider
final updateAppointmentStatusProvider = FutureProvider.autoDispose
    .family<Result<AppointmentModel>, UpdateStatusParams>((ref, params) async {
  final authState = ref.watch(authProvider);

  if (authState.isAuth != true) {
    return const Failure('Not authenticated');
  }

  final appointmentService = ref.watch(appointmentServiceProvider);
  return await appointmentService.updateAppointmentStatus(
    appointmentId: params.appointmentId,
    status: params.status,
  );
});

class UpdateStatusParams {
  final int appointmentId;
  final String status;

  UpdateStatusParams({
    required this.appointmentId,
    required this.status,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpdateStatusParams &&
          runtimeType == other.runtimeType &&
          appointmentId == other.appointmentId &&
          status == other.status;

  @override
  int get hashCode => appointmentId.hashCode ^ status.hashCode;
}

// Send WhatsApp Reminder Provider
final sendWhatsAppReminderProvider = FutureProvider.autoDispose
    .family<Result<Map<String, dynamic>>, int>((ref, appointmentId) async {
  final authState = ref.watch(authProvider);

  if (authState.isAuth != true) {
    return const Failure('Not authenticated');
  }

  final appointmentService = ref.watch(appointmentServiceProvider);
  return await appointmentService.sendWhatsAppReminder(
    appointmentId: appointmentId,
  );
});

// WhatsApp Status Provider - polls for status updates
class WhatsAppStatusParams {
  final int? clientId;
  final int? appointmentId;

  WhatsAppStatusParams({
    this.clientId,
    this.appointmentId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WhatsAppStatusParams &&
          runtimeType == other.runtimeType &&
          clientId == other.clientId &&
          appointmentId == other.appointmentId;

  @override
  int get hashCode => clientId.hashCode ^ appointmentId.hashCode;
}

final whatsAppStatusProvider = StreamProvider.autoDispose
    .family<Result<Map<String, dynamic>>, WhatsAppStatusParams>(
        (ref, params) async* {
  final authState = ref.watch(authProvider);

  if (authState.isAuth != true) {
    yield const Failure('Not authenticated');
    return;
  }

  if (params.clientId == null && params.appointmentId == null) {
    yield const Failure('client_id or appointment_id is required');
    return;
  }

  final appointmentService = ref.watch(appointmentServiceProvider);

  debugPrint(
      '🚀🚀🚀 [WhatsApp Status Provider] STARTING - clientId: ${params.clientId}, appointmentId: ${params.appointmentId}');

  // Poll every 5 seconds until status is final (read or failed)
  bool shouldContinue = true;
  int pollCount = 0;
  const maxPolls = 60; // Poll for up to 5 minutes (60 * 5 seconds)

  while (shouldContinue && pollCount < maxPolls) {
    pollCount++;
    debugPrint(
        '🔄 [WhatsApp Status Provider] Poll #$pollCount - clientId: ${params.clientId}, appointmentId: ${params.appointmentId}');

    try {
      final result = await appointmentService.getWhatsAppMessageStatus(
        clientId: params.clientId,
        appointmentId: params.appointmentId,
      );

      debugPrint('📥 [WhatsApp Status Provider] Got result: $result');
      yield result;

      // Stop polling if status is final
      result.when(
        success: (data) {
          final status = data['status'] as String?;
          debugPrint('📊 [WhatsApp Status Provider] Status: $status');

          // Only stop if status is final (read or failed)
          // Continue polling for delivered, sent, accepted, or not_found
          if (status?.toLowerCase() == 'read' ||
              status?.toLowerCase() == 'failed') {
            debugPrint(
                '🛑 [WhatsApp Status Provider] Final status reached, stopping');
            shouldContinue = false; // Exit the loop
          } else {
            debugPrint(
                '🔄 [WhatsApp Status Provider] Status is $status, continuing...');
          }
        },
        failure: (error) {
          debugPrint('❌ [WhatsApp Status Provider] Error: $error');
          // Continue polling on failure (might be temporary)
        },
      );
    } catch (e) {
      debugPrint('💥 [WhatsApp Status Provider] Exception: $e');
      yield Failure('Error: $e');
    }

    if (!shouldContinue) {
      debugPrint('🛑 [WhatsApp Status Provider] Stopping polls');
      break;
    }

    // Wait 5 seconds before next poll
    await Future.delayed(const Duration(seconds: 5));
  }

  if (pollCount >= maxPolls) {
    debugPrint('⏰ [WhatsApp Status Provider] Max polls reached');
  }
});

// Bulk Update Appointment Status Provider
final bulkUpdateAppointmentStatusProvider = FutureProvider.autoDispose
    .family<Result<Map<String, dynamic>>, BulkUpdateStatusParams>(
        (ref, params) async {
  final authState = ref.watch(authProvider);

  if (authState.isAuth != true) {
    return const Failure('Not authenticated');
  }

  final appointmentService = ref.watch(appointmentServiceProvider);
  return await appointmentService.bulkUpdateAppointmentStatus(
    appointmentIds: params.appointmentIds,
    status: params.status,
  );
});

class BulkUpdateStatusParams {
  final List<int> appointmentIds;
  final String status;

  BulkUpdateStatusParams({
    required this.appointmentIds,
    required this.status,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BulkUpdateStatusParams &&
          runtimeType == other.runtimeType &&
          appointmentIds == other.appointmentIds &&
          status == other.status;

  @override
  int get hashCode => appointmentIds.hashCode ^ status.hashCode;
}

// Update Appointment Provider
final updateAppointmentProvider = FutureProvider.autoDispose
    .family<Result<AppointmentModel>, UpdateAppointmentParams>(
        (ref, params) async {
  final authState = ref.watch(authProvider);

  if (authState.isAuth != true) {
    return const Failure('Not authenticated');
  }

  final appointmentService = ref.watch(appointmentServiceProvider);
  return await appointmentService.updateAppointment(
    appointmentId: params.appointmentId,
    appointmentData: params.appointmentData,
  );
});

class UpdateAppointmentParams {
  final int appointmentId;
  final Map<String, dynamic> appointmentData;

  UpdateAppointmentParams({
    required this.appointmentId,
    required this.appointmentData,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpdateAppointmentParams &&
          runtimeType == other.runtimeType &&
          appointmentId == other.appointmentId;

  @override
  int get hashCode => appointmentId.hashCode;
}

// Appointment Request Providers

// Fetch Appointment Requests Provider
final appointmentRequestsProvider =
    FutureProvider.autoDispose<Result<List<AppointmentRequestModel>>>(
        (ref) async {
  final authState = ref.watch(authProvider);

  if (authState.isAuth != true) {
    return const Failure('Not authenticated');
  }

  final appointmentService = ref.watch(appointmentServiceProvider);
  return await appointmentService.fetchAppointmentRequests();
});

// Confirm Appointment Request Provider
final confirmAppointmentRequestProvider = FutureProvider.autoDispose
    .family<Result<AppointmentModel>, int>((ref, requestId) async {
  final authState = ref.watch(authProvider);

  if (authState.isAuth != true) {
    return const Failure('Not authenticated');
  }

  final appointmentService = ref.watch(appointmentServiceProvider);
  return await appointmentService.confirmAppointmentRequest(requestId);
});

// Reject Appointment Request Provider
final rejectAppointmentRequestProvider = FutureProvider.autoDispose
    .family<Result<Map<String, dynamic>>, RejectRequestParams>(
        (ref, params) async {
  final authState = ref.watch(authProvider);

  if (authState.isAuth != true) {
    return const Failure('Not authenticated');
  }

  final appointmentService = ref.watch(appointmentServiceProvider);
  return await appointmentService.rejectAppointmentRequest(
    requestId: params.requestId,
    reason: params.reason,
  );
});

class RejectRequestParams {
  final int requestId;
  final String reason;

  RejectRequestParams({
    required this.requestId,
    required this.reason,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RejectRequestParams &&
          runtimeType == other.runtimeType &&
          requestId == other.requestId &&
          reason == other.reason;

  @override
  int get hashCode => requestId.hashCode ^ reason.hashCode;
}

// Update Appointment Request Provider
final updateAppointmentRequestProvider = FutureProvider.autoDispose
    .family<Result<AppointmentModel>, UpdateRequestParams>((ref, params) async {
  final authState = ref.watch(authProvider);

  if (authState.isAuth != true) {
    return const Failure('Not authenticated');
  }

  final appointmentService = ref.watch(appointmentServiceProvider);
  return await appointmentService.updateAppointmentRequest(
    requestId: params.requestId,
    date: params.date,
    time: params.time,
    confirm: params.confirm,
  );
});

class UpdateRequestParams {
  final int requestId;
  final String date;
  final String time;
  final bool confirm;

  UpdateRequestParams({
    required this.requestId,
    required this.date,
    required this.time,
    this.confirm = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpdateRequestParams &&
          runtimeType == other.runtimeType &&
          requestId == other.requestId &&
          date == other.date &&
          time == other.time &&
          confirm == other.confirm;

  @override
  int get hashCode =>
      requestId.hashCode ^ date.hashCode ^ time.hashCode ^ confirm.hashCode;
}

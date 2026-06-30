// lib/services/appointment_service.dart
import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../core/config/api_constants.dart';
import '../core/exceptions/api_exception.dart';
import '../core/utils/result.dart';
import '../data/models/appointment_model.dart';
import '../data/models/appointment_response_model.dart';
import '../data/models/time_slot_model.dart';
import '../data/models/waiting_room_model.dart';
import '../data/models/appointment_request_model.dart';

class AppointmentService {
  final ApiClient apiClient;

  AppointmentService({required this.apiClient});

  Future<Result<AppointmentResponseModel>> createAppointment(
    Map<String, dynamic> appointmentData,
  ) async {
    try {
      final responseData = await apiClient.post(
        ApiConstants.appointments,
        body: appointmentData,
        requireAuth: true,
      );

      // Check if response has appointment data
      if (responseData is Map<String, dynamic> &&
          responseData.containsKey('appointment')) {
        final response = AppointmentResponseModel.fromJson(responseData);
        return Success(response);
      } else {
        // Handle unexpected response structure
        return const Failure('Invalid response format from server');
      }
    } on ApiException catch (e) {
      // Extract detailed error message
      String errorMessage = e.message;

      // Try to get more detailed error from exception data
      if (e.data != null) {
        try {
          final errorData = e.data as Map<String, dynamic>?;
          if (errorData != null) {
            // Check for validation errors
            if (errorData.containsKey('errors')) {
              final errors = errorData['errors'] as Map<String, dynamic>?;
              if (errors != null && errors.isNotEmpty) {
                final firstError = errors.values.first;
                if (firstError is List && firstError.isNotEmpty) {
                  errorMessage = firstError.first.toString();
                } else if (firstError is String) {
                  errorMessage = firstError;
                }
              }
            } else if (errorData.containsKey('message')) {
              errorMessage = errorData['message'] as String? ?? e.message;
            } else if (errorData.containsKey('error')) {
              errorMessage = errorData['error'] as String? ?? e.message;
            }
          }
        } catch (_) {
          // Keep original error message if parsing fails
        }
      }

      return Failure(errorMessage);
    } catch (e) {
      return Failure('Failed to create appointment: ${e.toString()}');
    }
  }

  Future<Result<List<TimeSlotModel>>> getAvailableTimeSlots({
    required int doctorId,
    required String date,
  }) async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.getAvailableTimeSlots,
        queryParameters: {
          'doctor_id': doctorId.toString(),
          'date': date,
        },
        requireAuth: true,
      );

      // Handle response - should be a Map with 'time_slots' key
      List<dynamic> timeSlotsData = [];
      if (responseData is Map<String, dynamic>) {
        timeSlotsData = responseData['time_slots'] as List<dynamic>? ?? [];
      }

      final timeSlots = timeSlotsData
          .map((json) => TimeSlotModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(timeSlots);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch time slots: $e');
    }
  }

  Future<Result<List<AppointmentModel>>> fetchAppointments({
    int page = 1,
    String? search,
    String? status,
    String? priority,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page.toString(),
      };
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      if (priority != null && priority.isNotEmpty) {
        queryParams['priority'] = priority;
      }
      if (startDate != null && startDate.isNotEmpty) {
        queryParams['start_date'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        queryParams['end_date'] = endDate;
      }

      final responseData = await apiClient.get(
        ApiConstants.appointments,
        queryParameters: queryParams,
        requireAuth: true,
      );

      // Handle response - can be Map with 'data' key or direct List
      List<dynamic> appointmentsData = [];
      if (responseData is List) {
        appointmentsData = responseData;
      } else if (responseData is Map<String, dynamic>) {
        appointmentsData = responseData['data'] as List<dynamic>? ?? [];
      }

      final appointments = appointmentsData
          .map(
              (json) => AppointmentModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(appointments);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch appointments: $e');
    }
  }

  Future<Result<List<AppointmentModel>>> fetchAppointmentsByDate({
    required int year,
    required int month,
  }) async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.appointmentsByDate,
        queryParameters: {
          'year': year.toString(),
          'month': month.toString(),
        },
        requireAuth: true,
      );

      // API returns a direct array: [{...}, {...}]
      List<dynamic> appointmentsData = [];
      if (responseData is List) {
        appointmentsData = responseData;
      } else if (responseData is Map<String, dynamic>) {
        appointmentsData = responseData['data'] as List<dynamic>? ?? [];
      }

      final appointments = appointmentsData
          .map(
              (json) => AppointmentModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(appointments);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch appointments by date: ${e.toString()}');
    }
  }

  // Public method to request appointment (no auth required)
  Future<Result<Map<String, dynamic>>> requestPublicAppointment(
    Map<String, dynamic> appointmentData,
  ) async {
    try {
      final responseData = await apiClient.post(
        ApiConstants.publicAppointmentRequest,
        body: appointmentData,
        requireAuth: false,
      );

      if (responseData is Map<String, dynamic>) {
        return Success(responseData);
      } else {
        return const Failure('Invalid response format from server');
      }
    } on ApiException catch (e) {
      String errorMessage = e.message;

      if (e.data != null) {
        try {
          final errorData = e.data as Map<String, dynamic>?;
          if (errorData != null) {
            if (errorData.containsKey('errors')) {
              final errors = errorData['errors'] as Map<String, dynamic>?;
              if (errors != null && errors.isNotEmpty) {
                final firstError = errors.values.first;
                if (firstError is List && firstError.isNotEmpty) {
                  errorMessage = firstError.first.toString();
                } else if (firstError is String) {
                  errorMessage = firstError;
                }
              }
            } else if (errorData.containsKey('message')) {
              errorMessage = errorData['message'] as String? ?? e.message;
            }
          }
        } catch (_) {}
      }

      return Failure(errorMessage);
    } catch (e) {
      return Failure('Failed to request appointment: ${e.toString()}');
    }
  }

  // Public method to get available time slots (no auth required)
  Future<Result<List<TimeSlotModel>>> getPublicAvailableTimeSlots({
    required int doctorId,
    required String date,
  }) async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.publicGetAvailableTimeSlots,
        queryParameters: {
          'doctor_id': doctorId.toString(),
          'date': date,
        },
        requireAuth: false,
      );

      List<dynamic> timeSlotsData = [];
      if (responseData is Map<String, dynamic>) {
        timeSlotsData = responseData['time_slots'] as List<dynamic>? ?? [];
      }

      final timeSlots = timeSlotsData
          .map((json) => TimeSlotModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(timeSlots);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch time slots: $e');
    }
  }

  // Update appointment
  Future<Result<AppointmentModel>> updateAppointment({
    required int appointmentId,
    required Map<String, dynamic> appointmentData,
  }) async {
    try {
      final responseData = await apiClient.put(
        ApiConstants.appointment(appointmentId),
        body: appointmentData,
        requireAuth: true,
      );

      if (responseData is Map<String, dynamic>) {
        // Handle nested appointment structure from API response
        Map<String, dynamic> appointmentJson;
        if (responseData.containsKey('appointment')) {
          appointmentJson = responseData['appointment'] as Map<String, dynamic>;
        } else {
          appointmentJson = responseData;
        }
        final appointment = AppointmentModel.fromJson(appointmentJson);
        return Success(appointment);
      } else {
        return const Failure('Invalid response format from server');
      }
    } on ApiException catch (e) {
      String errorMessage = e.message;

      if (e.data != null) {
        try {
          final errorData = e.data as Map<String, dynamic>?;
          if (errorData != null) {
            if (errorData.containsKey('errors')) {
              final errors = errorData['errors'] as Map<String, dynamic>?;
              if (errors != null && errors.isNotEmpty) {
                final firstError = errors.values.first;
                if (firstError is List && firstError.isNotEmpty) {
                  errorMessage = firstError.first.toString();
                } else if (firstError is String) {
                  errorMessage = firstError;
                }
              }
            } else if (errorData.containsKey('error')) {
              errorMessage = (errorData['error'] as String?) ?? e.message;
            } else if (errorData.containsKey('message')) {
              errorMessage = (errorData['message'] as String?) ?? e.message;
            }
          }
        } catch (_) {}
      }

      return Failure(errorMessage);
    } catch (e) {
      return Failure('Failed to update appointment: ${e.toString()}');
    }
  }

  // Update appointment status
  Future<Result<AppointmentModel>> updateAppointmentStatus({
    required int appointmentId,
    required String status,
  }) async {
    try {
      final responseData = await apiClient.patch(
        ApiConstants.updateAppointmentStatus(appointmentId),
        body: {'status': status},
        requireAuth: true,
      );

      if (responseData is Map<String, dynamic>) {
        final appointment = AppointmentModel.fromJson(
            responseData['appointment'] ?? responseData);
        return Success(appointment);
      } else {
        return const Failure('Invalid response format from server');
      }
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to update appointment status: ${e.toString()}');
    }
  }

  // Bulk update appointment status
  Future<Result<Map<String, dynamic>>> bulkUpdateAppointmentStatus({
    required List<int> appointmentIds,
    required String status,
  }) async {
    try {
      final results = <int, AppointmentModel>{};
      final errors = <int, String>{};

      // Update each appointment status sequentially
      for (final appointmentId in appointmentIds) {
        final result = await updateAppointmentStatus(
          appointmentId: appointmentId,
          status: status,
        );

        result.when(
          success: (appointment) {
            results[appointmentId] = appointment;
          },
          failure: (error) {
            errors[appointmentId] = error;
          },
        );
      }

      if (errors.isEmpty) {
        return Success({
          'success': true,
          'updated_count': results.length,
          'appointments': results.values.toList(),
        });
      } else if (results.isEmpty) {
        return Failure('Échec de la mise à jour de tous les rendez-vous');
      } else {
        return Success({
          'success': true,
          'updated_count': results.length,
          'failed_count': errors.length,
          'appointments': results.values.toList(),
          'errors': errors,
        });
      }
    } catch (e) {
      return Failure(
          'Failed to bulk update appointment status: ${e.toString()}');
    }
  }

  // Send WhatsApp reminder
  Future<Result<Map<String, dynamic>>> sendWhatsAppReminder({
    required int appointmentId,
  }) async {
    try {
      final responseData = await apiClient.post(
        ApiConstants.sendWhatsAppReminder,
        body: {'appointment_id': appointmentId},
        requireAuth: true,
      );

      if (responseData is Map<String, dynamic>) {
        return Success(responseData);
      } else {
        return const Failure('Invalid response format from server');
      }
    } on ApiException catch (e) {
      String errorMessage = e.message;

      // Check for nested WhatsApp API error
      if (e.data != null) {
        try {
          final errorData = e.data as Map<String, dynamic>?;
          if (errorData != null && errorData.containsKey('whatsapp_response')) {
            final whatsappResponse =
                errorData['whatsapp_response'] as Map<String, dynamic>?;
            if (whatsappResponse != null &&
                whatsappResponse.containsKey('original')) {
              final original =
                  whatsappResponse['original'] as Map<String, dynamic>?;
              if (original != null && original.containsKey('error')) {
                errorMessage = original['error'] as String? ?? e.message;
              }
            }
          } else if (errorData != null && errorData.containsKey('error')) {
            errorMessage = (errorData['error'] as String?) ?? e.message;
          }
        } catch (_) {}
      }

      return Failure(errorMessage);
    } catch (e) {
      return Failure('Failed to send WhatsApp reminder: ${e.toString()}');
    }
  }

  // Get WhatsApp message status by client or appointment
  Future<Result<Map<String, dynamic>>> getWhatsAppMessageStatus({
    int? clientId,
    int? appointmentId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (clientId != null) {
        queryParams['client_id'] = clientId;
      }
      if (appointmentId != null) {
        queryParams['appointment_id'] = appointmentId;
      }

      if (queryParams.isEmpty) {
        return const Failure('client_id or appointment_id is required');
      }

      final responseData = await apiClient.get(
        ApiConstants.whatsAppMessageStatus,
        queryParameters: queryParams,
        requireAuth: true,
      );

      // Debug logging
      debugPrint('📡 [WhatsApp Status] API Response: $responseData');
      debugPrint('📡 [WhatsApp Status] Query Params: $queryParams');

      if (responseData is Map<String, dynamic>) {
        // Handle case where message not found
        if (responseData['status'] == 'not_found') {
          debugPrint('[WhatsApp Status] Message not found');
          return Success({'status': 'not_found'});
        }
        debugPrint(
            '[WhatsApp Status] Success - Status: ${responseData['status']}');
        return Success(responseData);
      } else {
        print(
            '[WhatsApp Status] Invalid response format: ${responseData.runtimeType}');
        return const Failure('Invalid response format from server');
      }
    } on ApiException catch (e) {
      // Don't treat 404 as error - it means no message found yet
      if (e.statusCode == 404) {
        return Success({'status': 'not_found'});
      }
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch WhatsApp status: ${e.toString()}');
    }
  }

  // Fetch waiting room data
  Future<Result<WaitingRoomData>> fetchWaitingRoomData() async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.waitingRoom,
        requireAuth: true,
      );

      if (responseData is Map<String, dynamic>) {
        final waitingRoomData = WaitingRoomData.fromJson(responseData);
        return Success(waitingRoomData);
      } else {
        return const Failure('Invalid response format from server');
      }
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch waiting room data: ${e.toString()}');
    }
  }

  // Fetch appointment requests (for admin/doctor/receptionist)
  Future<Result<List<AppointmentRequestModel>>>
      fetchAppointmentRequests() async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.appointmentRequests,
        requireAuth: true,
      );

      List<dynamic> requestsData = [];
      if (responseData is List) {
        requestsData = responseData;
      } else if (responseData is Map<String, dynamic>) {
        requestsData = responseData['data'] as List<dynamic>? ?? [];
      }

      final requests = requestsData
          .map((json) =>
              AppointmentRequestModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(requests);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch appointment requests: ${e.toString()}');
    }
  }

  // Confirm appointment request
  Future<Result<AppointmentModel>> confirmAppointmentRequest(
      int requestId) async {
    try {
      final responseData = await apiClient.post(
        ApiConstants.confirmAppointmentRequest(requestId),
        requireAuth: true,
      );

      if (responseData is Map<String, dynamic>) {
        // Handle nested appointment structure from API response
        Map<String, dynamic> appointmentJson;
        if (responseData.containsKey('appointment')) {
          appointmentJson = responseData['appointment'] as Map<String, dynamic>;
        } else {
          appointmentJson = responseData;
        }
        final appointment = AppointmentModel.fromJson(appointmentJson);
        return Success(appointment);
      } else {
        return const Failure('Invalid response format from server');
      }
    } on ApiException catch (e) {
      String errorMessage = e.message;

      if (e.data != null) {
        try {
          final errorData = e.data as Map<String, dynamic>?;
          if (errorData != null) {
            if (errorData.containsKey('error')) {
              errorMessage = (errorData['error'] as String?) ?? e.message;
            } else if (errorData.containsKey('message')) {
              errorMessage = (errorData['message'] as String?) ?? e.message;
            }
          }
        } catch (_) {}
      }

      return Failure(errorMessage);
    } catch (e) {
      return Failure('Failed to confirm appointment request: ${e.toString()}');
    }
  }

  // Reject appointment request
  Future<Result<Map<String, dynamic>>> rejectAppointmentRequest({
    required int requestId,
    required String reason,
  }) async {
    try {
      final responseData = await apiClient.post(
        ApiConstants.rejectAppointmentRequest(requestId),
        body: {'reason': reason},
        requireAuth: true,
      );

      if (responseData is Map<String, dynamic>) {
        return Success(responseData);
      } else {
        return const Failure('Invalid response format from server');
      }
    } on ApiException catch (e) {
      String errorMessage = e.message;

      if (e.data != null) {
        try {
          final errorData = e.data as Map<String, dynamic>?;
          if (errorData != null) {
            if (errorData.containsKey('error')) {
              errorMessage = (errorData['error'] as String?) ?? e.message;
            } else if (errorData.containsKey('message')) {
              errorMessage = (errorData['message'] as String?) ?? e.message;
            }
          }
        } catch (_) {}
      }

      return Failure(errorMessage);
    } catch (e) {
      return Failure('Failed to reject appointment request: ${e.toString()}');
    }
  }

  // Update appointment request (date/time) and optionally confirm
  Future<Result<AppointmentModel>> updateAppointmentRequest({
    required int requestId,
    required String date,
    required String time,
    bool confirm = false,
  }) async {
    try {
      final body = {
        'date': date,
        'time': time,
        if (confirm) 'confirm': true,
      };

      final responseData = await apiClient.patch(
        ApiConstants.updateAppointmentRequest(requestId),
        body: body,
        requireAuth: true,
      );

      if (responseData is Map<String, dynamic>) {
        // Handle nested appointment structure from API response
        Map<String, dynamic> appointmentJson;
        if (responseData.containsKey('appointment')) {
          appointmentJson = responseData['appointment'] as Map<String, dynamic>;
        } else {
          appointmentJson = responseData;
        }
        final appointment = AppointmentModel.fromJson(appointmentJson);
        return Success(appointment);
      } else {
        return const Failure('Invalid response format from server');
      }
    } on ApiException catch (e) {
      String errorMessage = e.message;

      if (e.data != null) {
        try {
          final errorData = e.data as Map<String, dynamic>?;
          if (errorData != null) {
            if (errorData.containsKey('error')) {
              errorMessage = (errorData['error'] as String?) ?? e.message;
            } else if (errorData.containsKey('message')) {
              errorMessage = (errorData['message'] as String?) ?? e.message;
            }
            // Store doctor availability if provided
            if (errorData.containsKey('doctor_availability')) {
              // This will be handled in the UI layer
            }
          }
        } catch (_) {}
      }

      return Failure(errorMessage);
    } catch (e) {
      return Failure('Failed to update appointment request: ${e.toString()}');
    }
  }
}

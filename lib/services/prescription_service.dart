// lib/services/prescription_service.dart
import '../core/network/api_client.dart';
import '../core/config/api_constants.dart';
import '../core/exceptions/api_exception.dart';
import '../core/utils/result.dart';
import '../data/models/prescription_model.dart';
import '../data/models/prescription_list_response.dart';
import '../data/models/patient_model.dart';
import '../data/models/medication_model.dart';
import '../data/models/prescription_template_model.dart';

class PrescriptionService {
  final ApiClient apiClient;

  PrescriptionService({required this.apiClient});

  Future<Result<List<PatientModel>>> searchPatients(String search) async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.searchPrescriptionPatients,
        queryParameters: {'search': search},
        requireAuth: true,
      );

      final data = responseData['data'] as List<dynamic>? ?? [];
      final patients = data
          .map((json) => PatientModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(patients);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to search patients: $e');
    }
  }

  Future<Result<List<MedicationModel>>> searchMedications(String search) async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.searchMedications,
        queryParameters: {'search': search},
        requireAuth: true,
      );

      final data = responseData['data'] as List<dynamic>? ?? [];
      final medications = data
          .map((json) => MedicationModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(medications);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to search medications: $e');
    }
  }

  Future<Result<List<PrescriptionTemplateModel>>> searchTemplates(
      String search) async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.prescriptionTemplates,
        queryParameters: {'search': search},
        requireAuth: true,
      );

      final data = responseData['data'] as List<dynamic>? ?? [];
      final templates = data
          .map((json) =>
              PrescriptionTemplateModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(templates);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to search templates: $e');
    }
  }

  Future<Result<PrescriptionModel>> createPrescription(
      Map<String, dynamic> prescriptionData) async {
    try {
      final responseData = await apiClient.post(
        ApiConstants.prescriptions,
        body: prescriptionData,
        requireAuth: true,
      );

      final prescription =
          PrescriptionModel.fromJson(responseData['data'] ?? responseData);
      return Success(prescription);
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
        } catch (_) {
          // Keep original error message
        }
      }

      return Failure(errorMessage);
    } catch (e) {
      return Failure('Failed to create prescription: ${e.toString()}');
    }
  }

  Future<Result<PrescriptionTemplateModel>> saveTemplate(
      Map<String, dynamic> templateData) async {
    try {
      final responseData = await apiClient.post(
        ApiConstants.prescriptionTemplates,
        body: templateData,
        requireAuth: true,
      );

      final template = PrescriptionTemplateModel.fromJson(
          responseData['data'] ?? responseData);
      return Success(template);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to save template: ${e.toString()}');
    }
  }

  Future<Result<void>> saveTemplateItems(
      int templateId, List<Map<String, dynamic>> items) async {
    try {
      for (final item in items) {
        await apiClient.post(
          ApiConstants.prescriptionItems,
          body: {
            'template_id': templateId,
            ...item,
          },
          requireAuth: true,
        );
      }
      return const Success(null);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to save template items: ${e.toString()}');
    }
  }

  Future<Result<PrescriptionListResponse>> fetchPrescriptions({
    int page = 1,
    String? search,
    String timeRange = 'all',
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'page': page,
        'timeRange': timeRange,
      };

      if (search != null && search.isNotEmpty) {
        queryParameters['search'] = search;
      }

      final responseData = await apiClient.get(
        ApiConstants.prescriptions,
        queryParameters: queryParameters,
        requireAuth: true,
      );

      final response = PrescriptionListResponse.fromJson(responseData);
      return Success(response);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch prescriptions: $e');
    }
  }

  Future<Result<void>> deletePrescription(int id) async {
    try {
      await apiClient.delete(
        ApiConstants.prescription(id),
        requireAuth: true,
      );
      return const Success(null);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to delete prescription: ${e.toString()}');
    }
  }
}

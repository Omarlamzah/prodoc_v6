// lib/services/medication_service.dart
import '../core/network/api_client.dart';
import '../core/config/api_constants.dart';
import '../core/exceptions/api_exception.dart';
import '../core/utils/result.dart';
import '../data/models/medication_model.dart';
import '../data/models/medication_list_response.dart';

class MedicationService {
  final ApiClient apiClient;

  MedicationService({required this.apiClient});

  Future<Result<MedicationListResponse>> fetchMedications({
    int page = 1,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page.toString(),
      };
      if (search != null && search.isNotEmpty) {
        queryParams['global'] = search;
      }

      final responseData = await apiClient.get(
        ApiConstants.medications,
        queryParameters: queryParams,
        requireAuth: true,
      );

      final parsed = MedicationListResponse.fromJson(responseData);
      return Success(parsed);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch medications: $e');
    }
  }

  Future<Result<MedicationModel>> createMedication(
    Map<String, dynamic> medicationData,
  ) async {
    try {
      final responseData = await apiClient.post(
        ApiConstants.medications,
        body: medicationData,
        requireAuth: true,
      );

      MedicationModel medication;
      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('data')) {
          medication = MedicationModel.fromJson(
            responseData['data'] as Map<String, dynamic>,
          );
        } else {
          medication = MedicationModel.fromJson(responseData);
        }
      } else {
        return const Failure('Invalid response format');
      }

      return Success(medication);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to create medication: ${e.toString()}');
    }
  }

  Future<Result<MedicationModel>> updateMedication({
    required String code,
    required Map<String, dynamic> medicationData,
  }) async {
    try {
      final responseData = await apiClient.put(
        ApiConstants.medication(code),
        body: medicationData,
        requireAuth: true,
      );

      MedicationModel medication;
      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('data')) {
          medication = MedicationModel.fromJson(
            responseData['data'] as Map<String, dynamic>,
          );
        } else {
          medication = MedicationModel.fromJson(responseData);
        }
      } else {
        return const Failure('Invalid response format');
      }

      return Success(medication);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to update medication: ${e.toString()}');
    }
  }

  Future<Result<String>> deleteMedication(String code) async {
    try {
      await apiClient.delete(
        ApiConstants.medication(code),
        requireAuth: true,
      );
      return const Success('Medication deleted successfully');
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to delete medication: $e');
    }
  }
}

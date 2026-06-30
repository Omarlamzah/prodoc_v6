// lib/services/specialty_service.dart
import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../core/config/api_constants.dart';
import '../core/exceptions/api_exception.dart';
import '../core/utils/result.dart';
import '../data/models/specialty_model.dart';

class SpecialtyService {
  final ApiClient apiClient;

  SpecialtyService({required this.apiClient});

  // ==================== Specialty CRUD ====================

  /// Fetch all specialties
  Future<Result<List<SpecialtyModel>>> fetchSpecialties() async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.specialties,
        requireAuth: true,
      );

      List<dynamic> specialtiesList = [];
      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('data')) {
          final data = responseData['data'];
          specialtiesList = data is List ? data : [];
        } else if (responseData.containsKey('specialties')) {
          specialtiesList = responseData['specialties'] as List<dynamic>? ?? [];
        }
      } else if (responseData is List) {
        specialtiesList = responseData;
      }

      final specialties = specialtiesList
          .map((json) => SpecialtyModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(specialties);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch specialties: ${e.toString()}');
    }
  }

  /// Fetch a single specialty by ID
  Future<Result<SpecialtyModel>> fetchSpecialty(int id) async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.specialty(id),
        requireAuth: true,
      );

      Map<String, dynamic> specialtyData;
      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('data')) {
          specialtyData = responseData['data'] as Map<String, dynamic>;
        } else {
          specialtyData = responseData;
        }
      } else {
        return const Failure('Invalid response format');
      }

      final specialty = SpecialtyModel.fromJson(specialtyData);
      return Success(specialty);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch specialty: ${e.toString()}');
    }
  }

  /// Create a new specialty
  Future<Result<SpecialtyModel>> createSpecialty({
    required String name,
    String? description,
  }) async {
    try {
      final responseData = await apiClient.post(
        ApiConstants.specialties,
        body: {
          'name': name,
          if (description != null && description.isNotEmpty)
            'description': description,
        },
        requireAuth: true,
      );

      Map<String, dynamic> specialtyData;
      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('data')) {
          specialtyData = responseData['data'] as Map<String, dynamic>;
        } else {
          specialtyData = responseData;
        }
      } else {
        return const Failure('Invalid response format');
      }

      final specialty = SpecialtyModel.fromJson(specialtyData);
      return Success(specialty);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to create specialty: ${e.toString()}');
    }
  }

  /// Update a specialty
  Future<Result<SpecialtyModel>> updateSpecialty({
    required int id,
    required String name,
    String? description,
  }) async {
    try {
      final responseData = await apiClient.put(
        ApiConstants.specialty(id),
        body: {
          'name': name,
          if (description != null) 'description': description,
        },
        requireAuth: true,
      );

      Map<String, dynamic> specialtyData;
      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('data')) {
          specialtyData = responseData['data'] as Map<String, dynamic>;
        } else {
          specialtyData = responseData;
        }
      } else {
        return const Failure('Invalid response format');
      }

      final specialty = SpecialtyModel.fromJson(specialtyData);
      return Success(specialty);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to update specialty: ${e.toString()}');
    }
  }

  /// Delete a specialty
  Future<Result<String>> deleteSpecialty(int id) async {
    try {
      debugPrint('[SpecialtyService] deleteSpecialty called with ID: $id');
      final endpoint = ApiConstants.specialty(id);
      debugPrint('[SpecialtyService] Endpoint: $endpoint');

      final responseData = await apiClient.delete(
        endpoint,
        requireAuth: true,
      );

      debugPrint('[SpecialtyService] Response received: $responseData');
      debugPrint(
          '[SpecialtyService] Response type: ${responseData.runtimeType}');

      String message = 'Specialty deleted successfully';
      if (responseData is Map<String, dynamic>) {
        debugPrint(
            '[SpecialtyService] Response is Map, keys: ${responseData.keys}');
        message = responseData['message'] as String? ?? message;
        debugPrint('[SpecialtyService] Message from response: $message');

        // Check for error in response
        if (responseData.containsKey('success') &&
            responseData['success'] == false) {
          final errorMsg = responseData['message'] as String? ??
              'Failed to delete specialty';
          debugPrint('[SpecialtyService] API returned error: $errorMsg');
          return Failure(errorMsg);
        }
      }

      debugPrint('[SpecialtyService] Returning success with message: $message');
      return Success(message);
    } on ApiException catch (e) {
      debugPrint('[SpecialtyService] ApiException caught: ${e.message}');
      debugPrint('[SpecialtyService] Status code: ${e.statusCode}');
      debugPrint('[SpecialtyService] Error data: ${e.data}');
      return Failure(e.message);
    } catch (e, stackTrace) {
      debugPrint('[SpecialtyService] General exception caught: $e');
      debugPrint('[SpecialtyService] Stack trace: $stackTrace');
      return Failure('Failed to delete specialty: ${e.toString()}');
    }
  }

  // ==================== Specialty Fields CRUD ====================

  /// Fetch all fields for a specialty
  Future<Result<List<SpecialtyFieldModel>>> fetchSpecialtyFields(
      int specialtyId) async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.specialtyFields(specialtyId),
        requireAuth: true,
      );

      List<dynamic> fieldsList = [];
      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('data')) {
          final data = responseData['data'];
          fieldsList = data is List ? data : [];
        } else if (responseData.containsKey('fields')) {
          fieldsList = responseData['fields'] as List<dynamic>? ?? [];
        }
      } else if (responseData is List) {
        fieldsList = responseData;
      }

      final fields = fieldsList
          .map((json) =>
              SpecialtyFieldModel.fromJson(json as Map<String, dynamic>))
          .toList();

      // Sort by field_order
      fields.sort((a, b) => (a.fieldOrder ?? 0).compareTo(b.fieldOrder ?? 0));

      return Success(fields);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch specialty fields: ${e.toString()}');
    }
  }

  /// Create a new specialty field
  Future<Result<SpecialtyFieldModel>> createSpecialtyField({
    required int specialtyId,
    required String fieldName,
    required String fieldLabel,
    required String fieldType,
    List<String>? options,
    bool required = false,
    int fieldOrder = 0,
  }) async {
    try {
      final body = <String, dynamic>{
        'field_name': fieldName,
        'field_label': fieldLabel,
        'field_type': fieldType,
        'required': required,
        'field_order': fieldOrder,
      };

      if (fieldType == 'select' && options != null && options.isNotEmpty) {
        body['options'] = options.join(',');
      }

      final responseData = await apiClient.post(
        ApiConstants.specialtyFields(specialtyId),
        body: body,
        requireAuth: true,
      );

      Map<String, dynamic> fieldData;
      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('data')) {
          fieldData = responseData['data'] as Map<String, dynamic>;
        } else {
          fieldData = responseData;
        }
      } else {
        return const Failure('Invalid response format');
      }

      final field = SpecialtyFieldModel.fromJson(fieldData);
      return Success(field);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to create specialty field: ${e.toString()}');
    }
  }

  /// Update a specialty field
  Future<Result<SpecialtyFieldModel>> updateSpecialtyField({
    required int specialtyId,
    required int fieldId,
    required String fieldName,
    required String fieldLabel,
    required String fieldType,
    List<String>? options,
    bool? required,
    int? fieldOrder,
  }) async {
    try {
      final body = <String, dynamic>{
        'field_name': fieldName,
        'field_label': fieldLabel,
        'field_type': fieldType,
      };

      if (required != null) {
        body['required'] = required;
      }
      if (fieldOrder != null) {
        body['field_order'] = fieldOrder;
      }
      if (fieldType == 'select' && options != null && options.isNotEmpty) {
        body['options'] = options.join(',');
      }

      final responseData = await apiClient.put(
        ApiConstants.specialtyField(specialtyId, fieldId),
        body: body,
        requireAuth: true,
      );

      Map<String, dynamic> fieldData;
      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('data')) {
          fieldData = responseData['data'] as Map<String, dynamic>;
        } else {
          fieldData = responseData;
        }
      } else {
        return const Failure('Invalid response format');
      }

      final field = SpecialtyFieldModel.fromJson(fieldData);
      return Success(field);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to update specialty field: ${e.toString()}');
    }
  }

  /// Delete a specialty field
  Future<Result<String>> deleteSpecialtyField({
    required int specialtyId,
    required int fieldId,
  }) async {
    try {
      final responseData = await apiClient.delete(
        ApiConstants.specialtyField(specialtyId, fieldId),
        requireAuth: true,
      );

      String message = 'Specialty field deleted successfully';
      if (responseData is Map<String, dynamic>) {
        message = responseData['message'] as String? ?? message;
      }

      return Success(message);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to delete specialty field: ${e.toString()}');
    }
  }

  /// Cleanup orphaned field data from medical records
  Future<Result<String>> cleanupFieldData({
    required int specialtyId,
    required String fieldName,
  }) async {
    try {
      // URL encode the field name
      final encodedFieldName = Uri.encodeComponent(fieldName);
      final responseData = await apiClient.post(
        ApiConstants.cleanupSpecialtyField(specialtyId, encodedFieldName),
        body: <String, dynamic>{},
        requireAuth: true,
      );

      String message = 'Field data cleaned up successfully';
      if (responseData is Map<String, dynamic>) {
        message = responseData['message'] as String? ?? message;
      }

      return Success(message);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to cleanup field data: ${e.toString()}');
    }
  }
}

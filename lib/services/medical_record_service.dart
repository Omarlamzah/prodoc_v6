// lib/services/medical_record_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import '../core/network/api_client.dart';
import '../core/config/api_constants.dart';
import '../core/exceptions/api_exception.dart';
import '../core/utils/result.dart';
import '../data/models/medical_record_model.dart';

class MedicalRecordService {
  final ApiClient apiClient;

  MedicalRecordService({required this.apiClient});

  Future<Result<List<MedicalRecordModel>>> fetchMedicalRecords({
    int page = 1,
    Map<String, dynamic>? filters,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page.toString(),
      };

      if (filters != null) {
        queryParams.addAll(filters
            .map((key, value) => MapEntry(key, value?.toString() ?? '')));
      }

      final responseData = await apiClient.get(
        ApiConstants.medicalRecords,
        queryParameters: queryParams,
        requireAuth: true,
      );

      final data = responseData['data'] as List<dynamic>?;
      final records = (data ?? [])
          .map((json) =>
              MedicalRecordModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(records);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch medical records: $e');
    }
  }

  Future<Result<MedicalRecordModel>> fetchMedicalRecord(int recordId) async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.medicalRecord(recordId),
        requireAuth: true,
      );

      MedicalRecordModel record;
      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('data')) {
          // Handle potential attachment errors by removing attachments if they cause issues
          final data = responseData['data'] as Map<String, dynamic>;
          // If attachments cause an error, we'll handle it in the model parsing
          record = MedicalRecordModel.fromJson(data);
        } else {
          record = MedicalRecordModel.fromJson(responseData);
        }
      } else {
        return const Failure('Invalid response format');
      }

      return Success(record);
    } on ApiException catch (e) {
      // Check if error is related to visibility column
      if (e.message.contains('visibility') ||
          e.message.contains('Column not found') ||
          e.message.contains('SQLSTATE[42S22]')) {
        // Try to fetch without attachments or with a workaround
        return Failure(
            'Database schema issue: The visibility column is missing in the attachments table. '
            'Please contact the administrator to run the database migration to add the visibility column.');
      }
      return Failure(e.message);
    } catch (e) {
      // Check if error is related to visibility column
      final errorStr = e.toString();
      if (errorStr.contains('visibility') ||
          errorStr.contains('Column not found') ||
          errorStr.contains('SQLSTATE[42S22]')) {
        return Failure(
            'Database schema issue: The visibility column is missing in the attachments table. '
            'Please contact the administrator to run the database migration to add the visibility column.');
      }
      return Failure('Failed to fetch medical record: $e');
    }
  }

  Future<Result<List<MedicalRecordModel>>> fetchPatientHistory(
      int patientId) async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.patientMedicalRecords(patientId),
        requireAuth: true,
      );

      final data = responseData['data'] as List<dynamic>?;
      final records = (data ?? [])
          .map((json) =>
              MedicalRecordModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(records);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch patient history: $e');
    }
  }

  Future<Result<MedicalRecordModel>> createMedicalRecord(
    Map<String, dynamic> recordData,
  ) async {
    try {
      final responseData = await apiClient.post(
        ApiConstants.medicalRecords,
        body: recordData,
        requireAuth: true,
      );

      MedicalRecordModel record;
      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('data')) {
          record = MedicalRecordModel.fromJson(
              responseData['data'] as Map<String, dynamic>);
        } else {
          record = MedicalRecordModel.fromJson(responseData);
        }
      } else {
        return const Failure('Invalid response format');
      }

      return Success(record);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to create medical record: $e');
    }
  }

  Future<Result<MedicalRecordModel>> updateMedicalRecord({
    required int recordId,
    required Map<String, dynamic> recordData,
  }) async {
    try {
      final responseData = await apiClient.put(
        ApiConstants.medicalRecord(recordId),
        body: recordData,
        requireAuth: true,
      );

      MedicalRecordModel record;
      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('data')) {
          record = MedicalRecordModel.fromJson(
              responseData['data'] as Map<String, dynamic>);
        } else {
          record = MedicalRecordModel.fromJson(responseData);
        }
      } else {
        return const Failure('Invalid response format');
      }

      return Success(record);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to update medical record: $e');
    }
  }

  Future<Result<String>> deleteMedicalRecord(int recordId) async {
    try {
      await apiClient.delete(
        ApiConstants.medicalRecord(recordId),
        requireAuth: true,
      );
      return const Success('Medical record deleted successfully');
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to delete medical record: $e');
    }
  }

  Future<Result<List<dynamic>>> fetchSpecialties() async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.medicalRecordSpecialties,
        requireAuth: true,
      );

      final specialties = responseData['specialties'] as List<dynamic>? ?? [];
      return Success(specialties);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch specialties: $e');
    }
  }

  Future<Result<Map<String, dynamic>>> fetchSpecialtyFields(
      int specialtyId) async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.medicalRecordSpecialtyFields(specialtyId),
        requireAuth: true,
      );

      return Success(responseData as Map<String, dynamic>);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch specialty fields: $e');
    }
  }

  Future<Result<MedicalRecordAttachment>> uploadAttachment({
    required int medicalRecordId,
    File? file,
    Uint8List? fileBytes,
    String? fileName,
    String visibility = 'public',
  }) async {
    try {
      if (file == null && fileBytes == null) {
        return const Failure('Either file or fileBytes must be provided');
      }
      if (kIsWeb && (fileBytes == null || fileName == null)) {
        return const Failure(
            'fileBytes and fileName are required on web platform');
      }
      if (!kIsWeb && file == null) {
        return const Failure('file is required on mobile/desktop platform');
      }

      dynamic responseData;
      if (kIsWeb) {
        // Use bytes for web
        responseData = await apiClient.postMultipart(
          ApiConstants.medicalRecordAttachments,
          fields: {
            'medical_record_id': medicalRecordId.toString(),
            'visibility': visibility,
          },
          fileBytes: {
            'file': {
              'bytes': fileBytes!,
              'filename': fileName!,
            },
          },
          requireAuth: true,
        );
      } else {
        // Use File for mobile/desktop
        Map<String, String>? fileNamesMap;
        if (fileName != null && fileName.isNotEmpty) {
          fileNamesMap = {'file': fileName};
        }
        responseData = await apiClient.postMultipart(
          ApiConstants.medicalRecordAttachments,
          fields: {
            'medical_record_id': medicalRecordId.toString(),
            'visibility': visibility,
          },
          files: {
            'file': file!,
          },
          fileNames: fileNamesMap,
          requireAuth: true,
        );
      }

      MedicalRecordAttachment attachment;
      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('data')) {
          attachment = MedicalRecordAttachment.fromJson(
            responseData['data'] as Map<String, dynamic>,
          );
        } else {
          attachment = MedicalRecordAttachment.fromJson(responseData);
        }
      } else {
        return const Failure('Invalid response format');
      }

      return Success(attachment);
    } on ApiException catch (e) {
      // Log the full error for debugging
      if (kDebugMode) {
        print('ApiException during upload: ${e.message}');
        print('Status code: ${e.statusCode}');
        print('Error data: ${e.data}');
      }
      return Failure(e.message);
    } catch (e, stackTrace) {
      // Log the full error for debugging
      if (kDebugMode) {
        print('Exception during upload: $e');
        print('Stack trace: $stackTrace');
      }
      return Failure('Failed to upload attachment: $e');
    }
  }

  Future<Result<String>> deleteAttachment(int attachmentId) async {
    try {
      await apiClient.delete(
        ApiConstants.medicalRecordAttachment(attachmentId),
        requireAuth: true,
      );
      return const Success('Attachment deleted successfully');
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to delete attachment: $e');
    }
  }

  Future<Result<MedicalRecordAttachment>> updateAttachmentVisibility({
    required int attachmentId,
    required String visibility,
  }) async {
    try {
      final responseData = await apiClient.put(
        ApiConstants.medicalRecordAttachment(attachmentId),
        body: {
          'visibility': visibility,
        },
        requireAuth: true,
      );

      MedicalRecordAttachment attachment;
      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('data')) {
          attachment = MedicalRecordAttachment.fromJson(
            responseData['data'] as Map<String, dynamic>,
          );
        } else {
          attachment = MedicalRecordAttachment.fromJson(responseData);
        }
      } else {
        return const Failure('Invalid response format');
      }

      return Success(attachment);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to update attachment: $e');
    }
  }

  /// Update the visibility of a medical record
  /// Only admin, assigned doctor, or the patient can update visibility
  Future<Result<MedicalRecordModel>> updateMedicalRecordVisibility({
    required int recordId,
    required String visibility,
  }) async {
    try {
      if (visibility != 'public' && visibility != 'private') {
        return const Failure('Visibility must be either "public" or "private"');
      }

      final responseData = await apiClient.patch(
        ApiConstants.medicalRecordVisibility(recordId),
        body: {
          'visibility': visibility,
        },
        requireAuth: true,
      );

      MedicalRecordModel record;
      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('data')) {
          record = MedicalRecordModel.fromJson(
            responseData['data'] as Map<String, dynamic>,
          );
        } else {
          record = MedicalRecordModel.fromJson(responseData);
        }
      } else {
        return const Failure('Invalid response format');
      }

      return Success(record);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to update medical record visibility: $e');
    }
  }
}

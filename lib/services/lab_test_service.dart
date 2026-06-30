import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../core/config/api_constants.dart';
import '../core/exceptions/api_exception.dart';
import '../core/network/api_client.dart';
import '../core/utils/result.dart';
import '../data/models/lab_test_model.dart';

class LabTestService {
  final ApiClient apiClient;

  LabTestService({required this.apiClient});

  Future<Result<List<LabTestModel>>> fetchPatientLabTests(int patientId) async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.patientLabTests(patientId),
        requireAuth: true,
      );

      List<dynamic>? data;
      if (responseData is Map<String, dynamic>) {
        data = responseData['data'] as List<dynamic>? ??
            responseData['labTests'] as List<dynamic>?;
      } else if (responseData is List<dynamic>) {
        data = responseData;
      }

      final tests = (data ?? [])
          .map((json) => LabTestModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(tests);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch lab tests: $e');
    }
  }

  Future<Result<LabTestModel>> fetchLabTest(int labTestId) async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.labTest(labTestId),
        requireAuth: true,
      );

      final labTest = responseData is Map<String, dynamic>
          ? LabTestModel.fromJson(
              (responseData['data'] ?? responseData) as Map<String, dynamic>)
          : throw ApiException(message: 'Invalid response format');

      return Success(labTest);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch lab test: $e');
    }
  }

  Future<Result<LabTestModel>> createLabTest(
    Map<String, dynamic> data,
  ) async {
    try {
      final responseData = await apiClient.post(
        ApiConstants.labTests,
        body: data,
        requireAuth: true,
      );

      final labTest = responseData is Map<String, dynamic>
          ? LabTestModel.fromJson(
              (responseData['data'] ?? responseData) as Map<String, dynamic>)
          : throw ApiException(message: 'Invalid response format');

      return Success(labTest);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to create lab test: $e');
    }
  }

  Future<Result<LabTestModel>> updateLabTest(
    int labTestId,
    Map<String, dynamic> data,
  ) async {
    try {
      final responseData = await apiClient.put(
        ApiConstants.labTest(labTestId),
        body: data,
        requireAuth: true,
      );

      final labTest = responseData is Map<String, dynamic>
          ? LabTestModel.fromJson(
              (responseData['data'] ?? responseData) as Map<String, dynamic>)
          : throw ApiException(message: 'Invalid response format');

      return Success(labTest);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to update lab test: $e');
    }
  }

  Future<Result<String>> deleteLabTest(int labTestId) async {
    try {
      await apiClient.delete(
        ApiConstants.labTest(labTestId),
        requireAuth: true,
      );
      return const Success('Lab test deleted successfully');
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to delete lab test: $e');
    }
  }

  Future<Result<LabTestAttachmentModel>> uploadAttachment({
    required int labTestId,
    File? file,
    Uint8List? fileBytes,
    String? fileName,
    String? fileType,
  }) async {
    try {
      if (kIsWeb) {
        if (fileBytes == null || fileName == null) {
          return const Failure('File is required');
        }

        final responseData = await apiClient.postMultipart(
          ApiConstants.labTestAttachments,
          fields: {
            'lab_test_id': labTestId.toString(),
            if (fileType != null) 'file_type': fileType,
          },
          fileBytes: {
            'file': {
              'bytes': fileBytes,
              'filename': fileName,
            },
          },
          requireAuth: true,
        );

        final attachment = responseData is Map<String, dynamic>
            ? LabTestAttachmentModel.fromJson(
                (responseData['data'] ?? responseData) as Map<String, dynamic>)
            : throw ApiException(message: 'Invalid response format');

        return Success(attachment);
      } else {
        if (file == null) {
          return const Failure('File is required');
        }

        final responseData = await apiClient.postMultipart(
          ApiConstants.labTestAttachments,
          fields: {
            'lab_test_id': labTestId.toString(),
            if (fileType != null) 'file_type': fileType,
          },
          files: {'file': file},
          fileNames: fileName != null ? {'file': fileName} : null,
          requireAuth: true,
        );

        final attachment = responseData is Map<String, dynamic>
            ? LabTestAttachmentModel.fromJson(
                (responseData['data'] ?? responseData) as Map<String, dynamic>)
            : throw ApiException(message: 'Invalid response format');

        return Success(attachment);
      }
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to upload attachment: $e');
    }
  }

  Future<Result<String>> deleteAttachment(int attachmentId) async {
    try {
      await apiClient.delete(
        ApiConstants.labTestAttachment(attachmentId),
        requireAuth: true,
      );
      return const Success('Attachment deleted successfully');
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to delete attachment: $e');
    }
  }

  /// Download lab test attachment by id (same as Next.js: auth required, file from B2).
  Future<Result<Uint8List>> downloadAttachment(int attachmentId) async {
    try {
      final bytes = await apiClient.getBytes(
        ApiConstants.labTestAttachmentDownload(attachmentId),
        requireAuth: true,
      );
      return Success(bytes);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to download attachment: $e');
    }
  }
}

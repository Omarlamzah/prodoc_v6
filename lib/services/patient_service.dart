// lib/services/patient_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../core/network/api_client.dart';
import '../core/config/api_constants.dart';
import '../core/exceptions/api_exception.dart';
import '../core/utils/result.dart';
import '../data/models/patient_model.dart';
import '../data/models/patient_list_response.dart';

class PatientService {
  final ApiClient apiClient;

  PatientService({required this.apiClient});

  Future<Result<PatientListResponse>> fetchPatients({
    int page = 1,
    String filter = 'today',
    String sortColumn = 'id',
    String sortDirection = 'asc',
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page.toString(),
        'filter': filter,
        'sort': sortColumn,
        'direction': sortDirection,
      };

      final responseData = await apiClient.get(
        ApiConstants.patients,
        queryParameters: queryParams,
        requireAuth: true,
      );

      final parsed = PatientListResponse.fromJson(responseData);
      return Success(parsed);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch patients: $e');
    }
  }

  Future<Result<String>> deletePatient(int patientId) async {
    try {
      await apiClient.delete(
        ApiConstants.patient(patientId),
        requireAuth: true,
      );
      return const Success('Patient deleted successfully');
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to delete patient: $e');
    }
  }

  Future<Result<List<PatientModel>>> findPatients(String search) async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.findPatients,
        queryParameters: {'search': search},
        requireAuth: true,
      );

      final data = responseData['data'] as List<dynamic>?;
      final patients = (data ?? [])
          .map((json) => PatientModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(patients);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to find patients: $e');
    }
  }

  /// Create a new patient (and a default appointment). Used when patient not found in medical record flow.
  /// Only [name] is required; [email] and [phone] are optional (API requires unique email, placeholder used if empty).
  Future<Result<PatientModel>> createPatient({
    required String name,
    String? email,
    String? phone,
    required int doctorId,
    required String appointmentDate,
    required String appointmentTime,
  }) async {
    try {
      final emailToSend = email?.trim().isNotEmpty == true
          ? email!.trim()
          : 'noemail-${DateTime.now().millisecondsSinceEpoch}@patient.local';

      final responseData = await apiClient.post(
        ApiConstants.patients,
        body: {
          'name': name.trim(),
          'email': emailToSend,
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
          'doctor_id': doctorId,
          'appointment_date': appointmentDate,
          'appointment_time': appointmentTime,
        },
        requireAuth: true,
      );

      if (responseData is Map<String, dynamic> &&
          responseData.containsKey('patient')) {
        final patient =
            PatientModel.fromJson(responseData['patient'] as Map<String, dynamic>);
        return Success(patient);
      }
      return const Failure('Invalid response format');
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to create patient: $e');
    }
  }

  Future<Result<PatientModel>> fetchPatient(int patientId) async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.patient(patientId),
        requireAuth: true,
      );

      // Handle different response structures
      PatientModel patient;
      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('patient')) {
          patient = PatientModel.fromJson(
              responseData['patient'] as Map<String, dynamic>);
        } else if (responseData.containsKey('data')) {
          patient = PatientModel.fromJson(
              responseData['data'] as Map<String, dynamic>);
        } else {
          patient = PatientModel.fromJson(responseData);
        }
      } else {
        return const Failure('Invalid response format');
      }

      return Success(patient);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch patient: $e');
    }
  }

  Future<Result<PatientModel>> updatePatient({
    required int patientId,
    required Map<String, dynamic> patientData,
  }) async {
    try {
      final responseData = await apiClient.put(
        ApiConstants.patient(patientId),
        body: patientData,
        requireAuth: true,
      );

      PatientModel patient;
      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('patient')) {
          patient = PatientModel.fromJson(
              responseData['patient'] as Map<String, dynamic>);
        } else if (responseData.containsKey('data')) {
          patient = PatientModel.fromJson(
              responseData['data'] as Map<String, dynamic>);
        } else {
          patient = PatientModel.fromJson(responseData);
        }
      } else {
        return const Failure('Invalid response format');
      }

      return Success(patient);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to update patient: $e');
    }
  }

  /// Upload patient photo
  /// Only admin and doctor can upload patient photos
  Future<Result<PatientModel>> uploadPatientPhoto({
    required int patientId,
    File? file,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    try {
      // Validate file input
      if (kIsWeb) {
        if (fileBytes == null || fileName == null) {
          return const Failure('File is required');
        }
      } else {
        if (file == null) {
          return const Failure('File is required');
        }
      }

      dynamic responseData;
      if (kIsWeb) {
        // Use bytes for web
        responseData = await apiClient.postMultipart(
          ApiConstants.patientPhoto(patientId),
          fields: {},
          fileBytes: {
            'photo': {
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
          fileNamesMap = {'photo': fileName};
        }
        responseData = await apiClient.postMultipart(
          ApiConstants.patientPhoto(patientId),
          fields: {},
          files: {
            'photo': file!,
          },
          fileNames: fileNamesMap,
          requireAuth: true,
        );
      }

      // The response should contain the updated patient data
      PatientModel patient;
      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('patient')) {
          patient = PatientModel.fromJson(
              responseData['patient'] as Map<String, dynamic>);
        } else {
          // If the response doesn't contain patient, fetch it again
          final fetchResult = await fetchPatient(patientId);
          if (fetchResult is Success<PatientModel>) {
            patient = fetchResult.data;
          } else {
            return const Failure(
                'Photo uploaded but failed to fetch updated patient data');
          }
        }
      } else {
        // If response format is unexpected, fetch patient again
        final fetchResult = await fetchPatient(patientId);
        if (fetchResult is Success<PatientModel>) {
          patient = fetchResult.data;
        } else {
          return const Failure(
              'Photo uploaded but failed to fetch updated patient data');
        }
      }

      return Success(patient);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to upload patient photo: $e');
    }
  }

  /// Delete patient photo
  /// Only admin and doctor can delete patient photos
  Future<Result<String>> deletePatientPhoto(int patientId) async {
    try {
      await apiClient.delete(
        ApiConstants.patientPhoto(patientId),
        requireAuth: true,
      );
      return const Success('Patient photo deleted successfully');
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to delete patient photo: $e');
    }
  }

  /// Generate face embedding for existing patient photo
  /// Only admin and doctor can generate face embeddings
  /// This is useful for patients who have photos but no embeddings
  Future<Result<Map<String, dynamic>>> generateFaceEmbedding(int patientId) async {
    try {
      final responseData = await apiClient.post(
        ApiConstants.generateFaceEmbedding(patientId),
        body: {},
        requireAuth: true,
      );

      if (responseData is Map<String, dynamic>) {
        return Success(responseData);
      } else {
        return const Failure('Invalid response format');
      }
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to generate face embedding: $e');
    }
  }

  /// Export patient data as ZIP (admin/doctor/receptionist). Returns raw bytes.
  Future<Result<Uint8List>> exportPatientData(int patientId) async {
    try {
      final bytes = await apiClient.getBytes(
        ApiConstants.patientExport(patientId),
        requireAuth: true,
      );
      return Success(bytes);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Export failed: $e');
    }
  }

  /// Export current user's own data as ZIP (patient role). Returns raw bytes.
  Future<Result<Uint8List>> exportMyData() async {
    try {
      final bytes = await apiClient.getBytes(
        ApiConstants.patientExportOwn,
        requireAuth: true,
      );
      return Success(bytes);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Export failed: $e');
    }
  }
}

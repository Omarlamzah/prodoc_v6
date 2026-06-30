// lib/services/doctor_service.dart
import '../core/network/api_client.dart';
import '../core/config/api_constants.dart';
import '../core/exceptions/api_exception.dart';
import '../core/utils/result.dart';
import '../data/models/doctor_model.dart';

class DoctorService {
  final ApiClient apiClient;

  DoctorService({required this.apiClient});

  Future<Result<List<DoctorModel>>> fetchDoctors() async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.doctors,
        queryParameters: {'page': '1'},
        requireAuth: true,
      );

      // API returns: {"doctors": [...], "pagination": {...}}
      List<dynamic> doctorsList = [];
      
      if (responseData is Map<String, dynamic>) {
        // Check for 'doctors' key first (most common structure)
        if (responseData.containsKey('doctors')) {
          doctorsList = responseData['doctors'] as List<dynamic>? ?? [];
        } 
        // Fallback to 'data' key
        else if (responseData.containsKey('data')) {
          final data = responseData['data'];
          doctorsList = data is List ? data : [];
        }
      } else if (responseData is List) {
        // If response is directly a list
        doctorsList = responseData;
      }

      final doctors = doctorsList
          .map((json) => DoctorModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(doctors);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch doctors: ${e.toString()}');
    }
  }

  // Public method (no auth required)
  Future<Result<List<DoctorModel>>> fetchPublicDoctors() async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.publicDoctors,
        queryParameters: {'page': '1'},
        requireAuth: false,
      );

      // API returns: {"doctors": [...], "pagination": {...}}
      List<dynamic> doctorsList = [];
      
      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('doctors')) {
          doctorsList = responseData['doctors'] as List<dynamic>? ?? [];
        } else if (responseData.containsKey('data')) {
          final data = responseData['data'];
          doctorsList = data is List ? data : [];
        }
      } else if (responseData is List) {
        doctorsList = responseData;
      }

      final doctors = doctorsList
          .map((json) => DoctorModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(doctors);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch doctors: ${e.toString()}');
    }
  }
}


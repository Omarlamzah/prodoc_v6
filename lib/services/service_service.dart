// lib/services/service_service.dart
import '../core/network/api_client.dart';
import '../core/config/api_constants.dart';
import '../core/exceptions/api_exception.dart';
import '../core/utils/result.dart';
import '../data/models/service_model.dart';

class ServiceService {
  final ApiClient apiClient;

  ServiceService({required this.apiClient});

  Future<Result<List<ServiceModel>>> fetchServices() async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.services,
        requireAuth: true,
      );

      // API returns a direct array: [{...}, {...}]
      List<dynamic> servicesList = [];
      
      if (responseData is List) {
        // Response is directly a list
        servicesList = responseData;
      } else if (responseData is Map<String, dynamic>) {
        // Check for 'services' or 'data' key
        if (responseData.containsKey('services')) {
          servicesList = responseData['services'] as List<dynamic>? ?? [];
        } else if (responseData.containsKey('data')) {
          final data = responseData['data'];
          servicesList = data is List ? data : [];
        }
      }

      final services = servicesList
          .map((json) => ServiceModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(services);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch services: ${e.toString()}');
    }
  }

  // Public method (no auth required)
  Future<Result<List<ServiceModel>>> fetchPublicServices() async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.publicServices,
        requireAuth: false,
      );

      List<dynamic> servicesList = [];
      
      if (responseData is List) {
        servicesList = responseData;
      } else if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('services')) {
          servicesList = responseData['services'] as List<dynamic>? ?? [];
        } else if (responseData.containsKey('data')) {
          final data = responseData['data'];
          servicesList = data is List ? data : [];
        }
      }

      final services = servicesList
          .map((json) => ServiceModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(services);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch services: ${e.toString()}');
    }
  }

  /// Create a new service
  Future<Result<ServiceModel>> createService({
    required String title,
    String? description,
    double? price,
    String? ngapCode,
    bool? status,
  }) async {
    try {
      final responseData = await apiClient.post(
        ApiConstants.services,
        body: {
          'title': title,
          if (description != null && description.isNotEmpty)
            'description': description,
          if (price != null) 'price': price,
          if (ngapCode != null && ngapCode.isNotEmpty) 'ngap_code': ngapCode,
          if (status != null) 'status': status,
        },
        requireAuth: true,
      );

      Map<String, dynamic> serviceData;
      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('data')) {
          serviceData = responseData['data'] as Map<String, dynamic>;
        } else if (responseData.containsKey('service')) {
          serviceData = responseData['service'] as Map<String, dynamic>;
        } else {
          serviceData = responseData;
        }
      } else {
        return const Failure('Invalid response format');
      }

      final service = ServiceModel.fromJson(serviceData);
      return Success(service);
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
      return Failure('Failed to create service: ${e.toString()}');
    }
  }
}


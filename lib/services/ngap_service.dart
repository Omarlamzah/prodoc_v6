// lib/services/ngap_service.dart
import '../core/network/api_client.dart';
import '../core/config/api_constants.dart';
import '../core/exceptions/api_exception.dart';
import '../core/utils/result.dart';
import '../data/models/ngap_model.dart';

class NgapService {
  final ApiClient apiClient;

  NgapService({required this.apiClient});

  /// Fetch all NGAP codes with optional filters
  Future<Result<List<NgapModel>>> fetchNgapCodes({
    int perPage = 50,
    String? search,
    String? category,
    bool? isActive,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'per_page': perPage,
        if (isActive != null) 'is_active': isActive,
        if (category != null) 'category': category,
        if (search != null) 'search': search,
      };

      final responseData = await apiClient.get(
        ApiConstants.ngapCodes,
        queryParameters: queryParams,
        requireAuth: true,
      );

      List<dynamic> ngapList = [];
      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('data')) {
          ngapList = responseData['data'] as List<dynamic>? ?? [];
        }
      } else if (responseData is List) {
        ngapList = responseData;
      }

      final ngapCodes = ngapList
          .map((json) => NgapModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(ngapCodes);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch NGAP codes: ${e.toString()}');
    }
  }

  /// Search NGAP codes (uses the same endpoint with search parameter)
  Future<Result<List<NgapModel>>> searchNgapCodes({
    required String query,
    int limit = 50,
  }) async {
    try {
      // Use the same endpoint with search parameter
      return await fetchNgapCodes(
        perPage: limit,
        search: query,
        isActive: true,
      );
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to search NGAP codes: ${e.toString()}');
    }
  }

  /// Get a single NGAP code by code
  Future<Result<NgapModel>> getNgapCode(String code) async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.ngapCode(code),
        requireAuth: true,
      );

      Map<String, dynamic> ngapData;
      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('data')) {
          ngapData = responseData['data'] as Map<String, dynamic>;
        } else {
          ngapData = responseData;
        }
      } else {
        return const Failure('Invalid response format');
      }

      final ngapCode = NgapModel.fromJson(ngapData);
      return Success(ngapCode);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch NGAP code: ${e.toString()}');
    }
  }

  /// Create a new NGAP code
  Future<Result<NgapModel>> createNgapCode({
    required String code,
    required String labelFr,
    String? labelAr,
    String? category,
    int? coefficientSurgeon,
    int? coefficientAnesthesia,
    double? basePrice,
    bool isActive = true,
  }) async {
    try {
      final responseData = await apiClient.post(
        ApiConstants.ngapCodes,
        body: {
          'code': code,
          'label_fr': labelFr,
          if (labelAr != null && labelAr.isNotEmpty) 'label_ar': labelAr,
          if (category != null && category.isNotEmpty) 'category': category,
          if (coefficientSurgeon != null)
            'coefficient_surgeon': coefficientSurgeon,
          if (coefficientAnesthesia != null)
            'coefficient_anesthesia': coefficientAnesthesia,
          if (basePrice != null) 'base_price': basePrice,
          'is_active': isActive,
        },
        requireAuth: true,
      );

      Map<String, dynamic> ngapData;
      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('data')) {
          ngapData = responseData['data'] as Map<String, dynamic>;
        } else {
          ngapData = responseData;
        }
      } else {
        return const Failure('Invalid response format');
      }

      final ngapCode = NgapModel.fromJson(ngapData);
      return Success(ngapCode);
    } on ApiException catch (e) {
      String errorMessage = e.message;
      if (e.data != null) {
        try {
          final errorData = e.data as Map<String, dynamic>?;
          if (errorData != null && errorData.containsKey('message')) {
            errorMessage = errorData['message'] as String? ?? e.message;
          }
        } catch (_) {}
      }
      return Failure(errorMessage);
    } catch (e) {
      return Failure('Failed to create NGAP code: ${e.toString()}');
    }
  }

  /// Update an existing NGAP code
  Future<Result<NgapModel>> updateNgapCode({
    required String code,
    String? newCode,
    String? labelFr,
    String? labelAr,
    String? category,
    int? coefficientSurgeon,
    int? coefficientAnesthesia,
    double? basePrice,
    bool? isActive,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (newCode != null) body['code'] = newCode;
      if (labelFr != null) body['label_fr'] = labelFr;
      if (labelAr != null) body['label_ar'] = labelAr;
      if (category != null) body['category'] = category;
      if (coefficientSurgeon != null)
        body['coefficient_surgeon'] = coefficientSurgeon;
      if (coefficientAnesthesia != null)
        body['coefficient_anesthesia'] = coefficientAnesthesia;
      if (basePrice != null) body['base_price'] = basePrice;
      if (isActive != null) body['is_active'] = isActive;

      final responseData = await apiClient.put(
        ApiConstants.ngapCode(code),
        body: body,
        requireAuth: true,
      );

      Map<String, dynamic> ngapData;
      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('data')) {
          ngapData = responseData['data'] as Map<String, dynamic>;
        } else {
          ngapData = responseData;
        }
      } else {
        return const Failure('Invalid response format');
      }

      final ngapCode = NgapModel.fromJson(ngapData);
      return Success(ngapCode);
    } on ApiException catch (e) {
      String errorMessage = e.message;
      if (e.data != null) {
        try {
          final errorData = e.data as Map<String, dynamic>?;
          if (errorData != null && errorData.containsKey('message')) {
            errorMessage = errorData['message'] as String? ?? e.message;
          }
        } catch (_) {}
      }
      return Failure(errorMessage);
    } catch (e) {
      return Failure('Failed to update NGAP code: ${e.toString()}');
    }
  }

  /// Delete an NGAP code
  Future<Result<void>> deleteNgapCode(String code) async {
    try {
      await apiClient.delete(
        ApiConstants.ngapCode(code),
        requireAuth: true,
      );
      return const Success(null);
    } on ApiException catch (e) {
      String errorMessage = e.message;
      if (e.data != null) {
        try {
          final errorData = e.data as Map<String, dynamic>?;
          if (errorData != null && errorData.containsKey('message')) {
            errorMessage = errorData['message'] as String? ?? e.message;
          }
        } catch (_) {}
      }
      return Failure(errorMessage);
    } catch (e) {
      return Failure('Failed to delete NGAP code: ${e.toString()}');
    }
  }

  /// Get all unique categories
  Future<Result<List<String>>> getCategories() async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.ngapCodesCategories,
        requireAuth: true,
      );

      List<dynamic> categoriesList = [];
      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('data')) {
          categoriesList = responseData['data'] as List<dynamic>? ?? [];
        }
      } else if (responseData is List) {
        categoriesList = responseData;
      }

      final categories = categoriesList
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();

      return Success(categories);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch categories: ${e.toString()}');
    }
  }
}

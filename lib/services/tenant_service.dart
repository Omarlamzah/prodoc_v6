// lib/services/tenant_service.dart - Add search parameter
import '../core/network/api_client.dart';
import '../core/config/api_constants.dart';
import '../core/exceptions/api_exception.dart';
import '../core/utils/result.dart';
import '../data/models/tenant_model.dart';

class TenantService {
  final ApiClient apiClient;

  TenantService({required this.apiClient});

  Future<Result<List<TenantModel>>> getAllTenants({String? search}) async {
    try {
      // Build query parameters
      final queryParams = search != null && search.isNotEmpty
          ? {'search': search}
          : null;

      // Use requireAuth: false since this is before login
      final responseData = await apiClient.get(
        ApiConstants.getAllTenants,
        requireAuth: false,
        queryParameters: queryParams,
      );

      final List<dynamic> tenantsJson = responseData['data'] ?? responseData['tenants'] ?? [];
      final tenants = tenantsJson
          .map((json) => TenantModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(tenants);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to load tenants: $e');
    }
  }

  /// Get all tenants (admin-only, system-level)
  Future<Result<Map<String, dynamic>>> getSystemTenants({
    String? search,
    int? page,
    int? perPage,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (page != null) {
        queryParams['page'] = page;
      }
      if (perPage != null) {
        queryParams['per_page'] = perPage;
      }

      final responseData = await apiClient.get(
        ApiConstants.systemTenants,
        requireAuth: true,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      return Success(responseData);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to load tenants: $e');
    }
  }

  /// Get tenant details (admin-only)
  Future<Result<TenantModel>> getSystemTenant(int id) async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.systemTenant(id),
        requireAuth: true,
      );

      final tenantData = responseData['data'] ?? responseData;
      final tenant = TenantModel.fromJson(tenantData as Map<String, dynamic>);

      return Success(tenant);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to load tenant: $e');
    }
  }

  /// Delete a tenant (admin-only, requires password confirmation)
  Future<Result<String>> deleteTenant({
    required int tenantId,
    required String password,
  }) async {
    try {
      final responseData = await apiClient.delete(
        ApiConstants.systemTenant(tenantId),
        body: {
          'password': password,
          'confirmation': 'DELETE TENANT',
        },
        requireAuth: true,
      );

      final message = responseData['message'] ??
          responseData['success'] == true
              ? 'Tenant has been permanently deleted.'
              : 'Failed to delete tenant.';
      return Success(message);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to delete tenant: $e');
    }
  }
}
// lib/providers/tenant_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/tenant_service.dart';
import '../services/storage_service.dart';
import '../data/models/tenant_model.dart';
import '../core/utils/result.dart';
import '../core/config/api_constants.dart';
import 'api_providers.dart';

// Storage Service Provider
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

// Tenant Service Provider
final tenantServiceProvider = Provider<TenantService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TenantService(apiClient: apiClient);
});

// Selected Tenant state Provider
final selectedTenantProvider =
    NotifierProvider<SelectedTenantNotifier, TenantModel?>(SelectedTenantNotifier.new);

class SelectedTenantNotifier extends Notifier<TenantModel?> {
  late StorageService _storageService;
  bool _isLoading = true;

  @override
  TenantModel? build() {
    _storageService = ref.watch(storageServiceProvider);
    _loadSavedTenant();
    return null;
  }

  bool get isLoading => _isLoading;

  Future<void> _loadSavedTenant() async {
    _isLoading = true;
    final tenant = await _storageService.getSavedTenant();
    if (tenant != null && tenant.baseUrl != null) {
      state = tenant;
      ApiConstants.setTenantUrls(tenant.baseUrl!);
    }
    _isLoading = false;
  }

  Future<void> waitForLoad() async {
    // Wait until loading is complete
    while (_isLoading) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> selectTenant(TenantModel tenant) async {
    if (tenant.baseUrl != null) {
      state = tenant;
      ApiConstants.setTenantUrls(tenant.baseUrl!);
      await _storageService.saveTenant(tenant);
    }
  }

  Future<void> clearTenant() async {
    state = null;
    ApiConstants.resetToMaster();
    await _storageService.clearTenant();
  }
}

// Tenant List Provider with search support
final tenantListProvider =
    FutureProvider.autoDispose.family<List<TenantModel>, String>(
  (ref, searchQuery) async {
    // Ensure we're using master URL to fetch tenants
    ApiConstants.resetToMaster();

    final service = ref.watch(tenantServiceProvider);
    final result = await service.getAllTenants(search: searchQuery);

    if (result is Success<List<TenantModel>>) {
      return result.data;
    }

    throw Exception((result as Failure).message);
  },
);

// Refresh Provider
final tenantRefreshProvider = Provider((ref) {
  return (String searchQuery) {
    ref.invalidate(tenantListProvider(searchQuery));
  };
});

// Stable key for system tenants list (prevents infinite refetch from new Map each build)
const String _systemTenantsKeySep = '|';
String systemTenantsKey(int page, int perPage, String? search) =>
    '$page$_systemTenantsKeySep$perPage$_systemTenantsKeySep${search ?? ""}';

// System Tenants Provider (Admin-only, paginated). No autoDispose to avoid refetch loop on rebuild.
final systemTenantsProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, key) async {
    final parts = key.split(_systemTenantsKeySep);
    final page = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 1 : 1;
    final perPage = parts.length >= 2 ? int.tryParse(parts[1]) ?? 15 : 15;
    final search = parts.length >= 3 && parts[2].isNotEmpty ? parts[2] : null;

    final service = ref.watch(tenantServiceProvider);
    final result = await service.getSystemTenants(
      search: search,
      page: page,
      perPage: perPage,
    );

    if (result is Success<Map<String, dynamic>>) {
      return result.data;
    }

    throw Exception((result as Failure).message);
  },
);

// System Tenant Details Provider
final systemTenantProvider = FutureProvider.autoDispose.family<TenantModel, int>(
  (ref, tenantId) async {
    final service = ref.watch(tenantServiceProvider);
    final result = await service.getSystemTenant(tenantId);

    if (result is Success<TenantModel>) {
      return result.data;
    }

    throw Exception((result as Failure).message);
  },
);

// Refresh System Tenants Provider
final systemTenantsRefreshProvider = Provider((ref) {
  return (int page, int perPage, String? search) {
    ref.invalidate(systemTenantsProvider(systemTenantsKey(page, perPage, search)));
  };
});

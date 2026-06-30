// lib/providers/tenant_website_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/tenant_website_model.dart';
import '../core/utils/result.dart';
import 'api_providers.dart';
import 'auth_providers.dart';
import 'tenant_providers.dart';

// Tenant Website Config Provider (requires auth)
final tenantWebsiteConfigProvider =
    FutureProvider.autoDispose<Result<TenantWebsiteModel>>(
  (ref) async {
    final authState = ref.watch(authProvider);

    if (authState.isAuth != true) {
      return const Failure('Not authenticated');
    }

    final tenantWebsiteService = ref.watch(tenantWebsiteServiceProvider);
    return await tenantWebsiteService.getTenantWebsiteConfig();
  },
);

// Public Tenant Website Provider (no auth required, uses selected tenant)
final publicTenantWebsiteProvider =
    FutureProvider.autoDispose<Result<TenantWebsiteModel>>(
  (ref) async {
    final selectedTenant = ref.watch(selectedTenantProvider);

    if (selectedTenant == null || selectedTenant.baseUrl == null) {
      return const Failure('No tenant selected');
    }

    final tenantWebsiteService = ref.watch(tenantWebsiteServiceProvider);
    return await tenantWebsiteService.getDefaultTenantWebsite();
  },
);

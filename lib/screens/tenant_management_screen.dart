// lib/screens/tenant_management_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tenant_providers.dart';
import '../providers/auth_providers.dart';
import '../data/models/tenant_model.dart';
import '../core/utils/result.dart';

class TenantManagementScreen extends ConsumerStatefulWidget {
  const TenantManagementScreen({super.key});

  @override
  ConsumerState<TenantManagementScreen> createState() =>
      _TenantManagementScreenState();
}

class _TenantManagementScreenState
    extends ConsumerState<TenantManagementScreen> {
  final _searchController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  int _currentPage = 1;
  final int _perPage = 15;
  TenantModel? _tenantToDelete;
  bool _showDeleteDialog = false;
  bool _isDeleting = false;
  String? _deleteError;

  static const String DELETE_CONFIRMATION_TEXT = 'DELETE TENANT';

  @override
  void dispose() {
    _searchController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  void _showDeleteTenantDialog(TenantModel tenant) {
    setState(() {
      _tenantToDelete = tenant;
      _showDeleteDialog = true;
      _deleteError = null;
      _passwordController.clear();
      _confirmationController.clear();
    });
  }

  void _hideDeleteTenantDialog() {
    setState(() {
      _showDeleteDialog = false;
      _tenantToDelete = null;
      _deleteError = null;
      _passwordController.clear();
      _confirmationController.clear();
    });
  }

  Future<void> _handleDeleteTenant() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_confirmationController.text.trim() != DELETE_CONFIRMATION_TEXT) {
      setState(() {
        _deleteError = 'Please type "$DELETE_CONFIRMATION_TEXT" to confirm.';
      });
      return;
    }

    if (_passwordController.text.trim().isEmpty) {
      setState(() {
        _deleteError = 'Please enter your password.';
      });
      return;
    }

    if (_tenantToDelete == null) {
      return;
    }

    setState(() {
      _isDeleting = true;
      _deleteError = null;
    });

    final tenantService = ref.read(tenantServiceProvider);
    final result = await tenantService.deleteTenant(
      tenantId: _tenantToDelete!.id!,
      password: _passwordController.text.trim(),
    );

    if (!mounted) return;

    if (result is Success<String>) {
      // Refresh the tenant list
      ref.invalidate(systemTenantsProvider(systemTenantsKey(
        _currentPage,
        _perPage,
        _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      )));

      _hideDeleteTenantDialog();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.data),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    } else {
      setState(() {
        _isDeleting = false;
        _deleteError = (result as Failure).message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Check if user is admin
    if (user == null || user.isAdmin != 1) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F0F23) : const Color(0xFFF0F2F5),
        appBar: AppBar(
          title: const Text('Your clinic'),
          backgroundColor: isDark ? const Color(0xFF0F0F23) : Colors.white,
          foregroundColor: isDark ? Colors.white : Colors.black,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Access denied',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Only administrators can manage your clinic.',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final selectedTenant = ref.watch(selectedTenantProvider);
    final searchQuery = _searchController.text.trim().isEmpty
        ? null
        : _searchController.text.trim();
    final tenantsKey = systemTenantsKey(_currentPage, _perPage, searchQuery);
    final tenantsAsync = ref.watch(systemTenantsProvider(tenantsKey));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F23) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.business_outlined, size: 24),
            SizedBox(width: 8),
            Text('Your clinic'),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF0F0F23) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Single-clinic view: no search, no list of other tenants
              Expanded(
                child: tenantsAsync.when(
                  data: (data) {
                    // API returns { "success": true, "data": { "current_page", "data": [...], "last_page", "total" } }
                    final paginator = data['data'];
                    final Map<String, dynamic> paginatorMap = paginator is Map<String, dynamic> ? paginator : <String, dynamic>{};
                    final tenantsList = paginatorMap['data'] is List ? (paginatorMap['data'] as List<dynamic>) : <dynamic>[];
                    final currentPage = paginatorMap['current_page'] as int? ?? 1;
                    final lastPage = paginatorMap['last_page'] as int? ?? 1;
                    final total = paginatorMap['total'] as int? ?? 0;

                    if (tenantsList.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.business_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Your clinic could not be loaded.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final tenants = tenantsList
                        .map((json) => TenantModel.fromJson(
                            json as Map<String, dynamic>))
                        .toList();

                    return Column(
                      children: [
                        // List
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: tenants.length,
                            itemBuilder: (context, index) {
                              final tenant = tenants[index];
                              return Card(
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.1)
                                        : Colors.grey.shade200,
                                  ),
                                ),
                                color: isDark
                                    ? const Color(0xFF1A1A2E)
                                    : Colors.white,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    child: Text(
                                      tenant.name != null &&
                                              tenant.name!.isNotEmpty
                                          ? tenant.name![0].toUpperCase()
                                          : 'T',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    tenant.name ?? 'Unnamed Tenant',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      if (tenant.domain != null)
                                        Row(
                                          children: [
                                            const Icon(Icons.domain,
                                                size: 14,
                                                color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(
                                              tenant.domain!,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      if (tenant.email != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.email_outlined,
                                                  size: 14,
                                                  color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Text(
                                                tenant.email!,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: selectedTenant?.id == tenant.id
                                      ? IconButton(
                                          icon: const Icon(Icons.delete_outline,
                                              color: Colors.red),
                                          onPressed: () =>
                                              _showDeleteTenantDialog(tenant),
                                          tooltip: 'Delete your tenant (this clinic)',
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),

                        // Pagination (only when more than one page)
                        if (lastPage > 1 && total > 1)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1A1A2E)
                                  : Colors.white,
                              border: Border(
                                top: BorderSide(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.grey.shade200,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Page $currentPage of $lastPage ($total total)',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.chevron_left),
                                      onPressed: _currentPage > 1
                                          ? () {
                                              setState(() {
                                                _currentPage--;
                                              });
                                            }
                                          : null,
                                    ),
                                    Text(
                                      '$_currentPage',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.chevron_right),
                                      onPressed: _currentPage < lastPage
                                          ? () {
                                              setState(() {
                                                _currentPage++;
                                              });
                                            }
                                          : null,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, stack) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading tenants',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.toString(),
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            ref.invalidate(systemTenantsProvider(tenantsKey));
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Delete Tenant Dialog
          if (_showDeleteDialog && _tenantToDelete != null)
            _buildDeleteTenantDialog(context, isDark),
        ],
      ),
    );
  }

  Widget _buildDeleteTenantDialog(BuildContext context, bool isDark) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: const Text(
                          'Delete Tenant',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _isDeleting ? null : _hideDeleteTenantDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Warning Message
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This will permanently delete "${_tenantToDelete?.name ?? "this tenant"}" and ALL associated data. This action is IRREVERSIBLE.',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tenant Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tenant: ${_tenantToDelete?.name ?? "N/A"}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_tenantToDelete?.domain != null)
                          Text('Domain: ${_tenantToDelete!.domain}'),
                        if (_tenantToDelete?.email != null)
                          Text('Email: ${_tenantToDelete!.email}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Error message
                  if (_deleteError != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _deleteError!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Your Password',
                      hintText: 'Enter your admin password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Password is required';
                      }
                      return null;
                    },
                    enabled: !_isDeleting,
                  ),
                  const SizedBox(height: 16),

                  // Confirmation field
                  TextFormField(
                    controller: _confirmationController,
                    decoration: InputDecoration(
                      labelText: 'Type "$DELETE_CONFIRMATION_TEXT" to confirm',
                      hintText: DELETE_CONFIRMATION_TEXT,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _confirmationController.text.isNotEmpty &&
                                  _confirmationController.text !=
                                      DELETE_CONFIRMATION_TEXT
                              ? Colors.red
                              : Colors.grey,
                        ),
                      ),
                      prefixIcon: const Icon(Icons.text_fields),
                    ),
                    style: const TextStyle(fontFamily: 'monospace'),
                    validator: (value) {
                      if (value == null ||
                          value.trim() != DELETE_CONFIRMATION_TEXT) {
                        return 'Please type "$DELETE_CONFIRMATION_TEXT" to confirm';
                      }
                      return null;
                    },
                    enabled: !_isDeleting,
                    onChanged: (value) {
                      setState(() {
                        _deleteError = null;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isDeleting ? null : _hideDeleteTenantDialog,
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isDeleting ? null : _handleDeleteTenant,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: _isDeleting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Delete Tenant'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

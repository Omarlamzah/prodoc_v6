import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tenant_providers.dart';
import '../providers/auth_providers.dart';
import '../widgets/tenant_card.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart';
import 'login_screen.dart';
import '../l10n/app_localizations.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    const searchQuery = ''; // Default empty search
    final tenantAsync = ref.watch(tenantListProvider(searchQuery));
    final refresh = ref.watch(tenantRefreshProvider);
    final authState = ref.watch(authProvider);

    // Listen for logout and redirect
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuth == false && previous?.isAuth == true) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
      if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: Colors.green,
          ),
        );
        ref.read(authProvider.notifier).resetSuccessMessage();
      }
    });

    void handleLogout() {
      showDialog(
        context: context,
        builder: (context) {
          final localizations = AppLocalizations.of(context);
          return AlertDialog(
            title: Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return const Text('Logout');
              },
            ),
            content: Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return const Text('Are you sure you want to logout?');
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return const Text('Cancel');
                  },
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  ref.read(authProvider.notifier).logout();
                },
                child: Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return const Text('Logout');
                  },
                ),
              ),
            ],
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return const Text('Tenants List');
          },
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // User info
          if (authState.user != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      authState.user!.name ?? 'User',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (authState.user!.email != null)
                      Text(
                        authState.user!.email!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          // Welcome Card with User Info
          if (authState.user != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Text(
                            'Welcome, ${authState.user!.name ?? 'User'}!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  if (authState.user!.email != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      authState.user!.email!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer
                            .withOpacity(0.7),
                      ),
                    ),
                  ],
                  if (authState.user!.id != null) ...[
                    const SizedBox(height: 4),
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Text(
                          'User ID: ${authState.user!.id}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer
                                .withOpacity(0.6),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          // Tenants List
          Expanded(
            child: tenantAsync.when(
              data: (tenants) {
                if (tenants.isEmpty) {
                  return Center(
                    child: Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return const Text(
                          'No tenants found',
                          style: TextStyle(fontSize: 16),
                        );
                      },
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    refresh(searchQuery);
                    return ref.refresh(tenantListProvider(searchQuery).future);
                  },
                  child: ListView.builder(
                    itemCount: tenants.length,
                    itemBuilder: (context, index) {
                      return TenantCard(tenant: tenants[index]);
                    },
                  ),
                );
              },
              loading: () => const LoadingWidget(),
              error: (error, stackTrace) => CustomErrorWidget(
                message: error.toString(),
                onRetry: () {
                  refresh(searchQuery);
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          refresh(searchQuery);
        },
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

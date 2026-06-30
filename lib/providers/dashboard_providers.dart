// lib/providers/dashboard_providers.dart - CORRECTED VERSION
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/dashboard_service.dart';
import '../data/models/dashboard_model.dart';
import '../core/utils/result.dart';
import 'api_providers.dart';
import 'auth_providers.dart';

// Dashboard Service Provider
final dashboardServiceProvider = Provider<DashboardService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DashboardService(apiClient: apiClient);
});

// Time Range Provider
// Time Range Provider
class TimeRangeNotifier extends Notifier<String> {
  @override
  String build() => 'day';
  
  void update(String value) => state = value;
}
final timeRangeProvider = NotifierProvider<TimeRangeNotifier, String>(TimeRangeNotifier.new);

// Dashboard Data Provider - Returns Result type to match your existing code
final dashboardDataProvider = FutureProvider.autoDispose
    .family<Result<DashboardModel>, String>((ref, timeRange) async {
  // Wait for authentication before fetching
  final authState = ref.watch(authProvider);
  
  // Don't fetch if not authenticated or still checking
  if (authState.isAuth != true) {
    return const Failure('Not authenticated');
  }
  
  final dashboardService = ref.watch(dashboardServiceProvider);
  return await dashboardService.getDashboard(timeRange: timeRange); // Changed from fetchDashboardData
});

// Refresh Dashboard Provider - Takes timeRange parameter
final dashboardRefreshProvider = Provider((ref) {
  return (String timeRange) {
    ref.invalidate(dashboardDataProvider(timeRange));
  };
  
});
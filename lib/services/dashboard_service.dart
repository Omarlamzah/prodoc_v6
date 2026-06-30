// lib/services/dashboard_service.dart
import '../core/network/api_client.dart';
import '../core/config/api_constants.dart';
import '../core/exceptions/api_exception.dart';
import '../core/utils/result.dart';
import '../data/models/dashboard_model.dart';

class DashboardService {
  final ApiClient apiClient;

  DashboardService({required this.apiClient});

  Future<Result<DashboardModel>> getDashboard({String? timeRange}) async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.dashboard,
        queryParameters: timeRange != null ? {'timeRange': timeRange} : null,
        requireAuth: true,
      );

      // The response might have the dashboard data directly or nested
      final dashboard = DashboardModel.fromJson(responseData);
      return Success(dashboard);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to load dashboard: $e');
    }
  }
}
// lib/services/report_service.dart
import '../core/network/api_client.dart';
import '../core/config/api_constants.dart';
import '../core/exceptions/api_exception.dart';
import '../core/utils/result.dart';

class ReportService {
  final ApiClient apiClient;

  ReportService({required this.apiClient});

  Future<Result<Map<String, dynamic>>> fetchReport({
    required String reportType,
    Map<String, dynamic>? filters,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (filters != null) {
        queryParams.addAll(filters);
        // Remove empty values
        queryParams.removeWhere((key, value) =>
            value == null ||
            value == '' ||
            (value is bool &&
                value == false &&
                key != 'low_stock' &&
                key != 'expiring_soon'));
      }

      final responseData = await apiClient.get(
        ApiConstants.report(reportType),
        queryParameters: queryParams,
        requireAuth: true,
      );

      return Success(responseData as Map<String, dynamic>);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch report: ${e.toString()}');
    }
  }
}

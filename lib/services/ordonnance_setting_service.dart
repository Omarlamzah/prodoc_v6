// lib/services/ordonnance_setting_service.dart
import '../core/network/api_client.dart';
import '../core/config/api_constants.dart';
import '../core/exceptions/api_exception.dart';
import '../core/utils/result.dart';
import '../data/models/ordonnance_setting_model.dart';

class OrdonnanceSettingService {
  final ApiClient apiClient;

  OrdonnanceSettingService({required this.apiClient});

  Future<Result<OrdonnanceSettingModel>> getOrdonnanceSettings() async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.ordonnanceSettings,
        requireAuth: true,
      );

      final settings = OrdonnanceSettingModel.fromJson(responseData);
      return Success(settings);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch ordonnance settings: $e');
    }
  }

  Future<Result<OrdonnanceSettingModel>> updateOrdonnanceSettings(
      Map<String, dynamic> data) async {
    try {
      final responseData = await apiClient.put(
        ApiConstants.ordonnanceSettings,
        body: data,
        requireAuth: true,
      );

      final settings = OrdonnanceSettingModel.fromJson(responseData);
      return Success(settings);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to update ordonnance settings: $e');
    }
  }

  Future<Result<OrdonnanceSettingModel>> resetOrdonnanceSettings() async {
    try {
      final responseData = await apiClient.put(
        ApiConstants.ordonnanceSettingsReset,
        requireAuth: true,
      );

      final settings =
          OrdonnanceSettingModel.fromJson(responseData['settings']);
      return Success(settings);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to reset ordonnance settings: $e');
    }
  }
}

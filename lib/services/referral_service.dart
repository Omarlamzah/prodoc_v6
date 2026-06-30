import '../core/config/api_constants.dart';
import '../core/exceptions/api_exception.dart';
import '../core/network/api_client.dart';
import '../core/utils/result.dart';

class ReferralService {
  final ApiClient apiClient;

  ReferralService({required this.apiClient});

  /// Get current tenant's referral code and stats (admin only).
  Future<Result<Map<String, dynamic>>> getMyReferralCode() async {
    try {
      final response = await apiClient.get(
        ApiConstants.referralMyCode,
        requireAuth: true,
      );
      final data = response as Map<String, dynamic>;
      if (data['success'] != true || data['data'] == null) {
        return Failure(data['message']?.toString() ?? 'Failed to load referral code');
      }
      return Success(data['data'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to load referral code: $e');
    }
  }

  /// Validate a referral code (before applying).
  Future<Result<Map<String, dynamic>>> validateReferralCode(String code) async {
    try {
      final response = await apiClient.post(
        ApiConstants.referralValidate,
        body: {'referral_code': code.toUpperCase()},
        requireAuth: true,
      );
      final data = response as Map<String, dynamic>;
      if (data['success'] != true) {
        return Failure(data['message']?.toString() ?? 'Invalid code');
      }
      return Success({
        'valid': data['valid'] == true,
        'referrer_name': data['data']?['referrer_name'],
      });
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to validate code: $e');
    }
  }

  /// Apply a referral code for the current tenant (admin only).
  Future<Result<Map<String, dynamic>>> applyReferralCode(String code) async {
    try {
      final response = await apiClient.post(
        ApiConstants.referralApply,
        body: {'referral_code': code.toUpperCase()},
        requireAuth: true,
      );
      final data = response as Map<String, dynamic>;
      if (data['success'] != true) {
        return Failure(data['message']?.toString() ?? 'Failed to apply code');
      }
      return Success({
        'message': data['message'],
        'reward_days': data['data']?['reward_days'],
        'referrer_name': data['data']?['referrer_name'],
      });
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to apply referral code: $e');
    }
  }

  /// Get referral history (given and received) for current tenant (admin only).
  Future<Result<Map<String, dynamic>>> getReferralHistory() async {
    try {
      final response = await apiClient.get(
        ApiConstants.referralHistory,
        requireAuth: true,
      );
      final data = response as Map<String, dynamic>;
      if (data['success'] != true || data['data'] == null) {
        return Failure(data['message']?.toString() ?? 'Failed to load history');
      }
      return Success(data['data'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to load referral history: $e');
    }
  }
}

import '../core/config/api_constants.dart';
import '../core/exceptions/api_exception.dart';
import '../core/network/api_client.dart';
import '../core/utils/result.dart';
import '../data/models/subscription_model.dart';
import '../data/models/subscription_plan_model.dart';

class SubscriptionService {
  final ApiClient apiClient;

  SubscriptionService({required this.apiClient});

  Future<Result<Map<String, dynamic>>> getSubscriptions() async {
    try {
      final response = await apiClient.get(
        ApiConstants.subscriptions,
        requireAuth: true,
      );

      final subs = (response['subscriptions'] as List<dynamic>? ?? [])
          .map((e) => SubscriptionModel.fromJson(e as Map<String, dynamic>))
          .toList();

      return Success({
        'subscriptions': subs,
        'tenant': response['tenant'],
      });
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to load subscriptions: $e');
    }
  }

  Future<Result<List<SubscriptionPlanModel>>> getPlans() async {
    try {
      final response = await apiClient.get(
        ApiConstants.subscriptionPlans,
        requireAuth: true,
      );

      final plans = (response['plans'] as List<dynamic>? ?? [])
          .map((e) => SubscriptionPlanModel.fromJson(e))
          .toList();

      return Success(plans);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to load plans: $e');
    }
  }

  Future<Result<Map<String, dynamic>>> createSubscription({
    required String planId,
    required String returnUrl,
    required String cancelUrl,
    bool isRenewal = false,
    bool isUpgrade = false,
  }) async {
    try {
      final body = {
        'plan_id': planId,
        'return_url': returnUrl,
        'cancel_url': cancelUrl,
        'is_renewal': isRenewal,
        'is_upgrade': isUpgrade,
      };

      final response = await apiClient.post(
        ApiConstants.createSubscription,
        body: body,
        requireAuth: true,
      );

      return Success(response as Map<String, dynamic>);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to create subscription: $e');
    }
  }

  Future<Result<String>> cancelSubscription(int subscriptionId) async {
    try {
      final response = await apiClient.post(
        ApiConstants.cancelSubscription(subscriptionId),
        requireAuth: true,
      );

      final message = (response as Map<String, dynamic>?)?['message'] ??
          'Subscription cancelled';
      return Success(message);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to cancel subscription: $e');
    }
  }

  // ——— PayPal one-time checkout (same flow as Next.js) ———

  Future<Result<Map<String, dynamic>>> getPayPalConfig() async {
    try {
      final response = await apiClient.get(
        ApiConstants.paypalConfig,
        requireAuth: true,
      );
      return Success(response as Map<String, dynamic>);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to load PayPal config: $e');
    }
  }

  Future<Result<String>> getPayPalClientToken() async {
    try {
      final response = await apiClient.get(
        ApiConstants.paypalClientToken,
        requireAuth: true,
      );
      final token = (response as Map<String, dynamic>)['accessToken']?.toString();
      if (token == null || token.isEmpty) {
        return Failure('No client token');
      }
      return Success(token);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to get PayPal client token: $e');
    }
  }

  Future<Result<String>> createPayPalOrder({
    required double amount,
    required String currency,
    String? planId,
    String? description,
  }) async {
    try {
      final body = <String, dynamic>{
        'amount': amount,
        'currency': currency,
      };
      if (planId != null && planId.isNotEmpty) body['plan_id'] = planId;
      if (description != null && description.isNotEmpty) {
        body['description'] = description;
      }

      final response = await apiClient.post(
        ApiConstants.paypalCreateOrder,
        body: body,
        requireAuth: true,
      );

      final orderId = (response as Map<String, dynamic>?)?['id']?.toString();
      if (orderId == null || orderId.isEmpty) {
        return Failure('No order ID returned');
      }
      return Success(orderId);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to create order: $e');
    }
  }

  Future<Result<Map<String, dynamic>>> capturePayPalOrder({
    required String orderId,
    required String planId,
  }) async {
    try {
      final response = await apiClient.post(
        ApiConstants.paypalCaptureOrder(orderId),
        body: {'plan_id': planId},
        requireAuth: true,
      );
      return Success(response as Map<String, dynamic>);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to capture order: $e');
    }
  }

  // Public method to get subscriptions (no auth required)
  // This is used for checking subscription expiration before login
  Future<Result<Map<String, dynamic>>> getSubscriptionsPublic() async {
    try {
      final response = await apiClient.get(
        ApiConstants.subscriptions,
        requireAuth: false,
      );

      final subs = (response['subscriptions'] as List<dynamic>? ?? [])
          .map((e) => SubscriptionModel.fromJson(e as Map<String, dynamic>))
          .toList();

      return Success({
        'subscriptions': subs,
        'tenant': response['tenant'],
      });
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to load subscriptions: $e');
    }
  }

  // Check if subscription expires in less than specified days
  // Returns days until expiration if less than threshold, null otherwise
  // Uses ceil to round up (like the React code) so that even 23 hours counts as 1 day
  static int? checkExpirationWarning(
    List<SubscriptionModel> subscriptions,
    int thresholdDays,
  ) {
    if (subscriptions.isEmpty) return null;

    // Find active subscription (check for active status including trialing)
    final activeSubscription = subscriptions.firstWhere(
      (sub) =>
          sub.isActive && (sub.status == 'active' || sub.status == 'trialing'),
      orElse: () => subscriptions.first,
    );

    // Use trial_ends_at if status is trialing, otherwise use ends_at
    DateTime? expirationDate;
    if (activeSubscription.status == 'trialing' &&
        activeSubscription.trialEndsAt != null) {
      expirationDate = activeSubscription.trialEndsAt;
    } else {
      expirationDate = activeSubscription.endsAt;
    }

    if (expirationDate == null) return null;

    final now = DateTime.now();
    final timeDiff = expirationDate.difference(now);

    // Calculate days using ceil (round up) - same as React: Math.ceil(timeDiff / (1000 * 60 * 60 * 24))
    // Convert to hours first, then divide by 24 and round up
    final hoursDiff = timeDiff.inHours;
    final daysLeft = (hoursDiff / 24).ceil();

    // Return days if expiration is within threshold and not expired
    if (daysLeft >= 0 && daysLeft < thresholdDays) {
      return daysLeft;
    }

    return null;
  }
}

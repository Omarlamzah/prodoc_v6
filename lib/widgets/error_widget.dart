import 'package:flutter/material.dart';

class CustomErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String? subscriptionButtonLabel;
  final VoidCallback? onSubscriptionTap;

  const CustomErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.subscriptionButtonLabel,
    this.onSubscriptionTap,
  });

  @override
  Widget build(BuildContext context) {
    final showSubscriptionButton = (subscriptionButtonLabel != null &&
            subscriptionButtonLabel!.isNotEmpty &&
            onSubscriptionTap != null) ||
        (onSubscriptionTap != null &&
            _looksLikeSubscriptionExpired(message));
    final isSubscriptionExpired = showSubscriptionButton;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: isSubscriptionExpired
              ? _buildSubscriptionExpiredCard(context, showSubscriptionButton)
              : _buildGenericError(context),
        ),
      ),
    );
  }

  Widget _buildSubscriptionExpiredCard(
      BuildContext context, bool showSubscriptionButton) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_busy_rounded,
                size: 44,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.verified_user_rounded,
                          size: 22, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Vos données sont en sécurité',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toutes les données de votre cabinet sont sauvegardées et sécurisées. Dès que vous renouvelez votre abonnement, l\'accès est restauré immédiatement.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_rounded, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Paiement sécurisé • Données sauvegardées',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (showSubscriptionButton && onSubscriptionTap != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onSubscriptionTap,
                  icon: const Icon(Icons.credit_card_rounded, size: 22),
                  label: Text(
                    subscriptionButtonLabel ?? 'Renouveler l\'abonnement',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            if (onRetry != null) ...[
              if (showSubscriptionButton && onSubscriptionTap != null)
                const SizedBox(height: 10),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Réessayer'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGenericError(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
        const SizedBox(height: 16),
        Text(
          message,
          style: const TextStyle(color: Colors.red, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ],
    );
  }

  static bool _looksLikeSubscriptionExpired(String message) {
    final lower = message.toLowerCase();
    return lower.contains('expiré') ||
        lower.contains('expired') ||
        lower.contains('abonnement');
  }
}


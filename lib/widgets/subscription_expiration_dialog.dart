// lib/widgets/subscription_expiration_dialog.dart
import 'package:flutter/material.dart';
import '../screens/subscription_management_screen.dart';

class SubscriptionExpirationDialog extends StatelessWidget {
  final int daysUntilExpiration;

  const SubscriptionExpirationDialog({
    super.key,
    required this.daysUntilExpiration,
  });

  static Future<void> show(BuildContext context, int daysUntilExpiration) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SubscriptionExpirationDialog(
        daysUntilExpiration: daysUntilExpiration,
      ),
    );
  }

  void _handleRenewNow(BuildContext context) {
    // Close the dialog first
    Navigator.of(context).pop();

    // Navigate to subscription management screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SubscriptionManagementScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final daysText =
        daysUntilExpiration == 1 ? '1 jour' : '$daysUntilExpiration jours';

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 28,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '⚠️ Attention : Expiration de l\'abonnement',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Votre abonnement expire dans $daysText.',
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Pensez à renouveler bientôt pour éviter toute interruption de service.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
              height: 1.5,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Fermer',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => _handleRenewNow(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Renouveler maintenant',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

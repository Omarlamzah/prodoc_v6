// lib/widgets/whatsapp_status_badge.dart
import 'package:flutter/material.dart';

/// WhatsApp Status Badge Widget
/// Displays the status of a WhatsApp message with appropriate colors and icons
class WhatsAppStatusBadge extends StatelessWidget {
  final String status;
  final bool showLabel;

  const WhatsAppStatusBadge({
    Key? key,
    required this.status,
    this.showLabel = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final config = _getStatusConfig(status.toLowerCase());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: config['color'] as Color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: config['borderColor'] as Color,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config['icon'] as IconData,
            size: 14,
            color: config['iconColor'] as Color,
          ),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              config['label'] as String,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: config['textColor'] as Color,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status) {
      case 'accepted':
        return {
          'icon': Icons.access_time,
          'color': Colors.yellow.shade100,
          'borderColor': Colors.yellow.shade300,
          'textColor': Colors.yellow.shade800,
          'iconColor': Colors.yellow.shade800,
          'label': 'Accepted',
        };
      case 'sent':
        return {
          'icon': Icons.check,
          'color': Colors.blue.shade100,
          'borderColor': Colors.blue.shade300,
          'textColor': Colors.blue.shade800,
          'iconColor': Colors.blue.shade800,
          'label': 'Sent',
        };
      case 'delivered':
        return {
          'icon': Icons.done_all,
          'color': Colors.green.shade100,
          'borderColor': Colors.green.shade300,
          'textColor': Colors.green.shade800,
          'iconColor': Colors.green.shade800,
          'label': 'Delivered',
        };
      case 'read':
        return {
          'icon': Icons.done_all,
          'color': Colors.teal.shade100,
          'borderColor': Colors.teal.shade300,
          'textColor': Colors.teal.shade800,
          'iconColor': Colors.teal.shade800,
          'label': 'Read',
        };
      case 'failed':
        return {
          'icon': Icons.error_outline,
          'color': Colors.red.shade100,
          'borderColor': Colors.red.shade300,
          'textColor': Colors.red.shade800,
          'iconColor': Colors.red.shade800,
          'label': 'Failed',
        };
      case 'loading':
        return {
          'icon': Icons.refresh,
          'color': Colors.grey.shade100,
          'borderColor': Colors.grey.shade300,
          'textColor': Colors.grey.shade800,
          'iconColor': Colors.grey.shade800,
          'label': 'Loading...',
        };
      default:
        return {
          'icon': Icons.chat,
          'color': Colors.grey.shade100,
          'borderColor': Colors.grey.shade300,
          'textColor': Colors.grey.shade800,
          'iconColor': Colors.grey.shade800,
          'label': 'Unknown',
        };
    }
  }
}

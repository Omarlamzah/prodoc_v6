// lib/widgets/api_notification_bell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/api_notification_provider.dart';
import 'api_notification_list.dart';

/// Notification bell button widget that shows unread count and opens notification list
class ApiNotificationBell extends ConsumerWidget {
  final Color? iconColor;
  final Color? badgeColor;
  final double iconSize;
  final double badgeSize;

  const ApiNotificationBell({
    super.key,
    this.iconColor,
    this.badgeColor,
    this.iconSize = 24,
    this.badgeSize = 20,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationState = ref.watch(notificationProvider);
    final unreadCount = notificationState.unreadCount;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(
            Icons.notifications_outlined,
            color: iconColor ?? (isDark ? Colors.white : Colors.black87),
            size: iconSize,
          ),
          onPressed: () {
            // Fetch notifications when opening
            ref.read(notificationProvider.notifier).fetchNotifications(
                  refresh: true,
                );
            // Show notification list
            _showNotificationList(context, ref);
          },
          tooltip: 'Notifications',
        ),
        if (unreadCount > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: badgeColor ?? Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: BoxConstraints(
                minWidth: badgeSize,
                minHeight: badgeSize,
              ),
              child: Center(
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showNotificationList(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ApiNotificationList(),
    );
  }
}

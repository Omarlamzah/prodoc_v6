// lib/widgets/api_notification_list.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/api_notification_provider.dart';
import '../data/models/api_notification.dart';
import 'package:intl/intl.dart';

/// Notification list widget that displays API notifications
class ApiNotificationList extends ConsumerStatefulWidget {
  const ApiNotificationList({super.key});

  @override
  ConsumerState<ApiNotificationList> createState() =>
      _ApiNotificationListState();
}

class _ApiNotificationListState extends ConsumerState<ApiNotificationList> {
  @override
  void initState() {
    super.initState();
    // Fetch notifications when opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationProvider.notifier).fetchNotifications(
            refresh: true,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final notificationState = ref.watch(notificationProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(context, notificationState, isDark),
          // Divider
          Divider(height: 1, color: Colors.grey[300]),
          // Content
          Expanded(
            child: _buildContent(context, notificationState, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, NotificationState state, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            'Notifications',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const Spacer(),
          if (state.unreadCount > 0)
            TextButton.icon(
              onPressed: () async {
                await ref.read(notificationProvider.notifier).markAllAsRead();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Toutes les notifications marquées comme lues')),
                  );
                }
              },
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Tout marquer comme lu'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            color: isDark ? Colors.white : Colors.black87,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, NotificationState state, bool isDark) {
    // Debug: Print state
    debugPrint('[ApiNotificationList] State: isLoading=${state.isLoading}, '
        'notifications=${state.notifications.length}, '
        'error=${state.error}, unreadCount=${state.unreadCount}');

    if (state.isLoading && state.notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Erreur lors du chargement',
              style: TextStyle(color: Colors.grey[400]),
            ),
            const SizedBox(height: 8),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  state.error!,
                  style: TextStyle(color: Colors.red[300], fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            TextButton(
              onPressed: () {
                ref.read(notificationProvider.notifier).fetchNotifications(
                      refresh: true,
                    );
              },
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (state.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune notification',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[400],
              ),
            ),
            if (state.unreadCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Mais il y a ${state.unreadCount} notification(s) non lue(s)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(notificationProvider.notifier).fetchNotifications(
              refresh: true,
            );
      },
      child: ListView.builder(
        itemCount: state.notifications.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.notifications.length) {
            // Load more button
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: TextButton(
                  onPressed: state.isLoading
                      ? null
                      : () {
                          ref
                              .read(notificationProvider.notifier)
                              .fetchNotifications(
                                page: state.currentPage + 1,
                              );
                        },
                  child: state.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Charger plus'),
                ),
              ),
            );
          }

          final notification = state.notifications[index];
          return _buildNotificationItem(context, notification, isDark);
        },
      ),
    );
  }

  Widget _buildNotificationItem(
      BuildContext context, ApiNotification notification, bool isDark) {
    final isRead = notification.isRead;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        ref.read(notificationProvider.notifier).deleteNotification(
              notification.id,
            );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification supprimée')),
        );
      },
      child: InkWell(
        onTap: () async {
          if (!isRead) {
            await ref.read(notificationProvider.notifier).markAsRead(
                  notification.id,
                );
          }
          // Handle navigation based on notification type
          _handleNotificationTap(context, notification);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isRead
                ? Colors.transparent
                : (isDark
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.blue.withOpacity(0.05)),
            border: Border(
              bottom: BorderSide(
                color: Colors.grey[300]!,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getNotificationColor(notification.type)
                      .withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getNotificationIcon(notification.type),
                  color: _getNotificationColor(notification.type),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(notification.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              // Unread indicator
              if (!isRead)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getNotificationColor(String type) {
    if (type.contains('Appointment')) {
      return Colors.blue;
    } else if (type.contains('Invoice')) {
      return Colors.orange;
    } else if (type.contains('Prescription')) {
      return Colors.green;
    } else if (type.contains('Emergency')) {
      return Colors.red;
    }
    return Colors.grey;
  }

  IconData _getNotificationIcon(String type) {
    if (type.contains('Appointment')) {
      return Icons.calendar_today;
    } else if (type.contains('Invoice')) {
      return Icons.receipt;
    } else if (type.contains('Prescription')) {
      return Icons.medication;
    } else if (type.contains('Emergency')) {
      return Icons.warning;
    }
    return Icons.notifications;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'À l\'instant';
        }
        return 'Il y a ${difference.inMinutes} min';
      }
      return 'Il y a ${difference.inHours} h';
    } else if (difference.inDays == 1) {
      return 'Hier';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} jours';
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  void _handleNotificationTap(BuildContext context, ApiNotification notification) {
    // Navigate based on notification type and data
    final data = notification.data;
    
    if (data.containsKey('appointment_id')) {
      // Navigate to appointment details
      // Navigator.push(...);
    } else if (data.containsKey('prescription_id')) {
      // Navigate to prescription details
      // Navigator.push(...);
    } else if (data.containsKey('invoice_id')) {
      // Navigate to invoice details
      // Navigator.push(...);
    }
    // Add more navigation logic as needed
  }
}

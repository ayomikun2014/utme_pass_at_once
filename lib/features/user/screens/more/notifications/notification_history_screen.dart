import 'package:flutter/material.dart';
import 'package:utme_pass_at_once/core/utils/custom_loader.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../auth/providers/auth_provider.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/utils/bg.dart';
import '../../../../../core/utils/custom_app_bar.dart';
import '../../../providers/notification_provider.dart';
import '../../../models/notification_model.dart';
import '../../../../../routes.dart';

class NotificationHistoryScreen extends StatelessWidget {
  const NotificationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    final notificationProvider = context.read<NotificationProvider>();

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          CustomScrollView(
            slivers: [
              CustomAppBar(
                title: 'Notifications',
                subtitle: 'Your recent updates and reminders.',
                isLeading: true,
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.check_circle_rounded),
                    onPressed: () =>
                        notificationProvider.markAllAsRead(user.uid),
                    tooltip: 'Mark all as read',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_rounded),
                    onPressed: () => _confirmClearAll(context, user.uid),
                    tooltip: 'Clear all',
                  ),
                ],
              ),
              StreamBuilder<List<NotificationModel>>(
                stream: notificationProvider.getNotificationStream(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      child: CustomLoader(),
                    );
                  }

                  final notifications = snapshot.data ?? [];

                  if (notifications.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_off_rounded,
                              size: 64,
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No notifications yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final notification = notifications[index];
                        return _NotificationTile(
                          notification: notification,
                          onTap: () {
                            notificationProvider.markAsRead(
                              user.uid,
                              notification.id,
                            );
                            Navigator.pushNamed(
                              context,
                              AppRoutes.notificationDetails,
                              arguments: notification,
                            );
                          },
                          onDelete: () {
                            notificationProvider.deleteNotification(
                              user.uid,
                              notification.id,
                            );
                          },
                        );
                      }, childCount: notifications.length),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmClearAll(BuildContext context, String uid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<NotificationProvider>().clearAll(uid);
              Navigator.pop(context);
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getTypeColor(notification.type).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getTypeIcon(notification.type),
                      color: _getTypeColor(notification.type),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              DateFormat('dd MMM, hh:mm a').format(notification.createdAt),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                            const Spacer(),
                            if (!notification.isRead)
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: notification.isRead
                                ? FontWeight.w600
                                : FontWeight.w800,
                            fontSize: 14,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          notification.body,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              color: isDark ? AppColors.dividerDark : Colors.grey.shade200,
              height: 1,
              thickness: 0.8,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'payment':
      case 'payment_approved':
        return Icons.credit_card_rounded;
      case 'payment_rejected':
        return Icons.credit_card_off_rounded;
      case 'exam_unlock':
        return Icons.lock_open_rounded;
      case 'result':
        return Icons.description_rounded;
      case 'reminder':
        return Icons.timer_rounded;
      case 'content_update':
        return Icons.library_books_rounded;
      case 'broadcast':
        return Icons.campaign_rounded;
      case 'system_update':
        return Icons.system_update_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'payment':
      case 'payment_approved':
        return Colors.green;
      case 'payment_rejected':
        return Colors.red;
      case 'exam_unlock':
        return Colors.orange;
      case 'result':
        return Colors.blue;
      case 'reminder':
        return Colors.purple;
      case 'content_update':
        return Colors.teal;
      case 'broadcast':
        return Colors.amber.shade700;
      case 'system_update':
        return Colors.indigo;
      default:
        return AppColors.primary;
    }
  }
}

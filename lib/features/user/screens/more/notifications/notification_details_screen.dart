import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/utils/bg.dart';
import '../../../../../core/utils/custom_app_bar.dart';
import '../../../../../routes.dart';
import '../../../models/notification_model.dart';
import 'package:utme_pass_at_once/features/user/utils/rich_text_link_renderer.dart';

class NotificationDetailsScreen extends StatelessWidget {
  final NotificationModel? notification;
  final Map<String, dynamic>? notificationData;

  const NotificationDetailsScreen({
    super.key,
    this.notification,
    this.notificationData,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Resolve details from either constructor parameter
    final title = notification?.title ?? notificationData?['title'] ?? 'Notification';
    final body = notification?.body ?? notificationData?['body'] ?? '';
    final type = notification?.type ?? notificationData?['type'] ?? 'general';

    DateTime createdAtDate = DateTime.now();
    if (notification != null) {
      createdAtDate = notification!.createdAt;
    } else if (notificationData?['createdAt'] != null) {
      final parsed = DateTime.tryParse(notificationData!['createdAt'].toString());
      if (parsed != null) createdAtDate = parsed;
    }

    final payload = notification?.payload ??
        (notificationData?['payload'] != null ? Map<String, dynamic>.from(notificationData!['payload']) : null);

    final resolvedRoute = payload?['route'] as String? ?? _getRouteFromType(type);
    final showActionBtn = resolvedRoute != null && resolvedRoute.isNotEmpty;

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          CustomScrollView(
            slivers: [
              CustomAppBar(
                title: 'Notification Details',
                subtitle: 'View more information about this alert.',
                isLeading: true,
                centerTitle: true,
              ),
              SliverPadding(
                padding: const EdgeInsets.all(24.0),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E1E2E).withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.grey.shade200,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Category Badge & Icon
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _getTypeColor(type).withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _getTypeIcon(type),
                                  color: _getTypeColor(type),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getTypeLabel(type),
                                    style: GoogleFonts.plusJakartaSans(
                                      color: _getTypeColor(type),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('dd MMM yyyy • hh:mm a').format(createdAtDate),
                                    style: GoogleFonts.plusJakartaSans(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Notification Title
                          Text(
                            title,
                            style: GoogleFonts.outfit(
                              color: theme.colorScheme.onSurface,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Divider
                          Divider(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.grey.shade200,
                            thickness: 1.2,
                          ),
                          const SizedBox(height: 16),

                          RichTextLinkRenderer(
                            text: body,
                            style: GoogleFonts.plusJakartaSans(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                              fontSize: 14.5,
                              height: 1.6,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Call to Action Button if there is a target route
                          if (showActionBtn) ...[
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () {
                                  // Navigate to target route
                                  Navigator.pushNamed(
                                    context,
                                    resolvedRoute,
                                    arguments: payload,
                                  );
                                },
                                icon: Icon(_getActionIcon(type), size: 18),
                                label: Text(
                                  _getActionLabel(type),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
            ],
          ),
        ],
      ),
    );
  }

  // --- Helper Methods ---

  String? _getRouteFromType(String type) {
    switch (type) {
      case 'payment':
      case 'payment_rejected':
        return AppRoutes.purchase;
      case 'payment_approved':
        return AppRoutes.unlock;
      case 'content_update':
        return AppRoutes.mainShell;
      case 'result':
        return AppRoutes.utmeHistory;
      case 'education_news':
        return AppRoutes.news;
      default:
        return null;
    }
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
      case 'education_news':
        return Icons.newspaper_rounded;
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
      case 'education_news':
        return Colors.deepPurple;
      default:
        return AppColors.primary;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'payment':
        return 'PAYMENT INITIATED';
      case 'payment_approved':
        return 'PAYMENT APPROVED';
      case 'payment_rejected':
        return 'PAYMENT DECLINED';
      case 'exam_unlock':
        return 'EXAM UNLOCKED';
      case 'result':
        return 'EXAM RESULT';
      case 'reminder':
        return 'STUDY REMINDER';
      case 'content_update':
        return 'CONTENT UPDATE';
      case 'broadcast':
        return 'ANNOUNCEMENT';
      case 'system_update':
        return 'SYSTEM UPDATE';
      case 'education_news':
        return 'EDUCATION NEWS';
      default:
        return 'NOTIFICATION';
    }
  }

  IconData _getActionIcon(String type) {
    switch (type) {
      case 'payment':
      case 'payment_rejected':
        return Icons.receipt_long_rounded;
      case 'payment_approved':
        return Icons.vpn_key_rounded;
      case 'result':
        return Icons.assessment_rounded;
      case 'education_news':
        return Icons.chrome_reader_mode_rounded;
      case 'broadcast':
        return Icons.campaign_rounded;
      default:
        return Icons.arrow_forward_rounded;
    }
  }

  String _getActionLabel(String type) {
    switch (type) {
      case 'payment':
      case 'payment_rejected':
        return 'View Purchase History';
      case 'payment_approved':
        return 'Proceed to Unlock';
      case 'result':
        return 'View Exam History';
      case 'content_update':
        return 'Go to Home';
      case 'education_news':
        return 'Read News Article';
      case 'broadcast':
        return 'View Announcements';
      default:
        return 'Proceed to Feature';
    }
  }
}

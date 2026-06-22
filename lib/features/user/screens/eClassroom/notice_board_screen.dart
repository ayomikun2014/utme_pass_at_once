import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:utme_pass_at_once/core/utils/custom_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/bg.dart';
import '../../models/eclassroom_models.dart';
import '../../services/eclassroom_service.dart';
import '../../../../core/services/network_service.dart';
import '../../../../core/utils/custom_toast.dart';

class NoticeBoardScreen extends StatefulWidget {
  final String adminId;
  const NoticeBoardScreen({super.key, required this.adminId});

  @override
  State<NoticeBoardScreen> createState() => _NoticeBoardScreenState();
}

class _NoticeBoardScreenState extends State<NoticeBoardScreen> {
  final EClassroomService _classroomService = EClassroomService();
  Set<String> _readNoticeIds = {};
  StreamSubscription<List<Notice>>? _noticeSubscription;
  List<Notice> _allNotices = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReadNotices();
    _initializeData();
  }

  void _initializeData() async {
    await _loadCachedNotices();
    _listenToNotices();
  }

  Future<void> _loadCachedNotices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString('cached_classroom_notices_${widget.adminId}');
      if (jsonStr != null) {
        final List decoded = jsonDecode(jsonStr);
        setState(() {
          _allNotices = decoded.map((e) => Notice.fromMap(Map<String, dynamic>.from(e))).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading cached notices: $e');
    }
  }

  Future<void> _saveCachedNotices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_allNotices.map((e) => e.toMap()).toList());
      await prefs.setString('cached_classroom_notices_${widget.adminId}', jsonStr);
    } catch (e) {
      debugPrint('Error saving cached notices: $e');
    }
  }

  void _listenToNotices() {
    _noticeSubscription?.cancel();
    _noticeSubscription = _classroomService.streamNotices(widget.adminId).listen((notices) async {
      if (mounted) {
        setState(() {
          _allNotices = notices;
          _isLoading = false;
          _errorMessage = null;
        });
        await _saveCachedNotices();
      }
    }, onError: (err) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_allNotices.isEmpty) {
            _errorMessage = err.toString();
          }
        });
      }
    });
  }

  void _loadReadNotices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _readNoticeIds = (prefs.getStringList('read_notice_ids') ?? []).toSet();
      });
    } catch (e) {
      debugPrint('Error loading read notice status: $e');
    }
  }

  void _markAsRead(String noticeId) async {
    if (!_readNoticeIds.contains(noticeId)) {
      try {
        final prefs = await SharedPreferences.getInstance();
        setState(() {
          _readNoticeIds.add(noticeId);
        });
        await prefs.setStringList('read_notice_ids', _readNoticeIds.toList());
      } catch (e) {
        debugPrint('Error marking notice as read: $e');
      }
    }
  }

  Future<void> _refreshData() async {
    final isOnline = NetworkService.instance.isOnline;
    if (!isOnline) {
      if (mounted) {
        CustomToast.show(context, 'No internet connection. Failed to refresh.', isError: true);
      }
      return;
    }
    _listenToNotices();
  }

  @override
  void dispose() {
    _noticeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  title: const Text(
                    'Notice Board',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.white),
                  pinned: true,
                  floating: true,
                  forceElevated: innerBoxIsScrolled,
                ),
              ];
            },
            body: RefreshIndicator(
              onRefresh: _refreshData,
              color: AppColors.primary,
              child: _isLoading
                  ? const Center(child: CustomLoader())
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: Colors.redAccent,
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Failed to load notices',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _allNotices.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.notifications_off_rounded,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No notices yet from your center',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              itemCount: _allNotices.length,
                              itemBuilder: (context, index) {
                                final notice = _allNotices[index];
                                final isUnread = !_readNoticeIds.contains(notice.id);
                                final enrichedNotice = Notice(
                                  id: notice.id,
                                  title: notice.title,
                                  message: notice.message,
                                  timestamp: notice.timestamp,
                                  isUnread: isUnread,
                                  isPinned: notice.isPinned,
                                );

                                return _buildNoticeCard(context, enrichedNotice, isDark);
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeCard(BuildContext context, Notice notice, bool isDark) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => _markAsRead(notice.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: notice.isUnread
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  notice.isUnread
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  color:
                      notice.isUnread ? AppColors.primary : Colors.grey.shade600,
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
                          _formatTimeAgo(notice.timestamp),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (notice.isPinned)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.push_pin_rounded,
                              size: 12,
                              color: Colors.amber.shade700,
                            ),
                          ),
                        if (notice.isUnread)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notice.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: notice.isUnread
                            ? FontWeight.bold
                            : FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notice.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(
              color: isDark ? AppColors.dividerDark : Colors.grey.shade200,
              height: 1,
              thickness: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inDays > 8) {
      return DateFormat('MMM dd, yyyy').format(timestamp);
    } else if ((difference.inDays / 7).floor() >= 1) {
      return '1 week ago';
    } else if (difference.inDays >= 2) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays >= 1) {
      return '1 day ago';
    } else if (difference.inHours >= 2) {
      return '${difference.inHours} hours ago';
    } else if (difference.inHours >= 1) {
      return '1 hour ago';
    } else if (difference.inMinutes >= 2) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inMinutes >= 1) {
      return '1 minute ago';
    } else {
      return 'Just now';
    }
  }
}

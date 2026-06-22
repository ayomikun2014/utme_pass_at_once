import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:utme_pass_at_once/core/utils/custom_loader.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/bg.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/eclassroom_models.dart';
import '../../services/eclassroom_service.dart';
import '../../../../core/utils/custom_toast.dart';
import '../../../../core/services/network_service.dart';

class CenterLeaderboardScreen extends StatefulWidget {
  final String adminId;
  const CenterLeaderboardScreen({super.key, required this.adminId});

  @override
  State<CenterLeaderboardScreen> createState() => _CenterLeaderboardScreenState();
}

class _CenterLeaderboardScreenState extends State<CenterLeaderboardScreen> {
  final EClassroomService _classroomService = EClassroomService();
  bool _isLoading = true;
  List<LeaderboardEntry> _leaderboard = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() async {
    await _loadCachedLeaderboard();
    _loadData();
  }

  Future<void> _loadCachedLeaderboard() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString('cached_classroom_leaderboard_${widget.adminId}');
      if (jsonStr != null) {
        final List decoded = jsonDecode(jsonStr);
        setState(() {
          _leaderboard = decoded.map((e) => LeaderboardEntry.fromMap(Map<String, dynamic>.from(e))).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading cached leaderboard: $e');
    }
  }

  Future<void> _saveCachedLeaderboard() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_leaderboard.map((e) => e.toMap()).toList());
      await prefs.setString('cached_classroom_leaderboard_${widget.adminId}', jsonStr);
    } catch (e) {
      debugPrint('Error saving cached leaderboard: $e');
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
    _loadData();
  }

  void _loadData() async {
    try {
      final isOnline = NetworkService.instance.isOnline;
      if (!isOnline && _leaderboard.isNotEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final currentUserId = context.read<AuthProvider>().currentUser?.uid ?? '';
      final leaderboard = await _classroomService.getClassroomLeaderboard(
        widget.adminId,
        currentUserId,
      );

      if (mounted) {
        setState(() {
          _leaderboard = leaderboard;
          _isLoading = false;
          _errorMessage = null;
        });
        await _saveCachedLeaderboard();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_leaderboard.isEmpty) {
            _errorMessage = e.toString();
          }
        });
      }
    }
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
                    'Leaderboard',
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
                  ? const CustomLoader()
                  : _errorMessage != null
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Failed to load leaderboard',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isLoading = true;
                                        });
                                        _loadData();
                                      },
                                      child: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : _leaderboard.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey.shade400),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No peer rankings available yet',
                                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : CustomScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                // Top Three Podium
                                SliverToBoxAdapter(
                                  child: _buildTopThree(context, isDark),
                                ),
                                // All Rankings Header
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 8, left: 24, right: 24, bottom: 16),
                                    child: Row(
                                      children: [
                                        Text(
                                          'All Rankings',
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${_leaderboard.length} Students',
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Leaderboard List
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final entry = _leaderboard[index + 3];
                                        return _buildLeaderboardTile(context, entry, isDark);
                                      },
                                      childCount: _leaderboard.length > 3 ? _leaderboard.length - 3 : 0,
                                    ),
                                  ),
                                ),
                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 40),
                                ),
                              ],
                            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopThree(BuildContext context, bool isDark) {
    if (_leaderboard.isEmpty) return const SizedBox.shrink();

    // Find the entries safely
    final first = _leaderboard.isNotEmpty ? _leaderboard[0] : null;
    final second = _leaderboard.length > 1 ? _leaderboard[1] : null;
    final third = _leaderboard.length > 2 ? _leaderboard[2] : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark 
            ? AppColors.surfaceDark.withValues(alpha: 0.5) 
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd Place (Left)
          if (second != null)
            Expanded(
              child: _buildPodiumItem(
                context: context,
                entry: second,
                rank: 2,
                avatarSize: 28,
                podiumHeight: 75,
                podiumColor: Colors.grey.shade400,
                isDark: isDark,
              ),
            )
          else
            const Expanded(child: SizedBox.shrink()),

          const SizedBox(width: 8),

          // 1st Place (Center)
          if (first != null)
            Expanded(
              child: _buildPodiumItem(
                context: context,
                entry: first,
                rank: 1,
                avatarSize: 36,
                podiumHeight: 100,
                podiumColor: const Color(0xFFFFD700), // Gold
                isDark: isDark,
              ),
            )
          else
            const Expanded(child: SizedBox.shrink()),

          const SizedBox(width: 8),

          // 3rd Place (Right)
          if (third != null)
            Expanded(
              child: _buildPodiumItem(
                context: context,
                entry: third,
                rank: 3,
                avatarSize: 24,
                podiumHeight: 60,
                podiumColor: const Color(0xFFCD7F32), // Bronze
                isDark: isDark,
              ),
            )
          else
            const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _buildPodiumItem({
    required BuildContext context,
    required LeaderboardEntry entry,
    required int rank,
    required double avatarSize,
    required double podiumHeight,
    required Color podiumColor,
    required bool isDark,
  }) {
    final displayScore = '${entry.totalScore}%';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown/Badge for 1st place
        if (rank == 1)
          const Icon(
            Icons.workspace_premium_rounded,
            color: Color(0xFFFFD700),
            size: 28,
          )
        else
          const SizedBox(height: 28),

        const SizedBox(height: 6),

        // Avatar
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: entry.isCurrentUser ? AppColors.primary : podiumColor,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: podiumColor.withValues(alpha: 0.25),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: CircleAvatar(
                radius: avatarSize,
                backgroundColor: isDark ? AppColors.surfaceDark : Colors.grey.shade200,
                backgroundImage: entry.avatarUrl.isNotEmpty ? NetworkImage(entry.avatarUrl) : null,
                child: entry.avatarUrl.isEmpty
                    ? Icon(Icons.person, size: avatarSize, color: Colors.grey)
                    : null,
              ),
            ),
            // Floating Rank Circular Badge
            Positioned(
              bottom: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: podiumColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: isDark ? AppColors.surfaceDark : Colors.white, width: 1.5),
                ),
                child: Text(
                  rank.toString(),
                  style: TextStyle(
                    color: rank == 1 ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 9,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Name
        Text(
          entry.name.split(' ').first,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),

        // Score
        Text(
          displayScore,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${entry.testsTaken} tests',
          style: TextStyle(
            color: isDark ? Colors.white54 : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),

        const SizedBox(height: 10),

        // Podium Pillar (Sleek Glassmorphic Bar)
        Container(
          height: podiumHeight,
          width: 55,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                podiumColor.withValues(alpha: 0.35),
                podiumColor.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(
              color: podiumColor.withValues(alpha: 0.25),
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '#$rank',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardTile(BuildContext context, LeaderboardEntry entry, bool isDark) {
    final isCurrent = entry.isCurrentUser;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCurrent 
            ? AppColors.primary.withValues(alpha: 0.08) 
            : (isDark ? AppColors.surfaceDark.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent 
              ? AppColors.primary.withValues(alpha: 0.25) 
              : (isDark ? AppColors.dividerDark : Colors.grey.shade200),
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '#${entry.rank}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: isCurrent ? AppColors.primary : Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 18,
              backgroundColor: isDark ? AppColors.surfaceDark : Colors.grey.shade200,
              backgroundImage: entry.avatarUrl.isNotEmpty ? NetworkImage(entry.avatarUrl) : null,
              child: entry.avatarUrl.isEmpty
                  ? const Icon(Icons.person, size: 18, color: Colors.grey)
                  : null,
            ),
          ],
        ),
        title: Text(
          entry.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          '${entry.testsTaken} tests taken',
          style: TextStyle(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isCurrent 
                ? AppColors.primary.withValues(alpha: 0.15) 
                : (isDark ? Colors.grey.shade900 : Colors.grey.shade50),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${entry.totalScore}%',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isCurrent ? AppColors.primary : (isDark ? Colors.grey.shade300 : Colors.grey.shade800),
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

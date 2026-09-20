import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/custom_app_bar.dart';
import '../../../../core/utils/custom_loader.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../auth/models/user_model.dart';
import '../../utils/setting_card.dart';
import 'account/logout.dart';

class MyAccount extends StatelessWidget {
  const MyAccount({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch the AuthProvider to get live user data
    final authProvider = context.watch<AuthProvider>();
    final UserModel? user = authProvider.currentUser;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const CustomAppBar(
            title: 'My Account',
            subtitle: 'Manage your personal details and security.',
            isLeading: true,
            centerTitle: true,
          ),

          // --- THE NEW PROFILE HEADER WITH DYNAMIC AVATAR ---
          if (user != null) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                child: _buildProfileHeader(context, user),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildActiveSubscriptions(context, user),
            ),
          ],

          _buildMyAccountCard(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, dynamic user) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // --- DYNAMIC AVATAR LOGIC ---
    final List<String> educationAvatars = [
      'https://api.dicebear.com/8.x/notionists/png?seed=Study1&backgroundColor=e0f2fe',
      'https://api.dicebear.com/8.x/notionists/png?seed=Study2&backgroundColor=dbeafe',
      'https://api.dicebear.com/8.x/notionists/png?seed=Study3&backgroundColor=ede9fe',
      'https://api.dicebear.com/8.x/notionists/png?seed=Study4&backgroundColor=fce7f3',
      'https://api.dicebear.com/8.x/notionists/png?seed=Study5&backgroundColor=fef3c7',
    ];

    // Use the UID to pick exactly 1 of the 5 images permanently for this user
    final String uid = user.uid;
    final int avatarIndex = uid.hashCode.abs() % educationAvatars.length;
    final String avatarUrl = educationAvatars[avatarIndex];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppColors.surfaceDark, Colors.grey.shade900]
              : [Colors.white, theme.colorScheme.primaryContainer.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? AppColors.dividerDark
              : theme.colorScheme.primary.withValues(alpha: 0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.shade200.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // --- CACHED NETWORK IMAGE AVATAR (Glowing & Resized) ---
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.4),
                width: 2.5,
              ),
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: avatarUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                    child: SizedBox(
                        width: 20, height: 20,
                        child: CustomLoader(size: 20)
                    )
                ),
                errorWidget: (context, url, error) => const Icon(Icons.person_rounded, size: 30, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),

                // Dynamic Premium Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: user.isPremium
                        ? Colors.amber.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: user.isPremium
                          ? Colors.amber.withValues(alpha: 0.5)
                          : Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        user.isPremium ? Icons.workspace_premium : Icons.stars_rounded,
                        size: 14,
                        color: user.isPremium ? Colors.amber.shade700 : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        user.isPremium ? 'Premium Member' : 'Free Account',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: user.isPremium
                              ? (isDark ? Colors.amber.shade400 : Colors.amber.shade700)
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Edit Profile Action Button
          GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, '/profile');
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.dividerDark : Colors.grey.shade200,
                ),
              ),
              child: Icon(
                Icons.edit_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyAccountCard() {
    final List<Map<String, dynamic>> myAccountLists = [
      {
        'title': 'My Orders',
        'icon': Icons.receipt_long_rounded,
        'route': '/purchase',
      },
      {
        'title': 'Change Password',
        'icon': Icons.lock_rounded,
        'route': '/change_password',
      },
      {'title': 'Logout', 'icon': Icons.logout_rounded, 'route': '/logout'},
      {
        'title': 'Delete Account',
        'icon': Icons.no_accounts_rounded,
        'route': '/delete_account',
      },
    ];

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = myAccountLists[index];

          return buildSettingCard(
            context: context,
            title: item['title'],
            icon: item['icon'],
            route: item['route'] == '/logout' ? null : item['route'],
            onTap: item['route'] == '/logout'
                ? () {
              showDialog(
                context: context,
                barrierColor: Colors.black.withValues(alpha: 0.5),
                builder: (context) => const LogoutDialog(),
              );
            }
                : null,
          );
        }, childCount: myAccountLists.length),
      ),
    );
  }

  Widget _buildActiveSubscriptions(BuildContext context, UserModel user) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activePackages = user.getActivePackages();

    if (activePackages.isEmpty) {
      // Compact single-row activation tile for free users
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.dividerDark : Colors.grey.shade200,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.01),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.stars_rounded,
                  color: Colors.amber.shade700,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  'Activate Exam / Package',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/unlock');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Activate',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 12),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Collapsible active subscriptions dropdown for premium users
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? AppColors.dividerDark : Colors.grey.shade200,
        ),
      ),
      color: isDark ? AppColors.surfaceDark : theme.colorScheme.surface,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: Icon(
              Icons.menu_book_rounded,
              color: theme.colorScheme.primary,
            ),
            title: Text(
              'My Active Studies (${activePackages.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            children: activePackages.map((package) {
              final examType = package['examType'].toString().toUpperCase();
              final instId = package['institutionId'].toString().toUpperCase();
              final sectionName = package['sectionName']?.toString() ?? '';
              final expiresAt = package['expiresAt'] as DateTime?;
              final subjects = List<String>.from(package['subjects'] ?? []);

              String expiryText = 'Lifetime Access';
              if (expiresAt != null) {
                expiryText = 'Expires: ${expiresAt.day}/${expiresAt.month}/${expiresAt.year}';
              }

              String detailsText = '';
              if (examType.toLowerCase() != instId.toLowerCase()) {
                detailsText = instId;
              }
              if (sectionName.isNotEmpty) {
                if (detailsText.isNotEmpty) {
                  detailsText += ' ($sectionName)';
                } else {
                  detailsText = sectionName;
                }
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.workspace_premium_rounded,
                      color: Colors.amber.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                examType,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                expiryText,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          if (detailsText.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              detailsText,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (subjects.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Subjects: ${subjects.map((s) => s.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '').join(' ')).join(', ')}',
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey.shade500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
}
}

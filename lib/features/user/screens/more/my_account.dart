import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/custom_app_bar.dart';
import '../../../../core/utils/custom_loader.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../utils/setting_card.dart';
import 'account/logout.dart';

class MyAccount extends StatelessWidget {
  const MyAccount({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch the AuthProvider to get live user data
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

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
          if (user != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                child: _buildProfileHeader(context, user),
              ),
            ),

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
        color: isDark ? AppColors.surfaceDark : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : Colors.grey.shade200,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          // --- CACHED NETWORK IMAGE AVATAR ---
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 2),
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
                    fontSize: 18,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Dynamic Premium Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: user.isPremium
                        ? Colors.amber.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: user.isPremium
                          ? Colors.amber.withValues(alpha: 0.5)
                          : Colors.grey.withValues(alpha: 0.5),
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
        ],
      ),
    );
  }

  Widget _buildMyAccountCard() {
    final List<Map<String, dynamic>> myAccountLists = [
      {
        'title': 'Edit Profile', // Changed to Edit Profile
        'icon': Icons.manage_accounts_rounded,
        'route': '/profile',
      },
      {
        'title': 'My Purchases',
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
}
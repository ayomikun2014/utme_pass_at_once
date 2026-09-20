import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../features/user/providers/notification_provider.dart';
import '../services/tutorial_service.dart';

import 'back_arrow.dart';
import '../constants/app_colors.dart';

class CustomAppBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool? hasIcon;
  final String? route;
  final Color? color;
  final bool isLeading;
  final bool centerTitle;
  final VoidCallback? onLeadingPressed;
  final String? logoUrl;
  final List<Widget>? actions;
  final TextStyle? subtitleStyle;
  final VoidCallback? onTitlePressed;
  final bool hideTitleOnCollapse;

  const CustomAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.hasIcon = false,
    this.icon,
    this.route = '',
    this.color,
    this.isLeading = false,
    this.centerTitle = true, // Default to centered
    this.onLeadingPressed,
    this.logoUrl,
    this.actions,
    this.subtitleStyle,
    this.onTitlePressed,
    this.hideTitleOnCollapse = false,
  });

  @override
  Widget build(BuildContext context) {
    // Determine the height based on whether we need to make room for a back button
    final double expandedHeight = isLeading ? 130.0 : 100.0;
    final theme = Theme.of(context);

    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      floating: false,
      elevation: 0,
      scrolledUnderElevation: 4.0,
      expandedHeight: expandedHeight, // The full height when opened
      toolbarHeight:
          kToolbarHeight, // The standard height when collapsed (approx 56px)
      //LEADING ICON (Always stays pinned at the top left)
      leading: isLeading
          ? Center(
              child: backArrow(
                theme: theme,
                context: context,
                onPressed: onLeadingPressed,
              ),
            )
          : null,

      actions: [
        if (hasIcon == true && icon != null)
          Consumer<NotificationProvider>(
            builder: (context, notificationProvider, child) {
              final count = notificationProvider.unreadCount;
              Widget bellWidget = IconButton(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () {
                  if (route != null && route!.isNotEmpty) {
                    Navigator.pushNamed(context, route!);
                  }
                },
                icon: Icon(icon, color: Colors.grey, size: 24),
              );

              if (title.startsWith('Hello,')) {
                bellWidget = TutorialService.instance.buildShowcase(
                  key: TutorialService.instance.notificationKey,
                  icon: Icons.notifications_rounded,
                  accent: const Color(0xFFF59E0B),
                  title: 'Your alerts',
                  description: 'New activation codes, payment updates and announcements land here. The red dot means something is waiting for you.',
                  context: context,
                  isCircleBorder: true,
                  child: bellWidget,
                );
              }

              return Padding(
                padding: const EdgeInsets.only(right: 0),
                child: Badge.count(
                  count: count,
                  isLabelVisible: count > 0,
                  smallSize: 10,
                  backgroundColor: Colors.redAccent,
                  textColor: Colors.white,
                  offset: const Offset(-2, 2),
                  child: bellWidget,
                ),
              );
            },
          ),
        if (actions != null) ...actions!,
      ],

      //THE MAGIC: Detecting the scroll position
      flexibleSpace: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Check how tall the app bar currently is
          final top = constraints.biggest.height;
          // Calculate what the fully collapsed height is
          final collapsedHeight =
              MediaQuery.of(context).padding.top + kToolbarHeight;
          // If we are within 20 pixels of fully collapsed, trigger the animations
          final isCollapsed = top <= collapsedHeight + 20;

          return FlexibleSpaceBar(
            centerTitle:
                centerTitle, // Will center for Study/Test, left-align for Home
            // --- 3. COLLAPSED TITLE (Fades IN when scrolled UP) ---
            title: hideTitleOnCollapse ? null : AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isCollapsed ? 1.0 : 0.0,
              child: GestureDetector(
                onTap: onTitlePressed,
                child: Text(
                  title,
                  maxLines: 2,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.displayLarge?.color,
                  ),
                ),
              ),
            ),

            //EXPANDED CONTENT (Fades OUT when scrolled UP) ---
            background: SafeArea(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isCollapsed ? 0.0 : 1.0,
                child: Padding(
                  padding: EdgeInsets.only(
                    // Reduce top padding slightly for the smaller expandedHeight
                    top: isLeading ? 40.0 : 5.0,
                    left: 24.0,
                    right: 24.0,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: onTitlePressed,
                          child: Builder(
                            builder: (context) {
                              Widget titleWidget = Text(
                                title,
                                style: GoogleFonts.outfit(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: theme.textTheme.displayLarge?.color,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );

                              if (title.startsWith('Hello,')) {
                                titleWidget = TutorialService.instance.buildShowcase(
                                  key: TutorialService.instance.welcomeKey,
                                  icon: Icons.person_rounded,
                                  accent: AppColors.primary,
                                  title: 'Welcome to Pass At Once',
                                  description: 'This is your home. Tap your name at any time to open your profile, orders and account settings.',
                                  context: context,
                                  child: titleWidget,
                                );
                              }

                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  titleWidget,
                                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      subtitle!,
                                      style: subtitleStyle ?? 
                                          GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                                            fontWeight: FontWeight.w600,
                                          ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              );
                            }
                          ),
                        ),
                      ),
                      if (logoUrl != null && logoUrl!.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: logoUrl!.startsWith('assets/')
                                ? Image.asset(logoUrl!, fit: BoxFit.cover)
                                : CachedNetworkImage(
                                    imageUrl: logoUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        const SizedBox.shrink(),
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.school, color: Colors.white, size: 24),
                                  ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

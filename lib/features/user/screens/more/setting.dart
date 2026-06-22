import 'package:flutter/material.dart';
import '../../../../core/utils/custom_app_bar.dart';
import '../../utils/setting_card.dart';
import '../../../../core/services/tutorial_service.dart';

class AppSetting extends StatelessWidget {
  const AppSetting({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          CustomAppBar(
            title: 'Settings',
            subtitle: 'Customize your app preferences.',
            isLeading: true,
            centerTitle: true,
          ),
          _buildSettingList(context),
        ],
      ),
    );
  }

  Widget _buildSettingList(BuildContext context) {
    final List<Map<String, dynamic>> mySettingsList = [
      // --- PREFERENCES ---
      {
        'title': 'Replay Tour',
        'icon': Icons.play_circle_outline_rounded,
        'onTap': () {
          Navigator.of(context).popUntil((route) => route.isFirst || route.settings.name == '/main-shell');
          TutorialService.instance.startTutorial(context, force: true);
        },
      },
      {
        'title': 'Update',
        'icon': Icons.update, // Or Icons.dark_mode if you prefer
        'route': '/update',
      }, {
        'title': 'Appearance',
        'icon': Icons.palette_rounded, // Or Icons.dark_mode if you prefer
        'route': '/appearance',
      },
      {
        'title': 'Notifications',
        'icon': Icons.notifications_rounded,
        'route': '/notification',
      },

      // --- SUPPORT ---
      {
        'title': 'Help & FAQ',
        'icon': Icons.quiz_rounded,
        'route': '/help',
      },
      {
        'title': 'Contact Us',
        'icon': Icons.chat_rounded, // Represents chat/support
        'route': '/contact',
      },

      // --- GROWTH & INFO ---
      {
        'title': 'Share App',
        'icon': Icons.share_rounded, // Crucial for getting more student downloads!
        'route': '/share',
      },
      {'title': 'Rate App', 'icon': Icons.star_rounded, 'route': '/rate'},
      {'title': 'About App', 'icon': Icons.info_rounded, 'route': '/about'},
    ];
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = mySettingsList[index];
          return buildSettingCard(
            context: context,
            title: item['title'],
            icon: item['icon'],
            route: item['route'],
            onTap: item['onTap'],
          );
        }, childCount: mySettingsList.length),
      ),
    );
  }
}

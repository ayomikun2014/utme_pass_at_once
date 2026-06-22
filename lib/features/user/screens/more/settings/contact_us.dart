import 'package:utme_pass_at_once/core/utils/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:utme_pass_at_once/core/utils/custom_loader.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/utils/bg.dart';
import '../../../../../core/utils/contact_helper.dart';
import '../../../../../core/utils/custom_app_bar.dart';
import '../../../../../core/providers/settings_provider.dart';
import '../../../../../core/models/app_settings_model.dart';

class ContactUs extends StatelessWidget {
  const ContactUs({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final settingsProvider = context.watch<SettingsProvider>();

    final hasWhatsapp = settingsProvider.whatsappNumber.trim().isNotEmpty;
    final hasEmail = settingsProvider.contactEmail.trim().isNotEmpty;
    final hasPhones = settingsProvider.supportPhones.isNotEmpty;

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          CustomScrollView(
            slivers: [
              CustomAppBar(
                title: 'Contact Us',
                subtitle: 'Get in touch with our support team for help.',
                color: AppColors.primary,
                isLeading: true,
                centerTitle: true,
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),

                      if (settingsProvider.isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: CustomLoader(),
                        ),

                      if (!settingsProvider.isLoading && hasWhatsapp)
                        _buildActionCard(
                          context: context,
                          title: 'Chat on WhatsApp',
                          subtitle: 'Fastest way to get a reply.',
                          icon: Icons.chat_rounded,
                          backgroundColor: Colors.green.withValues(
                            alpha: isDark ? 0.2 : 0.1,
                          ),
                          iconColor: Colors.green,
                          onTap: () async {
                            await _safeLaunch(
                              context,
                              () => ContactHelper.openWhatsApp(
                                settingsProvider.whatsappNumber,
                                'Hi support team, I need help with this app',
                              ),
                              failureMessage:
                                  'Unable to open WhatsApp on this device.',
                            );
                          },
                        ),

                      if (!settingsProvider.isLoading && hasWhatsapp)
                        const SizedBox(height: 12),

                      if (!settingsProvider.isLoading && hasEmail)
                        _buildActionCard(
                          context: context,
                          title: 'Send an email',
                          subtitle:
                              'Open your email app to contact support directly.',
                          icon: Icons.mail_rounded,
                          backgroundColor: AppColors.primary.withValues(
                            alpha: isDark ? 0.2 : 0.1,
                          ),
                          iconColor: AppColors.primary,
                          onTap: () async {
                            await _safeLaunch(
                              context,
                              () => ContactHelper.openEmail(
                                settingsProvider.contactEmail,
                              ),
                              failureMessage:
                                  'Unable to open email app on this device.',
                            );
                          },
                        ),

                      if (!settingsProvider.isLoading && hasPhones) ...[
                        const SizedBox(height: 32),
                        const Text(
                          'Give us a call',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'This option is useful for payment, activation, or service related issues.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ...settingsProvider.supportPhones.map(
                          (phone) => _buildPhoneRow(context, phone),
                        ),
                      ],

                      if (!settingsProvider.isLoading &&
                          !hasWhatsapp &&
                          !hasEmail &&
                          !hasPhones)
                        _buildEmptyContactState(context, settingsProvider),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyContactState(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.info_rounded,
            size: 48,
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No contact details yet',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Support contact details will appear here once the admin adds them.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: settingsProvider.refresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Sync Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _safeLaunch(
    BuildContext context,
    Future<void> Function() action, {
    required String failureMessage,
  }) async {
    try {
      await action();
    } catch (e) {
      if (!context.mounted) return;
      CustomToast.show(context, failureMessage, isError: true);
      debugPrint('Contact launch error: $e');
    }
  }

  Widget _buildActionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color backgroundColor,
    required Color iconColor,
    required Future<void> Function() onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: iconColor.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async => onTap(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: iconColor,
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneRow(BuildContext context, PhoneDetail phone) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final actionColor = AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: phone.isPrimary
              ? AppColors.primary.withValues(alpha: 0.3)
              : theme.colorScheme.onSurface.withValues(alpha: 0.05),
        ),
        boxShadow: [
          if (phone.isPrimary)
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (phone.isPrimary ? AppColors.primary : Colors.grey)
                  .withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              phone.isPrimary ? Icons.star_rounded : Icons.phone_rounded,
              color: phone.isPrimary ? AppColors.primary : Colors.grey,
              size: 20,
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
                      phone.label.isNotEmpty ? phone.label : 'Support Hotline',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: phone.isPrimary
                            ? AppColors.primary
                            : Colors.grey,
                      ),
                    ),
                    if (phone.isPrimary) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'PRIMARY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  phone.phoneNumber,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              await _safeLaunch(
                context,
                () => ContactHelper.openDialer(phone.phoneNumber),
                failureMessage: 'Unable to open phone dialer.',
              );
            },
            icon: Icon(Icons.phone_rounded, color: actionColor, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: actionColor.withValues(alpha: 0.1),
              padding: const EdgeInsets.all(10),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: phone.phoneNumber));
              if (!context.mounted) return;
              CustomToast.show(context, '${phone.phoneNumber} copied!');
            },
            icon: Icon(Icons.copy_rounded, color: actionColor, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: actionColor.withValues(alpha: 0.1),
              padding: const EdgeInsets.all(10),
            ),
          ),
        ],
      ),
    );
  }
}

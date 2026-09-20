import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  Future<void> _launchOnlinePolicy(BuildContext context) async {
    final Uri url = Uri.parse(
      'https://darttesting572-sys.github.io/pass-at-once-legal/privacy.html',
    );
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not open the link. Please check your web browser.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening link: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Interactive Link Button at the top
            Container(
              margin: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          AppColors.primary.withValues(alpha: 0.15),
                          AppColors.accent.withValues(alpha: 0.05),
                        ]
                      : [
                          theme.colorScheme.primary.withValues(alpha: 0.08),
                          theme.colorScheme.primary.withValues(alpha: 0.02),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.language_rounded,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Official Document hosted online',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Open Play Store Copy',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _launchOnlinePolicy(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.open_in_new_rounded, size: 14),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Privacy Policy for PASS AT ONCE CBT',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.05,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Effective Date: May 22, 2026',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Funtech Programming Consultants ("we," "us," or "our") operates the PASS AT ONCE CBT mobile application ("the Application"). We are committed to protecting your privacy. This Privacy Policy describes how we collect, use, store, disclose, and safeguard your information when you use our Application, in full compliance with the Google Play Developer Distribution Agreement and Play Console Program Policies.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.6,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'By downloading, installing, or using the Application, you agree to the collection and use of information in accordance with this Privacy Policy. If you do not agree with any terms of this policy, please do not use the Application.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.6,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    _buildSection(
                      theme: theme,
                      title: '1. Information We Collect',
                      content:
                          'To provide a premium educational experience, facilitate exam practice, and synchronize study progress, we collect certain personal and non-personal data.\n\n'
                          '• Account Registration Information: When you create an account, we collect your Full Name, Email Address, and Phone Number.\n'
                          '• Profile Management Data: Any optional profile picture or customization selections you choose within the profile editor.\n'
                          '• Support Interactions: Information you provide when contacting customer support (e.g., payment references, screenshots of issues, and communication logs).\n\n'
                          '• CBT Test Records: Subject selections, correct/wrong/skipped questions, scores achieved, time taken per exam, and test-taking history (used to compile your Performance Analytics dashboard).\n'
                          '• eClassroom Progress: Submissions for school assignments, study note views, and notifications fetched from center/sub-admin notices.\n'
                          '• Bookmarks & Custom Study Material: Questions you save or flag for later review.\n\n'
                          '• Device and Log Data: When you use the Application, we may collect technical data transmitted by your device, including device model, operating system version, unique device identifiers, and application performance analytics.',
                    ),

                    _buildSection(
                      theme: theme,
                      title: '2. How We Use Your Information',
                      content:
                          'We use the collected information for the following legitimate business and educational purposes:\n'
                          '• Account Provision & Sync: To register your user account, authorize login sessions, and securely synchronize your study progress, history, and notes across multiple devices.\n'
                          '• Performance Analysis: To compute statistics on your practice tests and display insights into weak/strong subject areas.\n'
                          '• Facilitate Payments & Activations: To process premium package upgrades, verify bank transfers, and generate activation vouchers.\n'
                          '• eClassroom Integrations: To link you to your specified study center/sub-admin, enabling assignment grading and class notice boards.\n'
                          '• Notifications: To send high-priority push notifications regarding exam reminders, classroom notices, or app updates (you can opt-out via system settings).\n'
                          '• Security & Integrity: To detect, prevent, and address technical issues, illegal license sharing, or unauthorized access to our premium database.',
                    ),

                    _buildSection(
                      theme: theme,
                      title: '3. Third-Party Services We Use',
                      content:
                          'The Application integrates third-party Software Development Kits (SDKs) and cloud services that collect and process data in accordance with their respective privacy policies. We disclose the following third-party integrations:\n\n'
                          '• Google Play Services: Used for app delivery, updates, and core system services.\n'
                          '• Firebase Authentication & Cloud Firestore (Google Firebase): Used for secure account creation, user authentication, and real-time syncing of study data.\n'
                          '• Paystack: Used as our secure payment gateway to process premium subscription checkouts.\n\n'
                          'We do not sell, trade, or rent your personal information to third-party marketing companies.',
                    ),

                    _buildSection(
                      theme: theme,
                      title: '4. Google Play Account and Data Deletion Policy',
                      content:
                          'In compliance with Google Play\'s Account Deletion Policy, we provide users with simple, transparent methods to delete their accounts and all associated data.\n\n'
                          'How to Delete Your Account and Data:\n'
                          '1. In-App Deletion: Open the Application, navigate to Settings, select "My Account / Profile", tap on "Delete Account" and confirm. Your data will be erased recursively from our active databases immediately.\n'
                          '2. Web/Email Request: You may request deletion by emailing our support team at taiwoprints999@gmail.com with the subject line "Request for Account Deletion". Please provide your registered email address.\n\n'
                          'What Happens Upon Deletion:\n'
                          '• Your user profile, registered name, email address, phone number, performance analytics, eClassroom logs, and purchase records will be permanently erased from our active Firebase databases within 7 business days.\n'
                          '• Any backups or audit logs will be overwritten or securely anonymized. Once completed, this action is irreversible, and your premium subscription cannot be recovered.',
                    ),

                    _buildSection(
                      theme: theme,
                      title: '5. Security of Your Data',
                      content:
                          'We implement administrative, physical, and industry-standard electronic security measures (such as SSL encryption and Firebase Security Rules) designed to protect your personal information from unauthorized access, loss, or alteration. However, please note that no method of transmission over the Internet or method of electronic storage is 100% secure, and we cannot guarantee absolute security.',
                    ),

                    _buildSection(
                      theme: theme,
                      title: '6. Children\'s Privacy',
                      content:
                          'The Application is designed as a study support platform for students preparing for WAEC, NECO, JAMB, and Post-UTME examinations. It is intended for users who are typically 13 years of age or older. We do not knowingly collect personally identifiable information from children under 13. If we discover that a child under 13 has provided us with personal information, we will immediately delete this data from our servers. If you are a parent or guardian and you are aware that your child has provided us with personal information, please contact us.',
                    ),

                    _buildSection(
                      theme: theme,
                      title: '7. Changes to This Privacy Policy',
                      content:
                          'We may update our Privacy Policy from time to time to adapt to changes in Google Play policies, security guidelines, or Application features. We will notify you of any changes by posting the new Privacy Policy within the Application\'s settings screen and updating the "Last Updated" date at the top of this document.',
                    ),

                    _buildSection(
                      theme: theme,
                      title: '8. Contact Us',
                      content:
                          'If you have any questions, suggestions, or concerns regarding this Privacy Policy, your personal data, or data deletion, please contact us:\n\n'
                          '• Developer Team: Funtech Programming Consultants\n'
                          '• Support Email: taiwoprints999@gmail.com',
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        '© 2026 PASS AT ONCE CBT Support',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required ThemeData theme,
    required String title,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.6,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

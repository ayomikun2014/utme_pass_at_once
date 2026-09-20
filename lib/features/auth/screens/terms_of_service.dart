import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  Future<void> _launchOnlineTerms(BuildContext context) async {
    final Uri url = Uri.parse(
      'https://darttesting572-sys.github.io/pass-at-once-legal/terms.html',
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
          'Terms of Service',
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
                      Icons.gavel_rounded,
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
                          'Official Agreement hosted online',
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
                    onPressed: () => _launchOnlineTerms(context),
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
                      'Terms of Service for PASS AT ONCE CBT',
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
                      'Welcome to PASS AT ONCE CBT ("the Application"), developed by Funtech Programming Consultants ("we," "us," or "our"). These Terms of Service ("Terms") govern your access to and use of our Application and related educational services.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.6,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Please read these Terms carefully before using the Application. By creating an account, logging in, making a payment, or using any feature, you represent that you are at least 13 years of age and agree to be bound by these Terms. If you do not agree to all of these Terms, please do not download, install, or use the Application.',
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
                      title: '1. Description of Service',
                      content:
                          'PASS AT ONCE CBT is a mobile educational simulator and classroom portal designed to assist candidates in preparing for major Nigerian exams, including the Unified Tertiary Matriculation Examination (UTME/JAMB), WAEC, NECO, and various Post-UTME tests. Features include:\n'
                          '• Full Computer-Based Test (CBT) simulations (timed exams, subject selections).\n'
                          '• Academic performance analysis and question bookmark review.\n'
                          '• Interactive AI-based academic support tutoring.\n'
                          '• E-Classroom connection linking students to school centers, sub-admins, live notices, and homework assignments.',
                    ),

                    _buildSection(
                      theme: theme,
                      title: '2. User Registration and Account Security',
                      content:
                          'To access most features of the Application, you must register and create a user account.\n'
                          '• Accuracy: You agree to provide accurate, current, and complete registration information (Name, Email, and Phone Number) and to update this information immediately in case of changes.\n'
                          '• Security: You are solely responsible for maintaining the confidentiality of your account credentials (email and password). You agree to immediately notify us at taiwoprints999@gmail.com of any unauthorized access or breach of security.\n'
                          '• Liability: We are not liable for any loss or damage arising from your failure to safeguard your login details.',
                    ),

                    _buildSection(
                      theme: theme,
                      title: '3. License Grant & Restrictions',
                      content:
                          'Subject to your compliance with these Terms, we grant you a limited, non-exclusive, non-transferable, revocable license to download, install, and use the Application on a personal mobile device solely for your non-commercial, personal study purposes.\n\n'
                          'Prohibited Actions:\n'
                          'You explicitly agree NOT to:\n'
                          '1. Copy, modify, translate, adapt, merge, or create derivative works of the Application\'s questions, database, study notes, or source code.\n'
                          '2. Reverse engineer, decompile, disassemble, or attempt to extract the source code or local database content.\n'
                          '3. Access, scrape, or extract question banks or answers using automated scripts, bots, spiders, or bypass tools.\n'
                          '4. Share your premium account credentials or license vouchers with other users to enable parallel multi-device usage.\n'
                          '5. Use the Application for any commercial training, cyber café exam practice, or unauthorized tutoring center distribution without obtaining a commercial license from us.\n\n'
                          'Any violation of this section immediately terminates your study license and may lead to database/account suspension and legal action.',
                    ),

                    _buildSection(
                      theme: theme,
                      title: '4. Premium Packages, Payments & Refund Policy',
                      content:
                          'Certain high-value study modules, full CBT database access, and eClassroom portal elements are classified as premium and require payment to activate.\n\n'
                          '• Pricing: Prices for activation bundles are specified within the in-app Store screen and are subject to change.\n'
                          '• Payments: Payment transactions are securely processed through our third-party checkout gateway (Paystack) or completed through manual bank transfer verification.\n'
                          '• Manual Bank Transfers: If you choose manual bank transfer, you must upload verifiable payment receipts or references within the transaction verification screen. Activation will take place upon administrative confirmation.\n'
                          '• Voucher Codes: Premium access can also be activated by entering valid printed voucher codes supplied by authorized centers or sub-admins.\n'
                          '• Refund Policy: Due to the instant delivery of digital educational licenses, all in-app purchases and voucher activations are non-refundable and non-exchangeable once premium features have been unlocked on your account, except in verified cases of technical failures where the bundle is not successfully provisioned.',
                    ),

                    _buildSection(
                      theme: theme,
                      title: '5. E-Classroom Interactions and Content',
                      content:
                          'If you use the Application to connect to an academic center or sub-admin classroom:\n'
                          '• Accountability: You are responsible for all answers, scores, and assignment submissions uploaded under your profile.\n'
                          '• Sub-Admin Authority: The linked sub-admin center has the authority to view your academic practice history, post notice board announcements, and assign CBT tests for grading purposes within the portal.\n'
                          '• Prohibited Content: You may not upload or submit any inappropriate, abusive, or copyright-infringing content through the classroom discussion or assignment submission flows.',
                    ),

                    _buildSection(
                      theme: theme,
                      title: '6. Disclaimer of Warranties',
                      content:
                          'The Application and all integrated study content, questions, answers, explanations, and AI tutor features are provided "AS IS" and "AS AVAILABLE" without any warranties of any kind, either express or implied.\n\n'
                          'While we strive to maintain the accuracy and educational validity of our question banks and performance statistics:\n'
                          '• We do not guarantee that the Application will be completely error-free, uninterrupted, or compatible with all operating systems.\n'
                          '• We make no warranties regarding the absolute correctness of every question\'s explanation, nor do we guarantee that practicing with this Application guarantees admission or a specific high score in the official JAMB/WAEC/NECO exams. Success is determined by continuous, diligent study.',
                    ),

                    _buildSection(
                      theme: theme,
                      title: '7. Limitation of Liability',
                      content:
                          'To the maximum extent permitted by applicable law, Funtech Programming Consultants and its developers, employees, or partners shall not be liable for any direct, indirect, incidental, special, exemplary, or consequential damages (including, but not limited to, loss of study data, device failure, academic setback, or financial loss) arising out of or related to your use of or inability to use the Application, even if advised of the possibility of such damages.',
                    ),

                    _buildSection(
                      theme: theme,
                      title: '8. Account Termination',
                      content:
                          'We reserve the right, in our sole discretion and without prior notice, to suspend, disable, or terminate your account and delete your data if we believe you have violated these Terms, engaged in security tampering, shared premium credentials, or compromised the platform\'s database.\n\n'
                          'Upon termination, your license to use the Application ceases immediately, and no refunds for active premium bundles will be granted.',
                    ),

                    _buildSection(
                      theme: theme,
                      title: '9. Governing Law',
                      content:
                          'These Terms are governed by and construed in accordance with the laws of the Federal Republic of Nigeria. You agree to submit to the exclusive jurisdiction of the courts located in Nigeria to resolve any dispute arising under these Terms.',
                    ),

                    _buildSection(
                      theme: theme,
                      title: '10. Contact Us',
                      content:
                          'For any clarification, questions, suggestions, or reports of security breaches related to these Terms, please contact us:\n\n'
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

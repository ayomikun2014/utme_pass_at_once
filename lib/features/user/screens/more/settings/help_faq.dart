import 'package:flutter/material.dart';
import 'package:utme_pass_at_once/core/constants/app_colors.dart';
import '../../../../../core/utils/bg.dart';
import '../../../../../core/utils/custom_app_bar.dart';
import '../../../../../core/utils/hero_card.dart';

class HelpAndFaq extends StatelessWidget {
  const HelpAndFaq({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          CustomScrollView(
            slivers: [
              const CustomAppBar(
                title: 'Help & FAQ',
                subtitle: 'Find quick answers and learn how the platform works.',
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
                      const HeroCard(
                        title: 'Need Assistance?',
                        subTitle:
                            'Browse common questions below or contact our support team for further help.',
                        icon: Icons.quiz_rounded,
                      ),
                      const SizedBox(height: 24),

                      _buildSectionLabel(context, 'Frequently Asked Questions'),
                      const SizedBox(height: 12),

                      _buildFaqTile(
                        context,
                        '1. How do I activate premium access?',
                        'To activate premium and unlock full access to our comprehensive question database, detailed solutions, and eClassroom portals:\n'
                            '• Open the side drawer menu or tab in the Application and tap "Activate / Buy More".\n'
                            '• Select your preferred exam bundle.\n'
                            '• Complete your payment securely via our automated gateway (Paystack) or choose the manual bank transfer option.\n'
                            '• If you paid via manual transfer, upload your transfer receipt screenshot inside the payment status screen. Once our admins verify your payment, your premium access is activated automatically.\n'
                            '• Alternatively, if your study center provided a printed voucher code, enter the code in the activation field to unlock your premium package instantly.',
                      ),

                      _buildFaqTile(
                        context,
                        '2. Why is my premium activation not reflecting?',
                        'In most cases, activations are instantaneous. If your purchase is not reflecting:\n'
                            '• Verify that the funds were debited and you received a successful transfer receipt or debit alert.\n'
                            '• Tap the Refresh button or close and relaunch the Application.\n'
                            '• Try signing out and signing back in to force a database refresh from the cloud servers.\n'
                            '• If the activation is still pending after 30 minutes, email your payment receipt/reference code to taiwoprints999@gmail.com for immediate manual resolution.',
                      ),

                      _buildFaqTile(
                        context,
                        '3. What happens if voucher generation fails after payment?',
                        'If a transaction completes successfully but the system encounters a network timeout before registering your premium voucher:\n'
                            '• Navigate to your Store screen to check the transaction logs. The system is designed to automatically retry failed voucher registrations once network connectivity is restored.\n'
                            '• If you do not see your activated subjects, contact our developer team at taiwoprints999@gmail.com with your Paystack reference or manual transfer receipt, and we will manually attach the premium license to your account.',
                      ),

                      _buildFaqTile(
                        context,
                        '4. Can I use the Application offline?',
                        'Yes! PASS AT ONCE CBT is designed for offline flexibility. Once you download your subjects, exam simulation databases, study notes, and syllabi can be fully accessed without an internet connection.\n'
                            '• Online Features: Creating an account, syncing scores/bookmarks, checking center notice boards, submitting assignments, upgrading packages, and utilizing the AI study tutor require active internet connectivity.',
                      ),

                      _buildFaqTile(
                        context,
                        '5. How does the CBT simulation work?',
                        'Our CBT engine is modeled after the actual computer-based testing format utilized by the Joint Admissions and Matriculation Board (JAMB/UTME).\n'
                            '• It features authentic timers, adjustable subject selections (pick up to 4 subjects matching your UTME combination), realistic question navigation, and automatic exam submission when the timer runs out.\n'
                            '• Upon completion, a majestic performance breakdown displays your score, correct/wrong/skipped totals, time analytics, and individual subject progress bars.',
                      ),

                      _buildFaqTile(
                        context,
                        '6. Is my study progress and personal data secure?',
                        'Absolutely. We implement robust Firebase Authentication protocols and secure Cloud Firestore security rules. Your personal details (name, email, phone number) are encrypted and protected against unauthorized data access. Additionally, our Premium database is fortified with secure access controls to safeguard copyrighted educational resources.',
                      ),

                      _buildFaqTile(
                        context,
                        '7. What is the PASS AT ONCE AI Tutor?',
                        'The AI Tutor is an advanced interactive learning assistant built directly into the exam review flow.\n'
                            '• If you struggle to understand why an answer is correct during exam reviews, you can tap "Ask AI" to get a comprehensive, detailed, step-by-step academic explanation of the question\'s concept.\n'
                            '• Note: This interactive feature utilizes cloud computing and requires active internet access.',
                      ),

                      _buildFaqTile(
                        context,
                        '8. Can I use my premium subscription on multiple devices?',
                        'Your premium study license is registered to your personal account. Under standard usage rules, parallel multi-device logins are monitored and may be restricted to prevent account sharing and license piracy. If your study center configuration allows multiple device sync, follow the guidelines provided by your administrator. If you experience device lockout after getting a new phone, contact taiwoprints999@gmail.com for assistance.',
                      ),

                      _buildFaqTile(
                        context,
                        '9. How do I delete my account and data?',
                        'In compliance with Google Play Store guidelines, we provide users with full control over their personal data.\n'
                            '• Navigate to Settings -> My Account / Profile -> Delete Account inside the Application.\n'
                            '• Alternatively, email a deletion request to taiwoprints999@gmail.com from your registered email address.\n'
                            '• Upon request, your profile, authentication data, exam history, eClassroom logs, and payment records will be permanently and irreversibly erased from our cloud servers within 7 business days.',
                      ),

                      const SizedBox(height: 24),

                      _buildSectionLabel(context, 'Support Information'),
                      const SizedBox(height: 12),

                      _buildSupportCard(context),

                      const SizedBox(height: 24),

                      Center(
                        child: Column(
                          children: [
                            Text(
                              'Developed by Funtech Programming Consultants',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.55,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
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

  Widget _buildSectionLabel(BuildContext context, String title) {
    final theme = Theme.of(context);

    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
      ),
    );
  }

  Widget _buildSupportCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.surfaceDark : theme.colorScheme.surface;
    final borderColor = isDark
        ? AppColors.dividerDark
        : theme.colorScheme.onSurface.withValues(alpha: 0.08);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.support_agent_outlined,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Contact Support',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Our support team is available to assist with account access, payment concerns, premium activation, and general platform usage.',
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          _buildSupportRow(
            context,
            Icons.mail_outline,
            'Email Support',
            'taiwoprints999@gmail.com',
          ),
          const SizedBox(height: 10),
          _buildSupportRow(
            context,
            Icons.access_time_outlined,
            'Support Hours',
            'Monday - Saturday, 8:00 AM - 6:00 PM',
          ),
        ],
      ),
    );
  }

  Widget _buildSupportRow(
    BuildContext context,
    IconData icon,
    String title,
    String value,
  ) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFaqTile(BuildContext context, String question, String answer) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.surfaceDark : theme.colorScheme.surface;
    final borderColor = isDark
        ? AppColors.dividerDark
        : theme.colorScheme.onSurface.withValues(alpha: 0.08);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          backgroundColor: isDark
              ? Colors.white.withValues(alpha: 0.01)
              : theme.colorScheme.primary.withValues(alpha: 0.01),
          collapsedBackgroundColor: Colors.transparent,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Icon(
            Icons.help_outline_rounded,
            size: 22,
            color: theme.colorScheme.primary,
          ),
          iconColor: theme.colorScheme.primary,
          collapsedIconColor: theme.colorScheme.primary,
          title: Text(
            question,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              height: 1.3,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                answer,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

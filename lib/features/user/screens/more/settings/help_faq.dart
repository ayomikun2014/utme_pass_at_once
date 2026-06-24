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
                        'What should I do if I forget my password?',
                        'If you cannot remember your password:\n\n'
                            '• On the Login screen, tap the Forgot Password? text link located below the password field.\n'
                            '• Enter your registered email address in the provided field, then tap the Send Reset Link button.\n'
                            '• Check your email inbox (and spam folder) for a password reset email from the app.\n'
                            '• Open the email, click the verification link, choose a new password, and save it. Return to the app to log in.\n\n'
                            'Please note: If you do not receive the email, make sure the email address was typed correctly and that your internet connection is active.',
                      ),

                      _buildFaqTile(
                        context,
                        'How do I update my profile details?',
                        'To edit your student details:\n\n'
                            '• Go to the bottom navigation bar and tap the More tab (the last icon on the right).\n'
                            '• Scroll to the "Account" section and tap the Profile card.\n'
                            '• Modify your personal details, including your Full Name, Gender, Date of Birth, Hobbies, Interests, or School Status.\n'
                            '• Tap the Save Changes button at the bottom of the form to save and update your details.\n\n'
                            'Please note: If updates do not save, check your internet connection. Your profile is automatically saved on your device for offline access.',
                      ),

                      _buildFaqTile(
                        context,
                        'How do I delete my account and data?',
                        'To permanently delete your account in compliance with data privacy guidelines:\n\n'
                            '• Tap the More tab on the navigation bar, go to the "Account" section, and tap Profile or Delete Account.\n'
                            '• Enter your current password for security verification, or complete Google re-authentication if you signed in via Google.\n'
                            '• Tap the red Confirm Delete Account button.\n\n'
                            'Please note: This action is irreversible. The app will permanently erase all your saved data (including exam history, notifications, and account information) from both your device and our servers instantly.',
                      ),

                      _buildFaqTile(
                        context,
                        'What is the device binding lock policy?',
                        'To prevent account sharing and piracy, PASS AT ONCE links your account to the first device you log in on:\n\n'
                            '• On your first login, the app automatically links your device to your online account.\n'
                            '• If you try to log in on a second device, the system will deny access and log you out.\n\n'
                            'Please note: You will see an error stating "This account is locked to another device." If you have purchased a new phone or need to transfer your registration, please email our support team at taiwoprints999@gmail.com to request a device reset.',
                      ),

                      _buildFaqTile(
                        context,
                        'How do I pay for an exam package using online payments?',
                        'To generate an Activation Code via Paystack:\n\n'
                            '• Open the Store from the Home screen or from the More tab.\n'
                            '• Select your target Exam Type (UTME, Post-UTME, NECO, or WAEC).\n'
                            '• Read the description text and select the Pay Online (Paystack) payment method.\n'
                            '• The app will direct you to the Paystack secure gateway where you can choose Card, USSD, or Bank Transfer.\n'
                            '• Once payment is completed successfully, the app will generate your unique Activation Code and display it on the screen for you to copy.\n'
                            '• A corresponding purchase order is also registered in your purchase history.\n\n'
                            'Note: Payment does not activate premium. You must use the generated Activation Code to unlock your exam package (see "How do I unlock and activate my exam package?").\n\n'
                            'Please note: If the payment succeeds but the screen closes before you copy the code, go to My Purchases on the Home screen or in the Account section to find and copy your generated activation PIN.',
                      ),

                      _buildFaqTile(
                        context,
                        'How do I submit a manual bank transfer?',
                        'To pay via direct bank transfer and receive an Activation Code:\n\n'
                            '• Open the Store from the Home screen or from the More tab.\n'
                            '• Select the Exam Type (UTME, Post-UTME, NECO, or WAEC) you want to purchase.\n'
                            '• Read the description text and select the Manual Payment option.\n'
                            '• Pay the exact amount to the bank details shown on the screen and take a screenshot of the receipt.\n'
                            '• In the payment screen, upload your proof of payment screenshot and submit.\n'
                            '• The transaction order will instantly show in your purchase history as pending.\n\n'
                            'Note: Payment does not activate premium. Once the admin approves your transaction, an Activation Code is generated and will appear in your purchase history. Use that code to unlock your exam package.\n\n'
                            'Please note: Manual payments require admin verification. Check your purchase history periodically for your activation code after submitting the transfer proof.',
                      ),

                      _buildFaqTile(
                        context,
                        'How do I force-refresh my premium status?',
                        'If you have already unlocked and activated an exam package but premium features still appear locked:\n\n'
                            '• Tap the More tab on the bottom navigation bar and select My Account or Store.\n'
                            '• Locate the Refresh Status button (or pull down to refresh on the home dashboard).\n'
                            '• The app will check the server for your latest subscription status and update your app accordingly.\n\n'
                            'Note: Premium is only granted after you successfully unlock an exam using your Activation Code (not at the point of payment).\n\n'
                            'Please note: If status still shows free after refreshing, check that you have completed the full activation process (enter code, select institution, select section, and submit). You can also sign out and sign back in to refresh your account.',
                      ),

                      _buildFaqTile(
                        context,
                        'How do I unlock and activate my exam package?',
                        'Once you have your Activation Code (from an online Paystack purchase, manual bank transfer approval, or a center voucher), you can activate it to unlock premium:\n\n'
                            '• Go to the Home screen and tap the Unlock Now button, or go to My Purchases in the Home screen or Account section and tap Unlock Now next to the order.\n'
                            '• Enter your Activation Code/PIN and tap Verify.\n'
                            '• After verification, the app will show the exam category (JAMB, Post-UTME, NECO, or WAEC) linked to your code. Tap Next to continue.\n'
                            '• Select the target Institution you want to bind to (for example, OAU or UI).\n'
                            '• Select the target Section (either Science or Art/Commerce) for the package.\n'
                            '• Tap the Submit button.\n'
                            '• After submitting, wait for a few minutes for the offline study materials and data to fully download to your device.\n'
                            '• Once activation is complete, your account is upgraded to premium for that exam.\n\n'
                            'Please note: Active internet is required during verification and institution selection. Do not close or minimize the application while the offline data is downloading.',
                      ),

                      _buildFaqTile(
                        context,
                        'How do I set up a CBT exam simulation?',
                        'To start a mock exam matching the official Joint Admissions and Matriculation Board (JAMB) standard:\n\n'
                            '• Tap the Study or Simulator tab in the bottom navigation bar.\n'
                            '• Select your Exam Type (e.g., UTME, Post-UTME) and your target Institution.\n'
                            '• Tap on the Subjects card to choose your 4 subjects pairing.\n'
                            '• Tap the Configure Session / Next button to proceed to the simulation dashboard.\n\n'
                            'Please note: If subjects do not load, make sure you have active internet or have fully downloaded the offline package for this institution.',
                      ),

                      _buildFaqTile(
                        context,
                        'How do I customize timing, question count, and test modes?',
                        'In the Simulator Session Setup screen, you can adjust settings before starting:\n\n'
                            '• Test Mode Toggle: Choose Practice Mode (reveals answers and explanations as you study) or Exam Mode (simulates real exam conditions; answers are hidden until submission).\n'
                            '• Question Count: Tap the question limit dropdown to choose 20, 40, 60, or All questions.\n'
                            '• Year Mode Selection: Select Latest Year (single year), Last 2 Years, Last 3 Years, or Random Shuffle to pool questions.\n'
                            '• Timer Setup: Choose Auto Timer (default duration) or tap Custom Timer and use the slider to set custom minutes.\n\n'
                            'Please note: Free users are limited to 2 years of questions for the Aptitude subject. Upgrade to unlock all years and subjects.',
                      ),

                      _buildFaqTile(
                        context,
                        'How do I run and submit a CBT session?',
                        'Once configured, tap the Start CBT / Start Exam button:\n\n'
                            '• Use the navigation buttons (tapping the Next or Previous buttons at the bottom) or use the question grid to jump directly to any question number.\n'
                            '• Select your answers by tapping option buttons A, B, C, or D.\n'
                            '• Monitor the countdown timer at the top. The app will auto-submit your exam instantly when the timer hits zero.\n'
                            '• To submit manually, tap the Submit Exam button at the top-right corner and tap Confirm.\n\n'
                            'Please note: If you close the app mid-exam, your progress will be lost. Make sure you have stable battery power before starting an exam.',
                      ),

                      _buildFaqTile(
                        context,
                        'How do I use the AI Tutor during review?',
                        'To get step-by-step academic explanations during post-exam review:\n\n'
                            '• After submitting a CBT, tap the Review Answers button.\n'
                            '• Select a question you got wrong or want to study further.\n'
                            '• Tap the Ask AI button located below the question and options.\n'
                            '• The AI Tutor will generate a detailed explanation showing why the correct answer is right.\n\n'
                            'Please note: The AI Tutor requires an active internet connection. The button will be disabled or show an error message when you are offline.',
                      ),

                      _buildFaqTile(
                        context,
                        'How do I track my exam history and analytics?',
                        'To view your academic growth and past performances:\n\n'
                            '• Tap the More tab at the bottom and select Exam History & Analytics.\n'
                            '• Tap any historical card to view a detailed performance summary, showcasing your total score, correct/wrong/skipped question counts, time spent, and individual subject progress bars.\n'
                            '• The app automatically uploads your saved results to the server whenever you are online.\n\n'
                            'Please note: If a test you completed offline is not showing in your history, tap the Sync History icon at the top-right corner of the History screen while connected to the internet.',
                      ),

                      _buildFaqTile(
                        context,
                        'How do I link my account to a study school or center?',
                        'To link your study progress and join your school\'s official virtual classroom:\n\n'
                            '• Go to the More tab, scroll to "Settings", and tap the Profile card.\n'
                            '• Locate the Center Code / Referral Code text field.\n'
                            '• Enter the code provided by your teacher, tutor, or center administrator, then tap the Link Center button.\n'
                            '• Once verified, the school\'s center name will reflect under your profile\'s School Status, and a classroom dashboard will unlock on your home screen.\n\n'
                            'Please note: If the code is rejected, check the spelling (codes are alphanumeric and case-insensitive). Make sure you have a working internet connection.',
                      ),

                      _buildFaqTile(
                        context,
                        'How do I check notices and announcements?',
                        'To read official updates posted by your center administrator:\n\n'
                            '• On the home dashboard, tap the eClassroom / notice board icon.\n'
                            '• Tap the Notice Board tile.\n'
                            '• The notice feed shows updates in real-time. Important announcements are pinned at the top with a red pin icon.\n\n'
                            'Please note: The Notice Board requires an active internet connection. Pull down on the screen to manually refresh the feed if notices are not loading.',
                      ),

                      _buildFaqTile(
                        context,
                        'How do I access downloaded tutor study notes?',
                        'To study using materials uploaded directly by your classroom tutor:\n\n'
                            '• Tap the eClassroom shortcut on the home screen and select Study Notes.\n'
                            '• Select your subject from the list to view available notes.\n'
                            '• Tap the Download Note icon next to any note to save it to your device for offline reading.\n'
                            '• Tap the notes card to open the document inside the built-in PDF viewer.\n\n'
                            'Please note: PDF notes are protected upon download for security purposes. If notes fail to open, delete the downloaded file and tap download again with a stable internet connection.',
                      ),

                      _buildFaqTile(
                        context,
                        'How do I submit my classroom assignments online?',
                        'To submit homework directly to your tutor for grading:\n\n'
                            '• Go to eClassroom, tap Assignments, and select your subject.\n'
                            '• Tap the assignment card to read the instructions, view details, or download reference PDFs.\n'
                            '• Tap the Submit Assignment Online button.\n'
                            '• Type your written response in the text block, or tap Attach File to pick a PDF or upload a photo of your handwritten work using the Camera or Gallery options.\n'
                            '• Tap Submit Homework Online to upload the files securely.\n\n'
                            'Please note: Once submitted, the status changes to "Submitted". You can return to this screen later to view your tutor\'s grade, feedback, and score details.',
                      ),

                      _buildFaqTile(
                        context,
                        'How do I attempt classroom tests and view rankings?',
                        'To sit for tests scheduled by your center:\n\n'
                            '• Go to eClassroom and tap the Classroom Tests tile.\n'
                            '• Tap the test title to read instructions, duration, and deadlines.\n'
                            '• Tap the Start Test button to begin (a strict timer will run, and the test will auto-submit when the duration expires).\n\n'
                            'Please note: You can only attempt a classroom test once. If you exit, the test submits automatically. To see where you rank among classmates, tap Leaderboard inside the eClassroom menu; rankings are updated automatically based on average scores.',
                      ),

                      _buildFaqTile(
                        context,
                        'How do I download syllabi for offline access?',
                        'To access exam syllabi without using internet data:\n\n'
                            '• Tap the Syllabus button on the home screen.\n'
                            '• Select your subject from the list and tap the Download button.\n'
                            '• The app will download the syllabus, protect it securely, and save it on your device.\n'
                            '• Tap the subject card to open it instantly inside the built-in PDF viewer.\n\n'
                            'Please note: Downloaded files are protected to prevent unauthorized copying. If you see any errors when opening, delete the file and re-download the syllabus while online.',
                      ),

                      _buildFaqTile(
                        context,
                        'How do I play video lectures and use Text-to-Speech (TTS)?',
                        'To learn visually or listen to questions audibly:\n\n'
                            '• Video Tutorials: Tap the Video Lectures button on the home screen, select your subject, and tap a video title to stream inside the player.\n'
                            '• Text-to-Speech (TTS): During any CBT exam or review session, locate the Speaker Icon button near the question card.\n'
                            '• Tap the speaker icon once to have the app read the question text and options out loud. Tap the button again to stop/pause the voice narration.\n\n'
                            'Please note: If the voice feature does not work, make sure your device\'s media volume is turned up and that Text-to-Speech is enabled in your phone\'s system settings.',
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

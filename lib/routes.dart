import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// --- CORE / AUTH IMPORTS ---
import 'package:utme_pass_at_once/core/screens/onboarding_screen.dart';
import 'package:utme_pass_at_once/features/auth/screens/forget_password.dart';
import 'package:utme_pass_at_once/features/auth/screens/login_screen.dart';
import 'package:utme_pass_at_once/features/auth/screens/signup_screen.dart';
import 'package:utme_pass_at_once/features/auth/providers/auth_provider.dart';
import 'features/auth/screens/privacy_policy.dart';
import 'features/auth/screens/terms_of_service.dart';

// --- CORE UTILS ---
import 'core/utils/custom_btn.dart';
import 'core/screens/app_startup_gate.dart';
import 'package:utme_pass_at_once/core/utils/custom_loader.dart';

// --- USER FEATURES IMPORTS ---
import 'package:utme_pass_at_once/features/user/screens/more/store.dart';
import 'package:utme_pass_at_once/features/user/utils/main_shell.dart';
import 'features/user/screens/home/unlock_now.dart';
import 'features/user/screens/more/account/change_password.dart';
import 'features/user/screens/more/account/delete_account.dart';
import 'features/user/screens/more/account/my_purchase.dart';
import 'features/user/screens/more/account/profile.dart';
import 'features/user/screens/more/news.dart';
import 'features/user/screens/more/settings/about.dart';
import 'features/user/screens/more/settings/appearance.dart';
import 'features/user/screens/more/settings/contact_us.dart';
import 'features/user/screens/more/settings/help_faq.dart';
import 'features/user/screens/more/settings/notification_setting.dart';
import 'features/user/screens/more/settings/rate.dart';
import 'features/user/screens/more/setting.dart';
import 'features/user/screens/more/my_account.dart';
import 'features/user/screens/more/settings/share_app.dart';
import 'features/user/screens/more/settings/update.dart';
import 'features/user/screens/more/store/manual_payment.dart';
import 'features/user/screens/more/store/payment_details.dart';
import 'features/user/screens/more/store/paystack_checkout.dart';
import 'features/user/screens/more/store/select_payment.dart';
import 'features/user/screens/more/notifications/notification_history_screen.dart';

// --- STUDY & SIMULATOR IMPORTS ---
import 'features/user/screens/simulator/simulator.dart';
import 'features/user/screens/simulator/simulator_history.dart';
import 'features/user/screens/simulator/simulator_session_setup.dart';
import 'features/user/screens/study/bookmarked.dart';
import 'features/user/screens/study/performance_analysis.dart';
import 'features/user/screens/study/syllabus_list_screen.dart';
import 'features/user/screens/study/exam_dashboard_screen.dart';
import 'features/user/screens/study/institution_selection_screen.dart';
import 'features/user/screens/study/study_notes_screen.dart';
import 'features/user/screens/simulator/simulator_subject_selection.dart';
import 'package:utme_pass_at_once/features/user/providers/simulator_provider.dart';

// --- ADMISSION IMPORTS ---
import 'features/user/screens/study/admission/admission_guideline_landing_screen.dart';
import 'features/user/screens/study/admission/admission_requirements_screen.dart';
import 'features/user/screens/study/admission/admission_cut_offs_screen.dart';

// --- ECLASSROOM IMPORTS ---
import 'features/user/screens/eClassroom/test_subject_list_screen.dart';
import 'features/user/screens/eClassroom/assignment_list_screen.dart';
import 'features/user/screens/eClassroom/study_note_list_screen.dart';
import 'features/user/screens/eClassroom/notice_board_screen.dart';

// --- VIDEO TUTORIALS ---
import 'features/user/screens/videos/video_subjects_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String onBoarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgetPassword = '/forget-password';
  static const String mainShell = '/main-shell';
  static const String silver = '/silver';
  static const String store = '/store';
  static const String myAccount = '/my_account';
  static const String settings = '/settings';
  static const String unlock = '/unlock';
  static const String help = '/help';
  static const String about = '/about';
  static const String appearance = '/appearance';
  static const String notification = '/notification';
  static const String rate = '/rate';
  static const String share = '/share';
  static const String update = '/update';
  static const String contact = '/contact';
  static const String profile = '/profile';
  static const String changePassword = '/change_password';
  static const String deleteAccount = '/delete_account';
  static const String paymentDetails = '/payment_details';
  static const String selectPayment = '/select_payment';
  static const String bankTransfer = '/bank_transfer';
  static const String purchase = '/purchase';
  static const String news = '/news';
  static const String utmeHistory = '/utme_history';
  static const String utmePerformance = '/performance_analysis';
  static const String bookmarked = '/bookmarked';
  static const String paystackCheckout = '/paystack_checkout';
  static const String notificationHistory = '/notification_history';

  // --- ECLASSROOM ROUTES ---
  static const String eclassroomTests = '/eclassroom_tests';
  static const String eclassroomAssignments = '/eclassroom_assignments';
  static const String eclassroomStudyNotes = '/eclassroom_study_notes';
  static const String eclassroomNotices = '/eclassroom_notices';

  // --- SYLLABUS ROUTES ---
  static const String jambSyllabus = '/jamb_syllabus';
  static const String jambBrochure = '/jamb_brochure';
  static const String necoSyllabus = '/neco_syllabus';
  static const String waecSyllabus = '/waec_syllabus';
  static const String lessonNotes = '/lesson_notes';
  static const String privacyPolicy = '/privacy_policy';
  static const String termsOfService = '/terms_of_service';

  // --- NEW EXAM-FIRST ROUTES ---
  static const String examDashboard = '/exam_dashboard';
  static const String institutionSelection = '/institution_selection';
  static const String studyNotes = '/study_notes';
  static const String examSyllabus = '/exam_syllabus';
  static const String examSimulatorEntry = '/exam_simulator_entry';

  // --- LEGACY SIMULATOR ROUTES ---
  static const String utmeSimulatorSelection = '/utme_simulator_selection';
  static const String utmeConfigSelection = '/utme_config_selection';
  static const String utmeSimulator = '/utme_simulator';

  // --- ADMISSION GUIDELINE ROUTES ---
  static const String admissionGuideline = '/admission-guideline';
  static const String admissionRequirements = '/admission-requirements';
  static const String admissionCutOffs = '/admission-cutoffs';

  static const String videoSubjects = '/video_subjects';

  static Map<String, WidgetBuilder> get staticRoutes => {
    splash: (context) => const AppStartupGate(),
    onBoarding: (context) => const OnboardingScreen(),
    login: (context) => const LoginScreen(),
    signup: (context) => const SignupScreen(),
    forgetPassword: (context) => const ForgetPassword(),
    mainShell: (context) => const MainShell(),
    store: (context) => const Store(),
    myAccount: (context) => const MyAccount(),
    settings: (context) => const AppSetting(),
    unlock: (context) => const UnlockNow(),
    help: (context) => const HelpAndFaq(),
    about: (context) => const About(),
    appearance: (context) => const Appearance(),
    notification: (context) => const NotificationSetting(),
    rate: (context) => const Rate(),
    share: (context) => const ShareApp(),
    update: (contact) => const UpdateScreen(),
    contact: (context) => const ContactUs(),
    profile: (context) => const Profile(),
    changePassword: (context) => const ChangePassword(),
    deleteAccount: (context) => const DeleteAccount(),
    paymentDetails: (context) => const PaymentDetails(),
    selectPayment: (context) => const SelectPayment(),
    bankTransfer: (context) => const ManualPayment(),
    purchase: (context) => const MyPurchase(),
    news: (context) => const NewsScreen(),
    privacyPolicy: (context) => const PrivacyPolicyScreen(),
    termsOfService: (context) => const TermsOfServiceScreen(),
    notificationHistory: (context) => const NotificationHistoryScreen(),
    admissionGuideline: (context) =>
    const AdmissionGuidelineLandingScreen(),
    admissionRequirements: (context) =>
    const AdmissionRequirementsScreen(),
    admissionCutOffs: (context) => const AdmissionCutOffsScreen(),

    // --- LEGACY SYLLABUS ROUTES ---
    jambSyllabus: (context) => const SyllabusListScreen(
      examType: 'jamb_s',
      title: 'JAMB Syllabus',
    ),
    jambBrochure: (context) => const SyllabusListScreen(
      examType: 'jamb_b',
      title: 'JAMB Brochure',
    ),
    waecSyllabus: (context) => const SyllabusListScreen(
      examType: 'waec',
      title: 'WAEC Syllabus',
    ),
    necoSyllabus: (context) => const SyllabusListScreen(
      examType: 'neco',
      title: 'NECO Syllabus',
    ),
    lessonNotes: (context) => const SyllabusListScreen(
      examType: 'lesson_notes',
      title: 'Lesson Notes',
    ),

    // --- PAYSTACK ROUTE ---
    paystackCheckout: (context) {
      final args =
      ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      return PaystackCheckoutPage(
        checkoutUrl: args?['url'] as String? ?? '',
        reference: args?['reference'] as String? ?? '',
      );
    },

    // === EXAM-FIRST ROUTES ===
    institutionSelection: (context) {
      final args =
      ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      return InstitutionSelectionScreen(
        examType: args?['examType']?.toString() ?? 'post_utme',
      );
    },

    examDashboard: (context) {
      final args =
      ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      return ExamDashboardScreen(
        examType: args?['examType']?.toString() ?? 'jamb',
        schoolId: args?['schoolId']?.toString(),
        schoolName: args?['schoolName']?.toString(),
        logoUrl: args?['logoUrl']?.toString(),
        sectionId: args?['sectionId']?.toString(),
      );
    },

    examSyllabus: (context) {
      final args =
      ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      return SyllabusListScreen(
        examType: args?['examType']?.toString() ?? 'jamb_s',
        title: args?['title']?.toString() ?? 'Syllabus',
      );
    },

    studyNotes: (context) {
      final args =
      ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      return StudyNotesScreen(
        examType: args?['examType']?.toString(),
        schoolId: args?['schoolId']?.toString(),
      );
    },

    bookmarked: (context) {
      final args =
      ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      return BookmarkedQuestionsScreen(
        examType: args?['examType']?.toString(),
        schoolId: args?['schoolId']?.toString() ??
            args?['institutionId']?.toString(),
      );
    },

    utmePerformance: (context) {
      final args =
      ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      return PerformanceAnalysisScreen(
        examType: args?['examType']?.toString(),
        schoolId: args?['schoolId']?.toString() ??
            args?['institutionId']?.toString(),
        sectionId: args?['sectionId']?.toString(),
      );
    },

    utmeHistory: (context) {
      final args =
      ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      return SimulatorHistoryScreen(
        examType: args?['examType']?.toString(),
        schoolId: args?['schoolId']?.toString() ??
            args?['institutionId']?.toString(),
        sectionId: args?['sectionId']?.toString(),
      );
    },

    examSimulatorEntry: (context) {
      final args =
      ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      return _ExamSimulatorEntryScreen(
        examType: args?['examType']?.toString() ?? 'jamb',
        institutionId: args?['institutionId']?.toString() ??
            args?['schoolId']?.toString(),
        institutionName: args?['institutionName']?.toString() ??
            args?['schoolName']?.toString(),
        logoUrl: args?['logoUrl']?.toString(),
        sectionId: args?['sectionId']?.toString(),
        sectionName: args?['sectionName']?.toString(),
      );
    },

    // --- LEGACY SIMULATOR STRINGS ---
    utmeSimulatorSelection: (context) {
      final args =
      ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      return InstitutionSelectionScreen(
        examType: args?['examType']?.toString() ?? 'post_utme',
      );
    },

    utmeConfigSelection: (context) {
      final args =
      ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      return SimulatorSessionSetup(
        examType: args?['examType']?.toString() ?? 'jamb',
        institutionId: args?['institutionId']?.toString() ?? 'oau',
        institutionName: args?['institutionName']?.toString() ?? 'OAU',
        subjects: List<String>.from(args?['subjects'] ?? []),
        isPremium: args?['isPremium'] as bool? ?? false,
        logoUrl: args?['logoUrl']?.toString(),
        sectionId: args?['sectionId']?.toString(),
      );
    },

    utmeSimulator: (context) => const SimulatorScreen(),

    // --- ECLASSROOM ROUTES ---
    eclassroomTests: (context) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      return TestSubjectListScreen(
        adminId: args?['adminId']?.toString() ?? '',
      );
    },
    eclassroomAssignments: (context) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      return AssignmentListScreen(
        adminId: args?['adminId']?.toString() ?? '',
        subject: args?['subject']?.toString() ?? '',
      );
    },
    eclassroomStudyNotes: (context) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      return StudyNoteListScreen(
        adminId: args?['adminId']?.toString() ?? '',
        subject: args?['subject']?.toString() ?? '',
      );
    },
    eclassroomNotices: (context) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      return NoticeBoardScreen(
        adminId: args?['adminId']?.toString() ?? '',
      );
    },
    videoSubjects: (context) => const VideoSubjectsScreen(),
  };

  static Route<dynamic> unknownRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (context) => NotFoundScreen(routeName: settings.name),
    );
  }
}

// =========================================================================
// EXAM SIMULATOR ENTRY — For JAMB/WAEC/NECO and Post UTME Dashboard
// =========================================================================

class _ExamSimulatorEntryScreen extends StatefulWidget {
  final String examType;
  final String? institutionId;
  final String? institutionName;
  final String? logoUrl;
  final String? sectionId;
  final String? sectionName;

  const _ExamSimulatorEntryScreen({
    required this.examType,
    this.institutionId,
    this.institutionName,
    this.logoUrl,
    this.sectionId,
    this.sectionName,
  });

  @override
  State<_ExamSimulatorEntryScreen> createState() =>
      _ExamSimulatorEntryScreenState();
}

class _ExamSimulatorEntryScreenState extends State<_ExamSimulatorEntryScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateToSubjects();
    });
  }

  Future<void> _navigateToSubjects() async {
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    final simProvider = context.read<SimulatorProvider>();
    final user = authProvider.currentUser;

    final bool isPremium = simProvider.hasPremiumForExam(
      authProvider,
      widget.examType,
    );

    final String effectiveInstitutionId =
        widget.institutionId ?? widget.examType.toLowerCase();

    final String effectiveInstitutionName =
        widget.institutionName ?? widget.examType.toUpperCase();

    List<String> availableSubjects = [];
    String? resolvedSectionName = widget.sectionName;

    if (isPremium && user != null) {
      availableSubjects = user.getSubjectsForCenter(
        widget.examType,
        effectiveInstitutionId,
      );

      if (resolvedSectionName == null || resolvedSectionName.trim().isEmpty) {
        final sectionInfo = user.getSectionForInstitution(
          widget.examType,
          effectiveInstitutionId,
        );

        if (sectionInfo != null) {
          resolvedSectionName = sectionInfo['name']?.toString();
        }
      }
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SubjectSelectionScreen(
          examType: widget.examType,
          institutionId: effectiveInstitutionId,
          institutionName: effectiveInstitutionName,
          availableSubjects: availableSubjects,
          isPremium: isPremium,
          logoUrl: widget.logoUrl,
          sectionId: widget.sectionId,
          sectionName: resolvedSectionName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CustomLoader(),
      ),
    );
  }
}

// =========================================================================
// 404 NOT FOUND SCREEN
// =========================================================================

class NotFoundScreen extends StatelessWidget {
  final String? routeName;

  const NotFoundScreen({
    super.key,
    this.routeName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F7);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final btnBgColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 24.0,
            vertical: 24.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '404',
                style: TextStyle(
                  fontSize: 120,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                  height: 1.0,
                  letterSpacing: -5,
                ),
              ),
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 10,
                      left: 0,
                      child: Text(
                        'Page\nnot\nfound',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          height: 1.1,
                          letterSpacing: -1.5,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: -30,
                      bottom: 0,
                      left: 80,
                      child: Image.asset(
                        'assets/images/roboto.webp',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    "Sorry, we couldn't find the\npage you are looking for.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: textColor.withValues(alpha: 0.7),
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              CustomBtn(
                label: 'Go Home',
                backgroundColor: btnBgColor,
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/',
                        (route) => false,
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:utme_pass_at_once/core/utils/custom_loader.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/bg.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/eclassroom_models.dart';
import '../../services/eclassroom_service.dart';
import 'test_list_screen.dart';
import 'widgets/eclassroom_shared_widgets.dart';
import '../../utils/custom_fallback_image.dart';
import '../../../../core/services/network_service.dart';
import '../../../../core/utils/custom_toast.dart';

class TestSubjectListScreen extends StatefulWidget {
  final String adminId;
  const TestSubjectListScreen({super.key, required this.adminId});

  @override
  State<TestSubjectListScreen> createState() => _TestSubjectListScreenState();
}

class _TestSubjectListScreenState extends State<TestSubjectListScreen> {
  final EClassroomService _classroomService = EClassroomService();
  StreamSubscription<List<ClassroomTest>>? _testSubscription;
  List<ClassroomTest> _allTests = [];
  Map<String, Map<String, dynamic>> _studentAttempts = {};
  bool _isLoading = true;
  String? _errorMessage;

  final PageController _pageController = PageController();
  Timer? _bannerTimer;
  int _currentPage = 0;

  final List<String> _bannerImages = [
    'assets/images/eClassroom_subject_banner.webp',
    'assets/images/eClassroom_topic_banner.webp',
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
    _startBannerTimer();
  }

  void _initializeData() async {
    await _loadCachedTests();
    _listenToTests();
  }

  Future<void> _loadCachedTests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString('cached_classroom_tests_${widget.adminId}');
      if (jsonStr != null) {
        final List decoded = jsonDecode(jsonStr);
        setState(() {
          _allTests = decoded.map((e) => ClassroomTest.fromMap(Map<String, dynamic>.from(e))).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading cached tests: $e');
    }
  }

  Future<void> _saveCachedTests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_allTests.map((e) => e.toMap()).toList());
      await prefs.setString('cached_classroom_tests_${widget.adminId}', jsonStr);
    } catch (e) {
      debugPrint('Error saving cached tests: $e');
    }
  }

  void _startBannerTimer() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pageController.hasClients) {
        setState(() {
          _currentPage = (_currentPage + 1) % _bannerImages.length;
        });
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _testSubscription?.cancel();
    _bannerTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    final isOnline = NetworkService.instance.isOnline;
    if (!isOnline) {
      if (mounted) {
        CustomToast.show(context, 'No internet connection. Failed to refresh.', isError: true);
      }
      return;
    }
    _listenToTests();
  }

  void _listenToTests() {
    _testSubscription?.cancel();
    _testSubscription = _classroomService.streamTests(widget.adminId).listen((tests) async {
      if (!mounted) return;
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final studentId = authProvider.currentUser?.uid ?? '';

        // Fetch student attempts in parallel
        final Map<String, Map<String, dynamic>> attempts = {};
        final List<Future<void>> attemptFutures = tests.map((test) async {
          final attempt = await _classroomService.getTestAttempt(widget.adminId, test.id, studentId);
          if (attempt != null) {
            attempts[test.id] = attempt;
          }
        }).toList();

        await Future.wait(attemptFutures);

        if (mounted) {
          setState(() {
            _allTests = tests;
            _studentAttempts = attempts;
            _isLoading = false;
            _errorMessage = null;
          });
          await _saveCachedTests();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _allTests = tests;
            _isLoading = false;
            if (_allTests.isEmpty) {
              _errorMessage = 'Failed to load test completion status: $e';
            }
          });
        }
      }
    }, onError: (err) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_allTests.isEmpty) {
            _errorMessage = err.toString();
          }
        });
      }
    });
  }

  int _getActiveTestCount(String subject) {
    return _allTests.where((test) {
      if (test.subject.trim().toLowerCase() != subject.trim().toLowerCase()) return false;
      final attempted = _studentAttempts.containsKey(test.id);
      final expired = test.deadline.isBefore(DateTime.now());
      return !attempted && !expired;
    }).length;
  }

  int _getTotalTestCount(String subject) {
    return _allTests.where((test) {
      return test.subject.trim().toLowerCase() == subject.trim().toLowerCase();
    }).length;
  }

  IconData _getSubjectIcon(String subject) {
    final s = subject.toLowerCase();
    if (s.contains('math')) return Icons.calculate_rounded;
    if (s.contains('english') || s.contains('yoruba') || s.contains('igbo') || s.contains('hausa') || s.contains('french')) return Icons.translate_rounded;
    if (s.contains('physic')) return Icons.science_rounded;
    if (s.contains('chemist')) return Icons.science_outlined;
    if (s.contains('biolog')) return Icons.biotech_rounded;
    if (s.contains('agric')) return Icons.agriculture_rounded;
    if (s.contains('civic') || s.contains('govern')) return Icons.gavel_rounded;
    if (s.contains('econ')) return Icons.trending_up_rounded;
    if (s.contains('literat')) return Icons.menu_book_rounded;
    if (s.contains('geograph')) return Icons.public_rounded;
    if (s.contains('commerc') || s.contains('account') || s.contains('book')) return Icons.account_balance_wallet_rounded;
    if (s.contains('relig') || s.contains('crs') || s.contains('irs')) return Icons.auto_stories_rounded;
    if (s.contains('histor')) return Icons.history_edu_rounded;
    if (s.contains('computer') || s.contains('data')) return Icons.computer_rounded;
    if (s.contains('art')) return Icons.palette_rounded;
    if (s.contains('music')) return Icons.music_note_rounded;
    return Icons.book_rounded;
  }

  Color _getSubjectColor(String subject) {
    final s = subject.toLowerCase();
    if (s.contains('math')) return Colors.blue;
    if (s.contains('english')) return Colors.indigo;
    if (s.contains('physic')) return Colors.purple;
    if (s.contains('chemist')) return Colors.teal;
    if (s.contains('biolog')) return Colors.green;
    if (s.contains('agric')) return Colors.lightGreen;
    if (s.contains('civic') || s.contains('govern')) return Colors.red;
    if (s.contains('econ')) return Colors.amber.shade800;
    if (s.contains('literat')) return Colors.pink;
    if (s.contains('geograph')) return Colors.cyan;
    if (s.contains('commerc') || s.contains('account') || s.contains('book')) return Colors.orange;
    if (s.contains('relig') || s.contains('crs') || s.contains('irs')) return Colors.deepOrange;
    if (s.contains('histor')) return Colors.brown;
    if (s.contains('computer') || s.contains('data')) return Colors.blueGrey;
    if (s.contains('art')) return Colors.purpleAccent;
    if (s.contains('music')) return Colors.deepPurple;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Unique list of subjects extracted dynamically
    final subjects = _allTests.map((t) => t.subject.trim()).toSet().toList();
    subjects.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 200.0,
                  floating: false,
                  pinned: true,
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.white),
                  flexibleSpace: FlexibleSpaceBar(
                    title: const Text(
                      'Classroom Tests',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 18.0,
                        shadows: [
                          Shadow(
                            color: Colors.black45,
                            blurRadius: 4,
                            offset: Offset(1, 1),
                          ),
                        ],
                      ),
                    ),
                    centerTitle: true,
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        PageView.builder(
                          controller: _pageController,
                          itemCount: _bannerImages.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            return Image.asset(
                              _bannerImages[index],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const CustomFallbackImage(
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            );
                          },
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.15),
                                Colors.black.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: RefreshIndicator(
              onRefresh: _refreshData,
              color: AppColors.primary,
              child: _isLoading
                  ? const CustomLoader()
                  : _errorMessage != null
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Failed to load classroom tests',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : subjects.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                                const EClassroomEmptyState(
                                  icon: Icons.quiz_outlined,
                                  message: 'No tests posted by administrator yet.',
                                ),
                              ],
                            )
                          : AnimationLimiter(
                              child: GridView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(20),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  childAspectRatio: 1.1,
                                ),
                                itemCount: subjects.length,
                                itemBuilder: (context, index) {
                                  final subject = subjects[index];
                                  final activeCount = _getActiveTestCount(subject);
                                  final totalCount = _getTotalTestCount(subject);

                                  return AnimationConfiguration.staggeredGrid(
                                    position: index,
                                    duration: const Duration(milliseconds: 600),
                                    columnCount: 2,
                                    child: SlideAnimation(
                                      verticalOffset: 50.0,
                                      child: FadeInAnimation(
                                        child: _buildSubjectCard(subject, activeCount, totalCount, isDark),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(String subject, int activeCount, int totalCount, bool isDark) {
    final Color baseColor = _getSubjectColor(subject);
    final IconData icon = _getSubjectIcon(subject);

    return Card(
      elevation: 0,
      color: isDark ? AppColors.surfaceDark.withValues(alpha: 0.5) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? AppColors.dividerDark : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TestListScreen(
                adminId: widget.adminId,
                subject: subject,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: baseColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: baseColor, size: 24),
              ),
              const Spacer(),
              Text(
                subject,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.0,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (activeCount > 0 ? Colors.green : Colors.grey).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: activeCount > 0 ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$activeCount Active',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: activeCount > 0 ? Colors.green : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$totalCount Total',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

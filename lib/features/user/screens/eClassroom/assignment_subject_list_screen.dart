import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:utme_pass_at_once/core/utils/custom_loader.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/bg.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/eclassroom_models.dart';
import '../../services/eclassroom_service.dart';
import 'assignment_list_screen.dart';
import 'widgets/eclassroom_shared_widgets.dart';
import '../../utils/custom_fallback_image.dart';
import '../../../../core/services/network_service.dart';
import '../../../../core/utils/custom_toast.dart';

class AssignmentSubjectListScreen extends StatefulWidget {
  final String adminId;
  const AssignmentSubjectListScreen({super.key, required this.adminId});

  @override
  State<AssignmentSubjectListScreen> createState() => _AssignmentSubjectListScreenState();
}

class _AssignmentSubjectListScreenState extends State<AssignmentSubjectListScreen> {
  final EClassroomService _classroomService = EClassroomService();
  StreamSubscription<List<Assignment>>? _assignmentSubscription;
  List<Assignment> _allAssignments = [];
  Map<String, Map<String, dynamic>> _studentSubmissions = {};
  bool _isLoading = true;
  String? _errorMessage;

  final PageController _pageController = PageController();
  Timer? _bannerTimer;
  int _currentPage = 0;

  final List<String> _bannerImages = [
    'assets/images/eclassroom_banner.webp',
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
    _startBannerTimer();
  }

  void _initializeData() async {
    await _loadCachedAssignments();
    _listenToAssignments();
  }

  Future<void> _loadCachedAssignments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString('cached_classroom_assignments_${widget.adminId}');
      if (jsonStr != null) {
        final List decoded = jsonDecode(jsonStr);
        setState(() {
          _allAssignments = decoded.map((e) => Assignment.fromMap(Map<String, dynamic>.from(e))).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading cached assignments: $e');
    }
  }

  Future<void> _saveCachedAssignments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_allAssignments.map((e) => e.toMap()).toList());
      await prefs.setString('cached_classroom_assignments_${widget.adminId}', jsonStr);
    } catch (e) {
      debugPrint('Error saving cached assignments: $e');
    }
  }

  void _startBannerTimer() {
    if (_bannerImages.length <= 1) return;
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
    _assignmentSubscription?.cancel();
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
    _listenToAssignments();
  }

  void _listenToAssignments() {
    _assignmentSubscription?.cancel();
    _assignmentSubscription = _classroomService.streamAssignments(widget.adminId).listen((assignments) async {
      if (!mounted) return;
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final studentId = authProvider.currentUser?.uid ?? '';

        // Fetch submissions in parallel
        final Map<String, Map<String, dynamic>> submissions = {};
        final List<Future<void>> submissionFutures = assignments.map((assignment) async {
          final doc = await FirebaseFirestore.instance
              .collection('admins')
              .doc(widget.adminId)
              .collection('assignments')
              .doc(assignment.id)
              .collection('submissions')
              .doc(studentId)
              .get();
          if (doc.exists && doc.data() != null) {
            submissions[assignment.id] = doc.data()!;
          }
        }).toList();

        await Future.wait(submissionFutures);

        if (mounted) {
          setState(() {
            _allAssignments = assignments;
            _studentSubmissions = submissions;
            _isLoading = false;
            _errorMessage = null;
          });
          await _saveCachedAssignments();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _allAssignments = assignments;
            _isLoading = false;
            if (_allAssignments.isEmpty) {
              _errorMessage = 'Failed to load assignment submission status: $e';
            }
          });
        }
      }
    }, onError: (err) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_allAssignments.isEmpty) {
            _errorMessage = err.toString();
          }
        });
      }
    });
  }

  int _getActiveAssignmentCount(String subject) {
    final nowWAT = DateTime.now().toUtc().add(const Duration(hours: 1));
    return _allAssignments.where((a) {
      if (a.subject.trim().toLowerCase() != subject.trim().toLowerCase()) return false;
      final hasSubmitted = _studentSubmissions.containsKey(a.id);
      final dueDateWAT = a.dueDate.toUtc().add(const Duration(hours: 1));
      final isExpired = dueDateWAT.isBefore(nowWAT);
      return !hasSubmitted && !isExpired;
    }).length;
  }

  int _getTotalAssignmentCount(String subject) {
    return _allAssignments.where((a) {
      return a.subject.trim().toLowerCase() == subject.trim().toLowerCase();
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
    if (s.contains('art')) return Colors.pinkAccent;
    if (s.contains('music')) return Colors.deepPurple;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Unique list of subjects extracted dynamically
    final subjects = _allAssignments.map((a) => a.subject.trim()).toSet().toList();
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
                      'Classroom Assignments',
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
                                      'Failed to load assignments',
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
                                  icon: Icons.assignment_outlined,
                                  message: 'No assignments posted by administrator yet.',
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
                                  final activeCount = _getActiveAssignmentCount(subject);
                                  final totalCount = _getTotalAssignmentCount(subject);

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
              builder: (_) => AssignmentListScreen(
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

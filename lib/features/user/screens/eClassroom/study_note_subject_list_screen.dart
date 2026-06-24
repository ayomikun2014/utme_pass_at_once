import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:utme_pass_at_once/core/utils/custom_loader.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/bg.dart';
import '../../models/eclassroom_models.dart';
import '../../services/eclassroom_service.dart';
import 'study_note_list_screen.dart';
import 'widgets/eclassroom_shared_widgets.dart';
import '../../utils/custom_fallback_image.dart';
import '../../../../core/services/network_service.dart';
import '../../../../core/utils/custom_toast.dart';

class StudyNoteSubjectListScreen extends StatefulWidget {
  final String adminId;
  const StudyNoteSubjectListScreen({super.key, required this.adminId});

  @override
  State<StudyNoteSubjectListScreen> createState() => _StudyNoteSubjectListScreenState();
}

class _StudyNoteSubjectListScreenState extends State<StudyNoteSubjectListScreen> {
  final EClassroomService _classroomService = EClassroomService();
  StreamSubscription<List<StudyNote>>? _studyNoteSubscription;
  List<StudyNote> _allStudyNotes = [];
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
    await _loadCachedStudyNotes();
    _listenToStudyNotes();
  }

  Future<void> _loadCachedStudyNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString('cached_classroom_studynotes_${widget.adminId}');
      if (jsonStr != null) {
        final List decoded = jsonDecode(jsonStr);
        setState(() {
          _allStudyNotes = decoded.map((e) => StudyNote.fromMap(Map<String, dynamic>.from(e))).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading cached study notes: $e');
    }
  }

  Future<void> _saveCachedStudyNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_allStudyNotes.map((e) => e.toMap()).toList());
      await prefs.setString('cached_classroom_studynotes_${widget.adminId}', jsonStr);
    } catch (e) {
      debugPrint('Error saving cached study notes: $e');
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
    _studyNoteSubscription?.cancel();
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
    _listenToStudyNotes();
  }

  void _listenToStudyNotes() {
    _studyNoteSubscription?.cancel();
    _studyNoteSubscription = _classroomService.streamStudyNotes(widget.adminId).listen((notes) async {
      if (mounted) {
        setState(() {
          _allStudyNotes = notes;
          _isLoading = false;
          _errorMessage = null;
        });
        await _saveCachedStudyNotes();
      }
    }, onError: (err) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_allStudyNotes.isEmpty) {
            _errorMessage = err.toString();
          }
        });
      }
    });
  }

  int _getTotalStudyNoteCount(String subject) {
    return _allStudyNotes.where((note) {
      return note.subject.trim().toLowerCase() == subject.trim().toLowerCase();
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
    final subjects = _allStudyNotes.map((note) => note.subject.trim()).toSet().toList();
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
                      'Study Notes',
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
                                      'Failed to load study notes',
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
                                  icon: Icons.menu_book_outlined,
                                  message: 'No study notes posted by administrator yet.',
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
                                  final totalCount = _getTotalStudyNoteCount(subject);

                                  return AnimationConfiguration.staggeredGrid(
                                    position: index,
                                    duration: const Duration(milliseconds: 600),
                                    columnCount: 2,
                                    child: SlideAnimation(
                                      verticalOffset: 50.0,
                                      child: FadeInAnimation(
                                        child: _buildSubjectCard(subject, totalCount, isDark),
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

  Widget _buildSubjectCard(String subject, int totalCount, bool isDark) {
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
              builder: (_) => StudyNoteListScreen(
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$totalCount Note${totalCount != 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:utme_pass_at_once/core/utils/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart'; // <-- NEW IMPORT

import '../../../../core/utils/bg.dart';
import '../../../../core/utils/custom_app_bar.dart';
import '../../../../core/utils/custom_btn.dart';
import '../../../../core/utils/custom_loader.dart'; // <-- NEW IMPORT
import '../../providers/simulator_provider.dart';

class SubjectSelectionScreen extends StatefulWidget {
  final String examType;
  final String institutionId;
  final String institutionName;
  final List<String> availableSubjects; // Kept as a fallback only
  final bool isPremium;
  final String? logoUrl;
  final String? sectionName;
  final String? sectionId;

  const SubjectSelectionScreen({
    super.key,
    required this.examType,
    required this.institutionId,
    required this.institutionName,
    required this.availableSubjects,
    required this.isPremium,
    this.logoUrl,
    this.sectionName,
    this.sectionId,
  });

  @override
  State<SubjectSelectionScreen> createState() => _SubjectSelectionScreenState();
}

class _SubjectSelectionScreenState extends State<SubjectSelectionScreen>
    with SingleTickerProviderStateMixin {
  final List<String> _selectedSubjects = [];
  late AnimationController _animController;

  List<String> _filteredSubjects = [];
  bool _isCenterUnlocked = false;
  bool _isLoading = true; // <-- NEW LOADING STATE

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Fetch the subjects dynamically on screen load
    _loadDynamicSubjects();
  }

  // --- NEW ARCHITECTURE: Dynamic Subject Fetching ---
  Future<void> _loadDynamicSubjects() async {
    if (!widget.isPremium) {
      setState(() {
        _isCenterUnlocked = false;
        _filteredSubjects = ['aptitude'];
        _selectedSubjects.add('aptitude');
        _isLoading = false;
      });
      _animController.forward();
      return;
    }

    try {
      final simProvider = context.read<SimulatorProvider>();

      // Clean the institution ID for Post-UTME (e.g., 'oau_science' -> 'oau')
      final baseInstitutionId = widget.examType.toLowerCase() == 'post_utme' && widget.institutionId.contains('_')
          ? widget.institutionId.split('_').first
          : widget.institutionId;

      // 1. Fetch exactly what is stored in the offline Hive cache right now
      final fetchedSubjects = await simProvider.getAvailableSubjects(
        widget.examType,
        baseInstitutionId,
        isPremium: true,
        sectionId: widget.sectionId,
      );

      final dynamicSubjectIds = fetchedSubjects.map((s) => s.id).toList();

      if (mounted) {
        setState(() {
          _isCenterUnlocked = true;
          // 2. Use the fresh dynamic list! (Fallback to old widget list just in case)
          _filteredSubjects = dynamicSubjectIds.isNotEmpty
              ? dynamicSubjectIds
              : widget.availableSubjects;

          if (widget.examType.toLowerCase() != 'post_utme' && _filteredSubjects.contains('aptitude')) {
            _selectedSubjects.add('aptitude');
          }
          _isLoading = false;
        });
        _animController.forward();
      }
    } catch (e) {
      debugPrint('Error loading dynamic subjects: $e');
      if (mounted) {
        setState(() {
          _isCenterUnlocked = true;
          _filteredSubjects = widget.availableSubjects; // Fallback
          _isLoading = false;
        });
        _animController.forward();
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onSubjectTap(String subject) {
    setState(() {
      if (_selectedSubjects.contains(subject)) {
        if (subject == 'aptitude' && widget.examType.toLowerCase() != 'post_utme') return; // Cannot unselect Aptitude unless Post-UTME
        _selectedSubjects.remove(subject);
      } else {
        // Post-UTME has no max subject limit for the selected section
        if (widget.examType.toLowerCase() != 'post_utme') {
          int maxSubjects =
          (widget.examType.toLowerCase() == 'waec' ||
              widget.examType.toLowerCase() == 'neco')
              ? 9
              : 4;
          if (_selectedSubjects.length >= maxSubjects) {
            CustomToast.show(context, 'You can only select up to $maxSubjects subjects');
            return;
          }
        }
        _selectedSubjects.add(subject);
      }
    });
  }

  void _onContinue() {
    if (_selectedSubjects.isEmpty) {
      CustomToast.show(context, 'Please select at least one subject');
      return;
    }

    Navigator.pushNamed(
      context,
      '/utme_config_selection',
      arguments: {
        'examType': widget.examType,
        'institutionId': widget.institutionId,
        'institutionName': widget.institutionName,
        'subjects': _selectedSubjects,
        'isPremium': widget.isPremium,
        'logoUrl': widget.logoUrl,
        'sectionId': widget.sectionId,
        'sectionName': widget.sectionName,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasLogo = widget.logoUrl != null && widget.logoUrl!.trim().isNotEmpty;

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          CustomScrollView(
            slivers: [
              CustomAppBar(
                title: widget.examType.toLowerCase() == 'post_utme' && widget.sectionName != null
                    ? 'Post-UTME ${widget.sectionName}'
                    : 'Select Subjects',
                subtitle: widget.institutionName,
                isLeading: true,
              ),

              // Institution Logo Header
              if (hasLogo)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [const Color(0xFF1E2330), const Color(0xFF2A3040)]
                              : [const Color(0xFFF8FAFC), Colors.white],
                        ),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Logo
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: CachedNetworkImage(
                                imageUrl: widget.logoUrl!,
                                width: 88,
                                height: 88,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 88,
                                  height: 88,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.school_rounded,
                                    color: theme.colorScheme.primary.withValues(alpha: 0.4),
                                    size: 32,
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 88,
                                  height: 88,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.school_rounded,
                                    color: theme.colorScheme.primary.withValues(alpha: 0.4),
                                    size: 32,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Info
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.institutionName,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : const Color(0xFF111827),
                                      height: 1.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      widget.examType == 'post_utme'
                                          ? 'Post-UTME'
                                          : widget.examType.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              if (!_isCenterUnlocked)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _UpgradeBanner(
                      onTap: () => Navigator.pushNamed(context, '/store'),
                    ),
                  ),
                ),

              // THE FIX: Show loader while fetching dynamic subjects
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CustomLoader()),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.3,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final subject = _filteredSubjects[index];
                      final isSelected = _selectedSubjects.contains(subject);
                      return _SubjectCard(
                        index: index,
                        subject: subject,
                        isSelected: isSelected,
                        animController: _animController,
                        onTap: () => _onSubjectTap(subject),
                      );
                    }, childCount: _filteredSubjects.length),
                  ),
                ),
            ],
          ),

          // Bottom continue button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.scaffoldBackgroundColor.withValues(alpha: 0),
                    theme.scaffoldBackgroundColor,
                  ],
                ),
              ),
              child: CustomBtn(
                label: widget.examType.toLowerCase() == 'post_utme'
                    ? 'Start Practice (${_selectedSubjects.length})'
                    : 'Continue to Setup (${_selectedSubjects.length}/${(widget.examType.toLowerCase() == 'waec' || widget.examType.toLowerCase() == 'neco') ? 9 : 4})',
                onPressed: _selectedSubjects.isEmpty || _isLoading ? null : _onContinue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================================================
// SUBJECT CARD
// ==========================================================================

class _SubjectCard extends StatelessWidget {
  final int index;
  final String subject;
  final bool isSelected;
  final AnimationController animController;
  final VoidCallback onTap;

  const _SubjectCard({
    required this.index,
    required this.subject,
    required this.isSelected,
    required this.animController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final delay = (index * 0.05).clamp(0.0, 0.6);
    final slideAnim =
    Tween<Offset>(begin: const Offset(0.2, 0), end: Offset.zero).animate(
      CurvedAnimation(
        parent: animController,
        curve: Interval(
          delay,
          (delay + 0.4).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic,
        ),
      ),
    );
    final fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: animController,
        curve: Interval(
          delay,
          (delay + 0.4).clamp(0.0, 1.0),
          curve: Curves.easeOut,
        ),
      ),
    );

    // Format strings like 'christian_religious_studies' to 'CHRISTIAN RELIGIOUS STUDIES'
    final displaySubjectName = subject.replaceAll('_', ' ').toUpperCase();

    return AnimatedBuilder(
      animation: animController,
      builder: (context, child) => FadeTransition(
        opacity: fadeAnim,
        child: SlideTransition(position: slideAnim, child: child),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary
                : (isDark ? const Color(0xFF1E2330) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : (isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.1)),
              width: 1.5,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getIconForSubject(subject),
                color: isSelected ? Colors.white : theme.colorScheme.primary,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                displaySubjectName,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white : Colors.black87),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (isSelected) ...[
                const SizedBox(height: 4),
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white.withValues(alpha: 0.8),
                  size: 16,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForSubject(String subject) {
    switch (subject.toLowerCase()) {
      case 'aptitude':
        return Icons.psychology_alt_rounded;
      case 'english':
      case 'use_of_english':
        return Icons.menu_book_rounded;
      case 'mathematics':
      case 'general_mathematics':
        return Icons.calculate_rounded;
      case 'physics':
        return Icons.science_rounded;
      case 'chemistry':
      case 'chemistry_1':
        return Icons.biotech_rounded;
      case 'biology':
        return Icons.psychology_rounded;
      case 'economics':
        return Icons.analytics_rounded;
      case 'government':
        return Icons.account_balance_rounded;
      case 'commerce':
        return Icons.shopping_bag_rounded;
      case 'accounts':
      case 'financial_accounting':
        return Icons.account_balance_wallet_rounded;
      case 'crs':
      case 'christian_religious_studies':
        return Icons.church_rounded;
      case 'irs':
      case 'islamic_religious_studies':
        return Icons.mosque_rounded;
      case 'literature':
      case 'literature_in_english':
        return Icons.auto_stories_rounded;
      case 'geography':
        return Icons.public_rounded;
      default:
        return Icons.subtitles_rounded;
    }
  }
}

// ==========================================================================
// UPGRADE BANNER
// ==========================================================================

class _UpgradeBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _UpgradeBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            const Icon(Icons.stars_rounded, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Unlock More Subjects',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Get access to all subjects, years, and institutions.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:utme_pass_at_once/core/utils/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/utils/custom_app_bar.dart';
import '../../../../core/utils/bg.dart';
import '../../models/question_model.dart';
import '../../providers/simulator_provider.dart';
import 'package:utme_pass_at_once/core/utils/custom_loader.dart';
import 'package:utme_pass_at_once/core/utils/rich_content_renderer.dart';
import '../../../../core/constants/app_colors.dart';
class BookmarkedQuestionsScreen extends StatefulWidget {
  final String? examType;
  final String? schoolId;
  final String? sectionId;

  const BookmarkedQuestionsScreen({
    super.key,
    this.examType,
    this.schoolId,
    this.sectionId,
  });

  @override
  State<BookmarkedQuestionsScreen> createState() =>
      _BookmarkedQuestionsScreenState();
}

class _BookmarkedQuestionsScreenState extends State<BookmarkedQuestionsScreen> {
  List<Map<String, dynamic>> _allBookmarks = [];
  List<Map<String, dynamic>> _filteredBookmarks = [];
  List<String> _availableSubjects = ['All'];

  bool _isLoading = true;
  String _selectedSubject = 'All';
  bool _sortAscending = false;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_filterAndSortBookmarks);
    _loadBookmarks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }



  String _baseInstitutionId(String id) {
    final lower = id.toLowerCase().trim();

    if (!lower.contains('_')) return lower;

    return lower.split('_').first;
  }

  String? _sectionIdFromKey(String id) {
    final lower = id.toLowerCase().trim();

    if (!lower.contains('_')) return null;

    final parts = lower.split('_');

    if (parts.length < 2) return null;

    return parts.sublist(1).join('_');
  }

  String? _targetSectionId() {
    final rawSection = widget.sectionId?.toLowerCase().trim();

    if (rawSection != null && rawSection.isNotEmpty) {
      return rawSection;
    }

    final schoolId = widget.schoolId?.toLowerCase().trim();

    if (schoolId == null || schoolId.isEmpty) return null;

    return _sectionIdFromKey(schoolId);
  }

  String? _targetBaseSchoolId() {
    final schoolId = widget.schoolId?.toLowerCase().trim();

    if (schoolId == null || schoolId.isEmpty) return null;

    return _baseInstitutionId(schoolId);
  }

  String? _effectiveInstitutionForAction() {
    final schoolId = widget.schoolId?.toLowerCase().trim();

    if (schoolId == null || schoolId.isEmpty) return null;

    return schoolId;
  }

  String _screenSubtitle() {
    final sectionId = _targetSectionId();

    if (widget.examType?.toLowerCase() == 'post_utme' &&
        sectionId != null &&
        sectionId.isNotEmpty) {
      final sectionName = sectionId
          .replaceAll('_', ' ')
          .split(' ')
          .map((word) {
        if (word.isEmpty) return word;
        return '${word[0].toUpperCase()}${word.substring(1)}';
      })
          .join(' ');

      return '$sectionName Local Bookmarks';
    }

    return 'Device Local Bookmarks';
  }

  Future<void> _loadBookmarks() async {
    setState(() => _isLoading = true);

    final provider = context.read<SimulatorProvider>();
    List<Map<String, dynamic>> bookmarks = await provider.getBookmarks();

    final targetExamType = widget.examType?.toLowerCase().trim();

    final targetBaseSchoolId = _targetBaseSchoolId();
    final targetSectionId = _targetSectionId();

    if (targetExamType != null) {
      bookmarks = bookmarks.where((bookmark) {
        final bExam = bookmark['examType']?.toString();

        if (bExam == null) return true;

        return bExam.toLowerCase().trim() == targetExamType;
      }).toList();
    }

    if (targetBaseSchoolId != null && targetExamType == 'post_utme') {
      bookmarks = bookmarks.where((bookmark) {
        final rawInstitution =
            bookmark['institutionId']?.toString() ??
                bookmark['centerCode']?.toString() ??
                bookmark['schoolId']?.toString();

        if (rawInstitution == null) return true;

        final bookmarkBaseInstitution = _baseInstitutionId(rawInstitution);

        final bookmarkSectionId = bookmark['sectionId']
            ?.toString()
            .toLowerCase()
            .trim() ??
            _sectionIdFromKey(rawInstitution);

        final sameInstitution = bookmarkBaseInstitution == targetBaseSchoolId;

        final sameSection = targetSectionId == null
            ? true
            : bookmarkSectionId == targetSectionId;

        return sameInstitution && sameSection;
      }).toList();
    }

    final Set<String> subjectsSet = {'All'};

    for (final bookmark in bookmarks) {
      final subject = bookmark['subject']?.toString();

      if (subject != null && subject.trim().isNotEmpty) {
        subjectsSet.add(subject.toUpperCase());
      }
    }

    if (!mounted) return;

    setState(() {
      _allBookmarks = bookmarks;
      _availableSubjects = subjectsSet.toList()
        ..sort((a, b) {
          if (a == 'All') return -1;
          if (b == 'All') return 1;
          return a.compareTo(b);
        });
      _isLoading = false;
    });

    _filterAndSortBookmarks();
  }

  void _filterAndSortBookmarks() {
    final query = _searchController.text.toLowerCase().trim();
    List<Map<String, dynamic>> result = List.from(_allBookmarks);

    if (_selectedSubject != 'All') {
      result = result.where((bookmark) {
        final subject = bookmark['subject']?.toString().toUpperCase() ?? '';
        return subject == _selectedSubject;
      }).toList();
    }

    if (query.isNotEmpty) {
      result = result.where((bookmark) {
        final subject = bookmark['subject']?.toString().toLowerCase() ?? '';

        final qMap = Map<String, dynamic>.from(bookmark['question']);
        final question = QuestionModel.fromFullJson(qMap);
        final plainText = extractPlainText(question.content).toLowerCase();

        return plainText.contains(query) || subject.contains(query);
      }).toList();
    }

    result.sort((a, b) {
      final dateA = a['savedAt']?.toString() ?? '';
      final dateB = b['savedAt']?.toString() ?? '';

      return _sortAscending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
    });

    if (!mounted) return;

    setState(() {
      _filteredBookmarks = result;
    });
  }

  Future<void> _removeBookmark(
      QuestionModel question,
      String subject,
      Map<String, dynamic>? sourceBookmark,
      ) async {
    final provider = context.read<SimulatorProvider>();

    final examType = sourceBookmark?['examType']?.toString() ??
        widget.examType ??
        'jamb';

    final institutionId = sourceBookmark?['institutionId']?.toString() ??
        sourceBookmark?['centerCode']?.toString() ??
        sourceBookmark?['schoolId']?.toString() ??
        _effectiveInstitutionForAction() ??
        'jamb';

    await provider.toggleBookmark(
      question,
      subject,
      examType,
      institutionId,
    );

    await _loadBookmarks();

    if (!mounted) return;

    CustomToast.show(context, 'Bookmark removed.');
  }

  Future<void> _clearAllBookmarks() async {
    if (_filteredBookmarks.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Clear Bookmarks?'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete all ${_filteredBookmarks.length} displayed bookmarks?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Clear All',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);

    final provider = context.read<SimulatorProvider>();

    if (_selectedSubject == 'All' && _searchController.text.isEmpty) {
      await provider.clearAllBookmarks(
        examType: widget.examType,
        institutionId: _effectiveInstitutionForAction(),
      );
    } else {
      for (final bookmark in _filteredBookmarks) {
        final qMap = Map<String, dynamic>.from(bookmark['question']);
        final question = QuestionModel.fromFullJson(qMap);

        final subject = bookmark['subject']?.toString() ?? '';

        final examType = bookmark['examType']?.toString() ??
            widget.examType ??
            'jamb';

        final institutionId = bookmark['institutionId']?.toString() ??
            bookmark['centerCode']?.toString() ??
            bookmark['schoolId']?.toString() ??
            _effectiveInstitutionForAction() ??
            'jamb';

        await provider.toggleBookmark(
          question,
          subject,
          examType,
          institutionId,
        );
      }
    }

    await _loadBookmarks();

    if (!mounted) return;

    CustomToast.show(context, 'Bookmarks cleared.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          RefreshIndicator(
            onRefresh: _loadBookmarks,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                CustomAppBar(
                  title: 'Saved Questions',
                  subtitle: _screenSubtitle(),
                  isLeading: true,
                  centerTitle: true,
                  actions: [
                    if (_allBookmarks.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.delete_sweep_rounded),
                        color: Colors.red.shade400,
                        tooltip: 'Clear All',
                        onPressed: _clearAllBookmarks,
                      ),
                  ],
                ),

                if (!_isLoading && _allBookmarks.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Search questions...',
                                    prefixIcon: const Icon(Icons.search),
                                    suffixIcon:
                                    _searchController.text.isNotEmpty
                                        ? IconButton(
                                      icon: const Icon(
                                        Icons.clear,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        FocusScope.of(context)
                                            .unfocus();
                                      },
                                    )
                                        : null,
                                    filled: true,
                                    fillColor: theme.colorScheme.surface,
                                    contentPadding:
                                    const EdgeInsets.symmetric(vertical: 0),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(30),
                                      borderSide: BorderSide(
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.2),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(30),
                                      borderSide: BorderSide(
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.1),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: 0.1),
                                  ),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    _sortAscending
                                        ? Icons.arrow_upward_rounded
                                        : Icons.arrow_downward_rounded,
                                    color: theme.colorScheme.primary,
                                  ),
                                  tooltip: _sortAscending
                                      ? 'Oldest First'
                                      : 'Newest First',
                                  onPressed: () {
                                    setState(() {
                                      _sortAscending = !_sortAscending;
                                    });

                                    _filterAndSortBookmarks();
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          SizedBox(
                            height: 40,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _availableSubjects.length,
                              separatorBuilder: (context, index) =>
                              const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final subject = _availableSubjects[index];
                                final isSelected =
                                    _selectedSubject == subject;

                                return ChoiceChip(
                                  label: Text(subject),
                                  selected: isSelected,
                                  selectedColor: theme.colorScheme.primary
                                      .withValues(alpha: 0.15),
                                  side: BorderSide(
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.dividerColor,
                                  ),
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                  onSelected: (selected) {
                                    if (!selected) return;

                                    setState(() {
                                      _selectedSubject = subject;
                                    });

                                    _filterAndSortBookmarks();
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),

                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              '${_filteredBookmarks.length} Bookmarks Found',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (_isLoading)
                  const SliverFillRemaining(
                    child: Center(child: CustomLoader()),
                  )
                else if (_allBookmarks.isEmpty)
                  SliverFillRemaining(
                    child: _buildEmptyState(
                      theme,
                      isGlobalEmpty: true,
                    ),
                  )
                else if (_filteredBookmarks.isEmpty)
                    SliverFillRemaining(
                      child: _buildEmptyState(
                        theme,
                        isGlobalEmpty: false,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) {
                            final item = _filteredBookmarks[index];
                            final subject = item['subject']?.toString() ?? '';
                            final qMap =
                            Map<String, dynamic>.from(item['question']);
                            final question = QuestionModel.fromFullJson(qMap);

                            return _buildBookmarkCard(
                              theme,
                              isDark,
                              question,
                              subject,
                              item,
                            );
                          },
                          childCount: _filteredBookmarks.length,
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
      ThemeData theme, {
        required bool isGlobalEmpty,
      }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isGlobalEmpty
                  ? Icons.bookmark_border_rounded
                  : Icons.search_off_rounded,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isGlobalEmpty ? 'No Saved Questions' : 'No Matches Found',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isGlobalEmpty
                ? 'Flag questions during your exams\nto save them for review later.'
                : 'Try adjusting your search query\nor changing the subject filter.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarkCard(
    ThemeData theme,
    bool isDark,
    QuestionModel question,
    String subject,
    Map<String, dynamic> sourceBookmark,
  ) {
    final plainText = extractPlainText(question.content);
    final year = sourceBookmark['year']?.toString() ?? question.year;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showQuestionDetailBottomSheet(question, subject, year, sourceBookmark),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$subject • YEAR $year'.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.bookmark_remove_rounded,
                        color: Colors.red.withValues(alpha: 0.6),
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _removeBookmark(
                        question,
                        subject,
                        sourceBookmark,
                      ),
                      tooltip: 'Remove Bookmark',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  plainText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    height: 1.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      'View Question & Solution',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showQuestionDetailBottomSheet(
    QuestionModel question,
    String subject,
    String year,
    Map<String, dynamic> sourceBookmark,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: isDark ? AppColors.dividerDark : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subject.toUpperCase(),
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              Text(
                                'Exam Year: $year',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, size: 20),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Divider(
                    color: isDark ? AppColors.dividerDark : Colors.grey.shade200,
                    thickness: 1,
                    height: 1,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichContentRenderer(
                            blocks: question.content,
                            textStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 15.5,
                              height: 1.6,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Column(
                            children: List.generate(question.options.length, (index) {
                              final optionLetter = question.options[index].key;
                              final optionBlocks = question.options[index].content;
                              final isCorrect = optionLetter == question.correctAnswer;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isCorrect
                                      ? (isDark ? Colors.green.withValues(alpha: 0.08) : Colors.green.shade50.withValues(alpha: 0.6))
                                      : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade50),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isCorrect
                                        ? Colors.green.withValues(alpha: 0.3)
                                        : (isDark ? AppColors.dividerDark : Colors.grey.shade200),
                                    width: isCorrect ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        color: isCorrect
                                            ? Colors.green
                                            : theme.colorScheme.onSurface.withValues(alpha: 0.06),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          optionLetter,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: isCorrect ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: RichContentRenderer(
                                          blocks: optionBlocks,
                                          textStyle: GoogleFonts.plusJakartaSans(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 16),
                          Divider(
                            color: isDark ? AppColors.dividerDark : Colors.grey.shade200,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.green.withValues(alpha: 0.1) : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.green.withValues(alpha: 0.25),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Correct Answer:',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: isDark ? Colors.green.shade300 : Colors.green.shade800,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      question.correctAnswer,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                        color: isDark ? Colors.green.shade300 : Colors.green.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                                if (question.explanation.isNotEmpty) ...[
                                  const SizedBox(height: 14),
                                  Text(
                                    'Explanation:',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: isDark ? Colors.green.shade300 : Colors.green.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  RichContentRenderer(
                                    blocks: question.explanation,
                                    textStyle: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      height: 1.5,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.95),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  Divider(
                    color: isDark ? AppColors.dividerDark : Colors.grey.shade200,
                    height: 1,
                  ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: Text(
                          'Got it, Close',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
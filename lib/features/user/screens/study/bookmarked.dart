import 'package:utme_pass_at_once/core/utils/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/custom_app_bar.dart';
import '../../../../core/utils/bg.dart';
import '../../models/question_model.dart';
import '../../providers/simulator_provider.dart';
import 'package:utme_pass_at_once/core/utils/custom_loader.dart';
import 'package:utme_pass_at_once/core/utils/rich_content_renderer.dart';
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                      subject.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.bookmark_remove_rounded,
                      color: Colors.red.withValues(alpha: 0.6),
                    ),
                    onPressed: () => _removeBookmark(
                      question,
                      subject,
                      sourceBookmark,
                    ),
                    tooltip: 'Remove Bookmark',
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: RichContentRenderer(
                blocks: question.content,
              ),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: List.generate(question.options.length, (index) {
                  final optionLetter = question.options[index].key;

                  final optionBlocks = question.options[index].content;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.05,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              optionLetter,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: RichContentRenderer(
                              blocks: optionBlocks,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 8),
            Divider(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              height: 1,
            ),

            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                iconColor: Colors.green,
                collapsedIconColor: theme.colorScheme.primary,
                title: Text(
                  'View Solution',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: theme.colorScheme.primary,
                  ),
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.green.shade50,
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
                                Icons.check,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Correct Answer:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              question.correctAnswer,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? Colors.green.shade300
                                    : Colors.green.shade700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        if (question.explanation.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Explanation:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark
                                  ? Colors.green.shade300
                                  : Colors.green.shade700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          RichContentRenderer(
                            blocks: question.explanation,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
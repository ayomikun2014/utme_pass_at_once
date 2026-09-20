import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:utme_pass_at_once/core/constants/app_colors.dart';
import 'package:utme_pass_at_once/core/utils/bg.dart';
import 'package:utme_pass_at_once/core/utils/custom_app_bar.dart';
import 'package:utme_pass_at_once/core/utils/custom_loader.dart';
import 'package:utme_pass_at_once/features/auth/providers/auth_provider.dart';
import 'package:utme_pass_at_once/features/user/providers/study_notes_provider.dart';
import 'package:utme_pass_at_once/features/user/screens/eClassroom/eclassroom_pdf_viewer.dart';
import 'package:utme_pass_at_once/features/user/models/study_notes_model.dart';
import 'package:utme_pass_at_once/core/utils/custom_toast.dart';

/// The app's study notes: one list of subjects, each a PDF that is downloaded
/// and then read inside the app.
///
/// This used to be opened from each exam's dashboard and showed only that
/// exam's notes. It is now a single global list reached from the Home and More
/// quick links, so it takes no exam or institution.
class StudyNotesScreen extends StatefulWidget {
  const StudyNotesScreen({super.key});

  @override
  State<StudyNotesScreen> createState() => _StudyNotesScreenState();
}

class _StudyNotesScreenState extends State<StudyNotesScreen> {
  /// The note every reader gets, activated or not.
  ///
  /// Use of English is the one subject every candidate sits whatever they are
  /// writing, so it is the sample: a free reader can download and read it in
  /// full. Activating any exam unlocks the rest, the same rule the video
  /// tutorials use.
  static const String _freeSubjectId = 'use_of_english';

  bool _isUnlocked(StudySubjectModel subject, {required bool isPremium}) =>
      isPremium || subject.subjectId.toLowerCase() == _freeSubjectId;

  final TextEditingController _searchController = TextEditingController();
  final Set<String> _cachedSubjectIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudyNotesProvider>().loadStudyNotes();
    });
  }

  /// Check if a subject's file is already cached locally
  Future<bool> _isFileCached(StudySubjectModel subject) async {
    final url = subject.fileUrl;
    if (url == null || url.isEmpty) return false;
    final bytes = utf8.encode(url);
    final hash = sha256.convert(bytes).toString();
    final directory = await getApplicationDocumentsDirectory();
    final localPath = '${directory.path}/pdf_cache_$hash.pdf';
    final file = File(localPath);
    if (await file.exists()) {
      final len = await file.length();
      return len > 0;
    }
    return false;
  }

  /// Refresh cached status for all subjects
  Future<void> _refreshCachedStatus(List<StudySubjectModel> subjects) async {
    final newCached = <String>{};
    for (final subject in subjects) {
      if (await _isFileCached(subject)) {
        newCached.add(subject.subjectId);
      }
    }
    if (mounted) {
      setState(() {
        _cachedSubjectIds.clear();
        _cachedSubjectIds.addAll(newCached);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();
    // Any activated exam opens every note, exactly as the video tutorials
    // decide it. Without one the reader still gets the list, and Use of English
    // to read in full.
    final isPremium = authProvider.currentUser?.isPremium ?? false;
    final provider = context.watch<StudyNotesProvider>();

    // Trigger data load if not yet fetched
    if (!provider.hasFetched && !provider.isLoading && provider.error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<StudyNotesProvider>().loadStudyNotes();
        }
      });
    }

    // Refresh cached file indicators when subjects finish loading
    if (provider.hasFetched &&
        provider.subjects.isNotEmpty &&
        _cachedSubjectIds.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshCachedStatus(provider.subjects);
      });
    }

    // Every subject is shown. The list used to be cut down to the subjects the
    // reader had activated for JAMB, which made sense when it hung off the
    // JAMB dashboard; as one global library it should show what there is.
    final List<StudySubjectModel> subjectsToShow = provider.subjects;

    final subjects_ = provider.selectedSubjectId == null
        ? subjectsToShow
        : subjectsToShow
              .where((s) => s.subjectId == provider.selectedSubjectId)
              .toList();
    final filteredSubjects = provider.searchQuery.isEmpty
        ? subjects_
        : subjects_
              .where(
                (s) => s.subjectName.toLowerCase().contains(
                  provider.searchQuery.toLowerCase(),
                ),
              )
              .toList();

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          CustomScrollView(
            slivers: [
              const CustomAppBar(
                title: 'Study Notes',
                subtitle: 'Summarized notes for quick revision.',
                isLeading: true,
                centerTitle: true,
              ),

              // Search and Filter Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: Column(
                    children: [
                      // Search Bar
                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.05,
                            ),
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
                        child: TextField(
                          controller: _searchController,
                          onChanged: provider.setSearchQuery,
                          decoration: InputDecoration(
                            hintText: 'Search topics...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      provider.setSearchQuery('');
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Subject Chips
                      if (subjectsToShow.isNotEmpty)
                        SizedBox(
                          height: 45,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _buildSubjectChip(
                                context,
                                'All',
                                null,
                                provider.selectedSubjectId == null,
                              ),
                              ...subjectsToShow.map(
                                (s) => _buildSubjectChip(
                                  context,
                                  s.subjectName,
                                  s.subjectId,
                                  provider.selectedSubjectId == s.subjectId,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Readers with nothing activated still get the list; this says
              // what they can open and how to get the rest.
              if (!isPremium)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lock_open_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Use of English is free to read. Activate any '
                              'exam to unlock every other note.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.75,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/store'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Unlock',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Content Area
              if (provider.isLoading)
                const SliverFillRemaining(child: Center(child: CustomLoader()))
              else if (provider.error != null)
                SliverFillRemaining(child: _buildErrorState(provider))
              else if (filteredSubjects.isEmpty)
                SliverFillRemaining(child: _buildEmptyState(theme))
              else
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.9,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final subject = filteredSubjects[index];
                      return _buildSubjectCard(
                            context,
                            subject,
                            theme,
                            isDark,
                            unlocked: _isUnlocked(
                              subject,
                              isPremium: isPremium,
                            ),
                          )
                          .animate()
                          .fadeIn(delay: Duration(milliseconds: 50 * index))
                          .scale(delay: Duration(milliseconds: 50 * index));
                    }, childCount: filteredSubjects.length),
                  ),
                ),

              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectChip(
    BuildContext context,
    String label,
    String? id,
    bool isSelected,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) {
          context.read<StudyNotesProvider>().setSelectedSubject(id);
        },
        selectedColor: theme.colorScheme.primary,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : theme.colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notes_rounded,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          const Text(
            'No topics found',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or search query.',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(StudyNotesProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Failed to load study notes',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              provider.error ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => provider.loadStudyNotes(forceRefresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectCard(
    BuildContext context,
    StudySubjectModel subject,
    ThemeData theme,
    bool isDark, {
    required bool unlocked,
  }) {
    final isCached = unlocked && _cachedSubjectIds.contains(subject.subjectId);

    return Opacity(
      opacity: unlocked ? 1 : 0.55,
      child: GestureDetector(
        onTap: () => unlocked ? _openFile(subject) : _showLockedNotice(),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
            border: Border.all(
              color: isCached
                  ? Colors.green.withValues(alpha: 0.3)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.05),
              width: isCached ? 1.5 : 1.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Study Notes',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        if (!unlocked)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.08,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.lock_rounded,
                              size: 14,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          )
                        else if (isCached)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.download_done_rounded,
                              size: 14,
                              color: Colors.green,
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.cloud_download_outlined,
                              size: 14,
                              color: Colors.orange,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      subject.subjectName,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Expanded, because the caption is longer than the card
                    // is wide once a note is locked.
                    Expanded(
                      child: Text(
                        !unlocked
                            ? 'Locked • Tap to unlock'
                            : isCached
                            ? 'Saved • Tap to read'
                            : 'PDF • Tap to download',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isCached
                              ? Colors.green.shade600
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      unlocked
                          ? Icons.picture_as_pdf_rounded
                          : Icons.lock_rounded,
                      size: 18,
                      color: theme.colorScheme.primary.withValues(alpha: 0.8),
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

  /// A locked note explains itself rather than doing nothing when tapped.
  void _showLockedNotice() {
    CustomToast.show(
      context,
      'Activate any exam to unlock this note.',
      isError: true,
    );
  }

  Future<void> _openFile(StudySubjectModel subject) async {
    final url = subject.fileUrl;
    if (url == null || url.isEmpty) {
      CustomToast.show(
        context,
        'No file URL available for this subject.',
        isError: true,
      );
      return;
    }

    _downloadAndOpenPdf(url, subject.subjectName);
  }

  Future<void> _downloadAndOpenPdf(String pdfUrl, String title) async {
    final bytes = utf8.encode(pdfUrl);
    final hash = sha256.convert(bytes).toString();
    final directory = await getApplicationDocumentsDirectory();
    final localPath = '${directory.path}/pdf_cache_$hash.pdf';
    final file = File(localPath);

    final exists = await file.exists();
    if (!mounted) return;
    bool hasCachedFile = false;
    if (exists) {
      final len = await file.length();
      if (len > 0) {
        hasCachedFile = true;
      }
    }
    if (!mounted) return;
    if (hasCachedFile) {
      _navigateToPdfViewer(title, localPath);
      return;
    }

    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _DownloadDialog(url: pdfUrl, localPath: localPath, fileType: 'PDF'),
    );

    if (success == true && mounted) {
      // Refresh cached status so the card updates its indicator
      final provider = context.read<StudyNotesProvider>();
      _refreshCachedStatus(provider.subjects);
      _navigateToPdfViewer(title, localPath);
    }
  }

  void _navigateToPdfViewer(String title, String filePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EClassroomPdfViewer(title: title, filePath: filePath),
      ),
    );
  }
}

class _DownloadDialog extends StatefulWidget {
  final String url;
  final String localPath;
  final String fileType;

  const _DownloadDialog({
    required this.url,
    required this.localPath,
    this.fileType = 'PDF',
  });

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  double _progress = 0.0;
  String _error = '';
  bool _isDone = false;
  http.Client? _client;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }

  Future<void> _startDownload() async {
    try {
      _client = http.Client();
      final request = http.Request('GET', Uri.parse(widget.url));
      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        throw Exception('Server returned status code ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final file = File(widget.localPath);
      final sink = file.openWrite();
      int bytesReceived = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        bytesReceived += chunk.length;
        if (contentLength > 0 && mounted) {
          setState(() {
            _progress = bytesReceived / contentLength;
          });
        }
      }

      await sink.flush();
      await sink.close();

      if (mounted) {
        setState(() => _isDone = true);
        // Brief delay so user sees 100% before dialog closes
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      // Clean up partial file
      try {
        final file = File(widget.localPath);
        if (await file.exists()) await file.delete();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error.isNotEmpty) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Download Failed'),
        content: Text(_error),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Close'),
          ),
        ],
      );
    }

    final percentage = (_progress * 100).round();
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        _isDone ? 'Download Complete' : 'Downloading ${widget.fileType}',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _progress > 0 ? _progress : null,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(
              _isDone ? Colors.green : Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isDone)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 18,
                ),
              if (_isDone) const SizedBox(width: 6),
              Text(
                _isDone ? 'Opening file...' : '$percentage% Completed',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _isDone ? Colors.green : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:utme_pass_at_once/core/constants/app_colors.dart';
import 'package:utme_pass_at_once/features/user/models/video_model.dart';
import 'package:utme_pass_at_once/core/utils/custom_toast.dart';

class VideoPlayerScreen extends StatefulWidget {
  final VideoModel video;

  const VideoPlayerScreen({super.key, required this.video});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with SingleTickerProviderStateMixin {
  WebViewController? _webViewController;
  late TabController _tabController;
  List<Map<String, dynamic>> _notes = [];
  bool _isLoading = true;
  String? _playerError;

  /// YouTube's own fullscreen view, handed to us by the WebView.
  Widget? _fullscreenPlayer;
  late String _currentTip;

  final List<String> _loadingTips = [
    "Active Recall: Testing yourself on key concepts is 150% more effective than just re-reading your study notes! 🧠",
    "Speed Wins: In the UTME exam, spend no more than 40 seconds per question. Learn to skip and return later! 🕒",
    "Smart Notes: Use the 'My Notes' tab below to type and save formulas, definitions, and key revision points instantly! 📚",
    "Widescreen View: Rotate your phone to landscape mode to watch this lecture in comfortable, immersive full-screen! 📱",
    "Feynman Technique: Try explaining the concepts learned in this video to a friend to master and retain them completely! 🧠",
    "Stay Fresh: Take a 5-minute break for every 25 minutes of intense study (Pomodoro Technique) to boost your focus! 🎯",
    "Simulator Ready: After watching this tutorial, go to the Exam Simulator to practice actual past questions on this topic! 🧪",
    "Exam Warning: Never bring any mobile phones or unauthorized electronic devices to the JAMB exam center. Be safe! ⚠️",
    "Practice Mode: Solving past questions repeatedly builds muscle memory and boosts confidence for the actual exam! ✍️",
    "Consistency: A little practice every single day builds up to an outstanding, elite UTME score! 🔥",
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Select a random study tip
    _currentTip = _loadingTips[Random().nextInt(_loadingTips.length)];

    _initWebViewController();

    _loadNotes();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _tabController.dispose();
    super.dispose();
  }

  void _initWebViewController() {
    final videoId = widget.video.youtubeId;
    debugPrint("🎬 Video: '${widget.video.url}' -> id '$videoId'");

    if (videoId.isEmpty) {
      setState(() {
        _playerError = "This video link is not one the player understands.";
        _isLoading = false;
      });
      return;
    }

    // YouTube's own embed page. Loading their page rather than a page of our
    // own means their player, their controls and their fullscreen button.
    final embedUrl = Uri.parse(
      'https://www.youtube-nocookie.com/embed/$videoId'
      '?autoplay=1&playsinline=1&rel=0&modestbranding=1&fs=1&iv_load_policy=3&cc_load_policy=0',
    );

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _playerError = null;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            // Sub-resources fail all the time on a weak connection; only a
            // failure of the page itself is worth telling the reader about.
            if (!error.isForMainFrame!) return;
            debugPrint("❌ WebView error: ${error.description}");
            if (mounted) {
              setState(() {
                _playerError = "This video could not be loaded.";
                _isLoading = false;
              });
            }
          },
        ),
      );

    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setMediaPlaybackRequiresUserGesture(false);
      // The fullscreen button inside the player asks the host app for a
      // fullscreen view; without this it does nothing at all.
      platform.setCustomWidgetCallbacks(
        onShowCustomWidget: (Widget widget, void Function()? onExit) {
          if (!mounted) return;
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
          setState(() => _fullscreenPlayer = widget);
        },
        onHideCustomWidget: () {
          if (!mounted) return;
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          setState(() => _fullscreenPlayer = null);
        },
      );
    }

    controller.loadRequest(embedUrl);

    if (mounted) {
      setState(() {
        _webViewController = controller;
      });
    }
  }

  void _reloadVideo() {
    setState(() {
      _isLoading = true;
      _playerError = null;
      _currentTip = _loadingTips[Random().nextInt(_loadingTips.length)];
    });
    _initWebViewController();
    CustomToast.show(context, "Reloading video...", isError: false);
  }

  /// Some owners do not allow their video to play inside another app. The
  /// YouTube app or the browser will still play it.
  Future<void> _openOnYoutube() async {
    final uri = Uri.parse(widget.video.watchUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        CustomToast.show(context, "Could not open YouTube.", isError: true);
      }
    } catch (e) {
      debugPrint('Could not open YouTube: $e');
    }
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'notes_${widget.video.id}';
    final raw = prefs.getString(key);

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        setState(() {
          _notes = decoded.cast<Map<String, dynamic>>();
        });
      } catch (_) {
        final migrated = {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'content': raw,
          'createdAt': DateTime.now().toIso8601String(),
        };
        setState(() {
          _notes = [migrated];
        });
        await _persistNotes();
      }
    }
  }

  Future<void> _persistNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'notes_${widget.video.id}';
    await prefs.setString(key, jsonEncode(_notes));
  }

  void _addNote(String title, String content) {
    final note = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': title,
      'content': content,
      'createdAt': DateTime.now().toIso8601String(),
    };
    setState(() {
      _notes.insert(0, note);
    });
    _persistNotes();
    CustomToast.show(context, "Note saved!", isError: false);
  }

  void _deleteNote(int index) {
    setState(() {
      _notes.removeAt(index);
    });
    _persistNotes();
    CustomToast.show(context, "Note deleted", isError: false);
  }

  void _showAddNoteSheet(bool isDark) {
    final titleController = TextEditingController();
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            margin: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              16 + MediaQuery.of(sheetContext).viewPadding.bottom,
            ),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.grey.shade200,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      color: AppColors.dynamicColors[2],
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "New Revision Note",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.grey.shade200,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  child: TextField(
                    controller: titleController,
                    maxLines: 1,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: const InputDecoration(
                      hintText: "Title (e.g. Newton's First Law)",
                      hintStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.normal,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(
                    minHeight: 120,
                    maxHeight: 220,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.amber.shade50.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.amber.shade100,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  child: TextField(
                    controller: noteController,
                    minLines: 4,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: const InputDecoration(
                      hintText:
                          "Type your note — key concepts, formulas, definitions...",
                      hintStyle: TextStyle(fontSize: 13),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    final content = noteController.text.trim();
                    if (title.isEmpty) {
                      CustomToast.show(
                        sheetContext,
                        "Please enter a title!",
                        isError: true,
                      );
                      return;
                    }
                    if (content.isEmpty) {
                      CustomToast.show(
                        sheetContext,
                        "Please type a note first!",
                        isError: true,
                      );
                      return;
                    }
                    _addNote(title, content);
                    Navigator.pop(sheetContext);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dynamicColors[2],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Save Note",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The player itself: on screen as soon as there is a controller, with the
  /// loading state over the top of it rather than in place of it.
  Widget _buildPlayerArea({required bool isDark, required bool isLandscape}) {
    if (_playerError != null) {
      return _buildPlayerErrorState(isLandscape: isLandscape);
    }

    return Stack(
      children: [
        if (_webViewController != null)
          WebViewWidget(controller: _webViewController!)
        else
          const ColoredBox(color: Colors.black, child: SizedBox.expand()),
        if (_isLoading) ...[
          _buildLoadingOverlay(isDark, isLandscape: isLandscape),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              minHeight: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF8F00)),
              backgroundColor: Colors.transparent,
            ),
          ),
        ],
      ],
    );
  }

  /// When a video will not play here -- most often because its owner does not
  /// allow it outside YouTube -- say so and offer the way that works.
  Widget _buildPlayerErrorState({required bool isLandscape}) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.play_disabled_rounded,
                color: Colors.white54,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                _playerError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _reloadVideo,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Try again'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _openOnYoutube,
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Watch on YouTube'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF0000),
                      foregroundColor: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    final visual = _getSubjectVisualDetails(widget.video.subject);

    // The player asked for fullscreen; give it the whole screen.
    if (_fullscreenPlayer != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.expand(child: _fullscreenPlayer),
      );
    }

    if (isLandscape) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            _buildPlayerArea(isDark: isDark, isLandscape: true),
            Positioned(
              top: 20,
              left: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () {
                    SystemChrome.setPreferredOrientations([
                      DeviceOrientation.portraitUp,
                    ]);
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.video.subject.toUpperCase(),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            fontSize: 15,
            color: Colors.white,
            letterSpacing: 0.8,
          ),
        ),
        centerTitle: true,
        backgroundColor: visual.gradientStart,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: "Reload Player",
            onPressed: _reloadVideo,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: Colors.black,
                child: Stack(
                  children: [
                    _buildPlayerArea(isDark: isDark, isLandscape: false),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 8,
              ),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: isDark ? Colors.white12 : Colors.white,
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                        ),
                    ],
                  ),
                  labelColor: isDark ? Colors.white : Colors.black87,
                  unselectedLabelColor: isDark
                      ? Colors.white54
                      : Colors.black54,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: "About Lesson"),
                    Tab(text: "My Notes"),
                  ],
                ),
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAboutTab(theme, isDark),
                  _buildNotesTab(theme, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutTab(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.video.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ).animate().fadeIn(duration: 300.ms),

          const SizedBox(height: 12),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.dynamicColors[2].withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.video.subject.toUpperCase(),
                  style: TextStyle(
                    color: AppColors.dynamicColors[2],
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              if (widget.video.duration.isNotEmpty) ...[
                const SizedBox(width: 12),
                Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: isDark ? Colors.white60 : Colors.black45,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.video.duration,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ],
          ).animate().fadeIn(delay: 100.ms, duration: 300.ms),

          const Divider(height: 32),

          const Text(
            "Description",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),

          const SizedBox(height: 8),

          Text(
            widget.video.description.isNotEmpty
                ? widget.video.description
                : "No description available for this lesson.",
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 300.ms),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1736) : Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF2E2452)
                    : Colors.indigo.shade100,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.screen_rotation_rounded,
                  color: isDark ? Colors.indigoAccent : Colors.indigo.shade700,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Tip: Rotate your phone to landscape mode to watch in full-screen widescreen format!",
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? Colors.indigo.shade100
                          : Colors.indigo.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
        ],
      ),
    );
  }

  Widget _buildNotesTab(ThemeData theme, bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            children: [
              const Text(
                "My Notes",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(width: 8),
              if (_notes.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.dynamicColors[2].withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_notes.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.dynamicColors[2],
                    ),
                  ),
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _showAddNoteSheet(isDark),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  "Add Note",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.dynamicColors[2],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: _notes.isEmpty
              ? _buildEmptyNotesState(isDark)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    return _buildNoteCard(_notes[index], index, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note, int index, bool isDark) {
    final content = note['content'] as String? ?? '';
    final createdAt =
        DateTime.tryParse(note['createdAt'] ?? '') ?? DateTime.now();
    final dateStr =
        '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    // Support backwards compatibility for old notes that don't have a title
    final title =
        note['title'] as String? ??
        (content.length > 40 ? '${content.substring(0, 40)}...' : content);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.dynamicColors[2].withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.dynamicColors[2],
                  fontSize: 14,
                ),
              ),
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              dateStr,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ),
          trailing: IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: isDark ? Colors.white38 : Colors.redAccent.shade100,
            ),
            onPressed: () => _deleteNote(index),
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.amber.shade50.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(
                content,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.6,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms, delay: (index * 50).ms);
  }

  Widget _buildEmptyNotesState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.amber.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.note_add_rounded,
              size: 32,
              color: isDark ? Colors.white24 : Colors.amber.shade300,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "No notes yet",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Tap 'Add Note' to jot down key points\nwhile watching this lesson",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white30 : Colors.black38,
              height: 1.5,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildLoadingOverlay(bool isDark, {bool isLandscape = false}) {
    final double paddingVal = isLandscape ? 16.0 : 12.0;

    return Container(
      color: Colors.black,
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 40 : 16,
        vertical: isLandscape ? 12 : 4,
      ),
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isLandscape ? 500 : double.infinity,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161925) : const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: EdgeInsets.all(paddingVal),
          child: Center(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFFF8F00),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Preparing Video Player...",
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 1,
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                  const SizedBox(height: 8),
                  Icon(
                        Icons.lightbulb_outline_rounded,
                        color: const Color(0xFFFF8F00),
                        size: isLandscape ? 24 : 22,
                      )
                      .animate(
                        onPlay: (controller) =>
                            controller.repeat(reverse: true),
                      )
                      .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.15, 1.15),
                        duration: 800.ms,
                      ),
                  const SizedBox(height: 6),
                  Text(
                    "CORE STUDY INSIGHT",
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: const Color(0xFFFF8F00),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentTip,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: isLandscape ? 12 : 11.5,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.9)
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _SubjectVisual _getSubjectVisualDetails(String subject) {
    final key = subject.trim().toLowerCase();

    if (key.contains('physics')) {
      return _SubjectVisual(
        icon: Icons.science_rounded,
        gradientStart: const Color(0xFF3F51B5),
        gradientEnd: const Color(0xFF303F9F),
      );
    }
    if (key.contains('chemistry')) {
      return _SubjectVisual(
        icon: Icons.biotech_rounded,
        gradientStart: const Color(0xFF009688),
        gradientEnd: const Color(0xFF00796B),
      );
    }
    if (key.contains('biology')) {
      return _SubjectVisual(
        icon: Icons.psychology_rounded,
        gradientStart: const Color(0xFF4CAF50),
        gradientEnd: const Color(0xFF388E3C),
      );
    }
    if (key.contains('math') || key.contains('arithmetic')) {
      return _SubjectVisual(
        icon: Icons.calculate_rounded,
        gradientStart: const Color(0xFFFF5722),
        gradientEnd: const Color(0xFFD84315),
      );
    }
    if (key.contains('english') ||
        key.contains('literature') ||
        key.contains('lang')) {
      return _SubjectVisual(
        icon: Icons.menu_book_rounded,
        gradientStart: const Color(0xFF9C27B0),
        gradientEnd: const Color(0xFF7B1FA2),
      );
    }
    if (key.contains('government') ||
        key.contains('history') ||
        key.contains('civic')) {
      return _SubjectVisual(
        icon: Icons.gavel_rounded,
        gradientStart: const Color(0xFFE91E63),
        gradientEnd: const Color(0xFFC2185B),
      );
    }
    if (key.contains('geo') || key.contains('agric')) {
      return _SubjectVisual(
        icon: Icons.public_rounded,
        gradientStart: const Color(0xFF8BC34A),
        gradientEnd: const Color(0xFF689F38),
      );
    }
    if (key.contains('account') ||
        key.contains('commerce') ||
        key.contains('econ')) {
      return _SubjectVisual(
        icon: Icons.monetization_on_rounded,
        gradientStart: const Color(0xFF00BCD4),
        gradientEnd: const Color(0xFF0097A7),
      );
    }

    return _SubjectVisual(
      icon: Icons.import_contacts_rounded,
      gradientStart: const Color(0xFF673AB7),
      gradientEnd: const Color(0xFF512DA8),
    );
  }
}

class _SubjectVisual {
  final IconData icon;
  final Color gradientStart;
  final Color gradientEnd;

  _SubjectVisual({
    required this.icon,
    required this.gradientStart,
    required this.gradientEnd,
  });
}

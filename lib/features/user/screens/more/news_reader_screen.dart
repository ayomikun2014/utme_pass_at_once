import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:utme_pass_at_once/core/utils/custom_loader.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/news_model.dart';

class NewsReaderScreen extends StatefulWidget {
  final NewsModel news;
  const NewsReaderScreen({super.key, required this.news});

  @override
  State<NewsReaderScreen> createState() => _NewsReaderScreenState();
}

class _NewsReaderScreenState extends State<NewsReaderScreen> {
  /// Open the publisher's own page, inside the app.
  void _openPublisher() {
    if (widget.news.link.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PublisherPage(
          url: widget.news.link,
          source: widget.news.source,
        ),
      ),
    );
  }

  Future<void> _launchSourceUrl() async {
    try {
      final uri = Uri.parse(widget.news.link);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open the source link.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Launch Error: $e');
    }
  }

  void _shareArticle() {
    Share.share('Check out this educational news: ${widget.news.title}\n\nRead more at: ${widget.news.link}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Education News',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _shareArticle,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: _launchSourceUrl,
            tooltip: 'Open in your browser',
          ),
        ],
      ),
      body: _buildNativeReader(context),
    );
  }

  Widget _buildNativeReader(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    // The story as far as it goes: the article when the feed gives one, the
    // publisher's summary otherwise.
    final paragraphs = widget.news.body
        .split(RegExp(r'\n+'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    final isSummary = !widget.news.hasFullStory;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Elegant Header Image
          if (widget.news.imageUrl.isNotEmpty)
            Hero(
              tag: 'news_image_${widget.news.link}',
              child: CachedNetworkImage(
                imageUrl: widget.news.imageUrl,
                height: 250,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 250,
                  color: isDarkMode ? Colors.grey[900] : Colors.grey[200],
                  child: const Center(child: CustomLoader()),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 250,
                  color: isDarkMode ? Colors.grey[900] : Colors.grey[200],
                  child: Icon(Icons.image_not_supported_outlined, size: 50, color: theme.colorScheme.primary),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Source and Date Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.secondary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.news.source,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.news.pubDate,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Large Premium Title
                Text(
                  widget.news.title,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),

                // Subtle Premium Gradient Divider
                Container(
                  height: 2,
                  width: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(height: 20),

                if (isSummary) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.summarize_rounded,
                        size: 15,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'In brief',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                // Body Paragraphs
                ...paragraphs.map((para) => Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        para,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          height: 1.7,
                          color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.95),
                        ),
                      ),
                    )),
                
                const SizedBox(height: 24),

                // Premium Source Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isSummary
                            ? 'That is the summary ${widget.news.source} published. Read the '
                                'rest of the story on their site -- it opens here in the app.'
                            : 'This article was first published by ${widget.news.source}. '
                                'Their page has the pictures and comments.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          height: 1.5,
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _openPublisher,
                          icon: const Icon(Icons.menu_book_rounded, size: 18),
                          label: Text(
                            isSummary ? 'Read the full story' : 'Open the original page',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _launchSourceUrl,
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: Text(
                          'Open in my browser',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The publisher's own page, shown inside the app.
class _PublisherPage extends StatefulWidget {
  const _PublisherPage({required this.url, required this.source});

  final String url;
  final String source;

  @override
  State<_PublisherPage> createState() => _PublisherPageState();
}

class _PublisherPageState extends State<_PublisherPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.source,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Open in my browser',
            icon: const Icon(Icons.open_in_browser),
            onPressed: () async {
              final uri = Uri.parse(widget.url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CustomLoader()),
        ],
      ),
    );
  }
}

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
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Initialize WebViewController only if fullContent is null or empty
    if (widget.news.fullContent == null || widget.news.fullContent!.isEmpty) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) {
              if (mounted) {
                setState(() => _isLoading = false);
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.news.link));
    } else {
      _isLoading = false;
    }
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
    final bool useNativeReader = widget.news.fullContent != null && widget.news.fullContent!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          useNativeReader ? 'Education News' : widget.news.source,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _shareArticle,
          ),
          if (useNativeReader)
            IconButton(
              icon: const Icon(Icons.open_in_browser),
              onPressed: _launchSourceUrl,
            ),
        ],
      ),
      body: useNativeReader
          ? _buildNativeReader(context)
          : Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading)
                  const Center(child: CustomLoader()),
              ],
            ),
    );
  }

  Widget _buildNativeReader(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    // Process paragraphs
    final paragraphs = widget.news.fullContent!
        .split('\n')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

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
                        'This article was originally published on ${widget.news.source}. To read the fully formatted version with images or comments, view the original source.',
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
                        child: OutlinedButton.icon(
                          onPressed: _launchSourceUrl,
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: Text(
                            'View Original Source',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: theme.colorScheme.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
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
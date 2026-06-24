import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class RichTextLinkRenderer extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? linkStyle;

  const RichTextLinkRenderer({
    super.key,
    required this.text,
    this.style,
    this.linkStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finalStyle = style ?? theme.textTheme.bodyMedium;
    final finalLinkStyle = linkStyle ??
        theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.bold,
        );

    // Regex to match image tags/urls
    // 1. Markdown image syntax: ![alt](url)
    // 2. Bracket image tag: [image:url] or [img:url]
    // 3. Raw image URL ending with typical image extensions
    final RegExp imagePattern = RegExp(
      r'(?:!\[.*?\]\((https?://[^\s)]+)\))|'
      r'(?:\[image:(https?://[^\s\]]+)\])|'
      r'(?:\[img:(https?://[^\s\]]+)\])|'
      r'\b(https?://[^\s)]+\.(?:png|jpg|jpeg|gif|webp|svg))\b',
      caseSensitive: false,
    );

    final matches = imagePattern.allMatches(text);

    if (matches.isEmpty) {
      // If there are no images, just render the clickable text directly
      return _buildTextWithLinks(text, finalStyle, finalLinkStyle);
    }

    final List<Widget> widgets = [];
    int lastIndex = 0;

    for (final match in matches) {
      // 1. Add text before the image match
      if (match.start > lastIndex) {
        final segment = text.substring(lastIndex, match.start).trim();
        if (segment.isNotEmpty) {
          widgets.add(_buildTextWithLinks(segment, finalStyle, finalLinkStyle));
        }
      }

      // 2. Add the Image widget
      final String? imageUrl = match.group(1) ?? match.group(2) ?? match.group(3) ?? match.group(4);
      if (imageUrl != null && imageUrl.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 180,
                    width: double.infinity,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.broken_image_outlined, color: Colors.red, size: 28),
                          const SizedBox(height: 8),
                          Text(
                            'Failed to load image',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      }

      lastIndex = match.end;
    }

    // 3. Add remaining text after matches
    if (lastIndex < text.length) {
      final segment = text.substring(lastIndex).trim();
      if (segment.isNotEmpty) {
        widgets.add(_buildTextWithLinks(segment, finalStyle, finalLinkStyle));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }

  Widget _buildTextWithLinks(String rawText, TextStyle? defaultStyle, TextStyle? linkStyle) {
    final RegExp urlRegex = RegExp(r'(https?://[^\s]+)');
    final matches = urlRegex.allMatches(rawText);

    if (matches.isEmpty) {
      return Text(rawText, style: defaultStyle);
    }

    final List<TextSpan> spans = [];
    int lastMatchEnd = 0;

    for (final match in matches) {
      // Add preceding normal text
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: rawText.substring(lastMatchEnd, match.start),
          style: defaultStyle,
        ));
      }

      // Add clickable link text
      final urlString = match.group(0)!;
      spans.add(TextSpan(
        text: urlString,
        style: linkStyle,
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            final Uri? uri = Uri.tryParse(urlString);
            if (uri != null) {
              try {
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              } catch (e) {
                debugPrint('Could not launch URL: $urlString, error: $e');
              }
            }
          },
      ));

      lastMatchEnd = match.end;
    }

    // Add trailing normal text
    if (lastMatchEnd < rawText.length) {
      spans.add(TextSpan(
        text: rawText.substring(lastMatchEnd),
        style: defaultStyle,
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}

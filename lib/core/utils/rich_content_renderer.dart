import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:utme_pass_at_once/features/user/models/question_model.dart';
import 'custom_loader.dart';
import 'package:utme_pass_at_once/core/services/backend_api.dart';

/// A widget that renders a list of ContentBlockModel items natively.
/// Supports text, LaTeX math, remote/local images, and tabular data.
class RichContentRenderer extends StatelessWidget {
  final List<ContentBlockModel> blocks;
  final TextStyle? textStyle;
  final Color? iconColor;

  const RichContentRenderer({
    super.key,
    required this.blocks,
    this.textStyle,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    if (blocks.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    // Ensure the style always has a color — RichText does NOT inherit
    // DefaultTextStyle, so null color renders as white/invisible.
    final baseStyle = textStyle ??
        const TextStyle(
          fontSize: 16,
          height: 1.6,
          fontWeight: FontWeight.bold,
        );
    final defaultStyle = baseStyle.copyWith(
      color: baseStyle.color ?? theme.colorScheme.onSurface,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks.map((block) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: _buildBlock(context, block, defaultStyle, theme),
        );
      }).toList(),
    );
  }

  Widget _buildBlock(
    BuildContext context,
    ContentBlockModel block,
    TextStyle style,
    ThemeData theme,
  ) {
    try {
      switch (block.type) {
        case 'text':
          return _buildStyledText(block.value ?? '', style);

        case 'latex':
          return _buildLatexWrap(block.value ?? '', style);

        case 'image':
          final rawSrc = block.src;
          if (rawSrc == null || rawSrc.isEmpty) return const SizedBox.shrink();

          // Resolve src: if it's not http and not assets/, it is a path in
          // the public storage bucket.
          String src = rawSrc;
          final bool isRemote = rawSrc.startsWith('http');
          final bool isAsset = rawSrc.startsWith('assets/');

          if (!isRemote && !isAsset) {
            src = BackendApi.publicFileUrl(rawSrc);
          }

          final isSvg = src.toLowerCase().contains('.svg'); // Use contains because of query params

          return Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: (src.startsWith('http'))
                  ? (isSvg
                      ? SvgPicture.network(
                          src,
                          fit: BoxFit.contain,
                          placeholderBuilder: (context) =>
                              const SizedBox(height: 150, child: Center(child: CustomLoader())),
                          // Handle network SVG errors gracefully
                          errorBuilder: (context, error, stackTrace) => _buildErrorDiagram(theme),
                        )
                      : CachedNetworkImage(
                          imageUrl: src,
                          fit: BoxFit.contain,
                          placeholder: (context, url) =>
                              const SizedBox(height: 150, child: Center(child: CustomLoader())),
                          errorWidget: (context, url, error) => _buildErrorDiagram(theme),
                        ))
                  : (isSvg
                      ? SvgPicture.asset(
                          src,
                          fit: BoxFit.contain,
                          // Handle asset SVG errors gracefully
                          errorBuilder: (context, error, stackTrace) => _buildErrorDiagram(theme),
                        )
                      : Image.asset(
                          src,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => _buildErrorDiagram(theme),
                        )),
            ),
          );

        case 'table':
          return _buildTable(block, style, theme);

        default:
          return Text(
            block.plainText,
            style: style,
            softWrap: true,
            overflow: TextOverflow.visible,
          );
      }
    } catch (e) {
      debugPrint('💥 Error rendering content block: $e');
      return _buildErrorDiagram(theme);
    }
  }

  Widget _buildTable(ContentBlockModel block, TextStyle style, ThemeData theme) {
    final borderColor = theme.colorScheme.onSurface.withValues(alpha: 0.2);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder.all(color: borderColor, width: 1),
            children: [
              if (block.headers != null && block.headers!.isNotEmpty)
                TableRow(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  ),
                  children: block.headers!.map((header) {
                    return Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        header,
                        style: style.copyWith(fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                ),
              if (block.rows != null)
                ...block.rows!.map((row) {
                  return TableRow(
                    children: row.map((cell) {
                      return Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(cell, style: style),
                      );
                    }).toList(),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorDiagram(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_rounded,
            size: 40,
            color: iconColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 8),
          Text(
            'Diagram not available',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatexWrap(String latex, TextStyle style) {
    // Check for \text{} — our new format uses single backslash
    if (!latex.contains(r'\text{')) {
      // Pure math — allow horizontal scroll at readable size
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Math.tex(
          latex,
          textStyle: style,
          mathStyle: MathStyle.display,
          onErrorFallback: (err) => Text(latex, style: style.copyWith(color: Colors.red)),
        ),
      );
    }

    List<InlineSpan> spans = [];
    String mathBuffer = '';
    int depth = 0;
    int i = 0;

    void flushMath() {
      if (mathBuffer.trim().isNotEmpty) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Math.tex(
            mathBuffer.trim(),
            textStyle: style,
            mathStyle: MathStyle.text,
            onErrorFallback: (err) => Text(mathBuffer.trim(), style: style.copyWith(color: Colors.red)),
          ),
        ));
      }
      mathBuffer = '';
    }

    while (i < latex.length) {
      if (latex.startsWith(r'\text{', i) && depth == 0) {
        int startText = i + 6;
        int textDepth = 1;
        int j = startText;
        while (j < latex.length && textDepth > 0) {
          if (latex[j] == '{') {
            textDepth++;
          } else if (latex[j] == '}') {
            textDepth--;
          }
          j++;
        }

        if (textDepth == 0) {
          String textContent = latex.substring(startText, j - 1);
          if (textContent.contains(' ')) {
            flushMath();
            spans.add(TextSpan(text: textContent, style: style));
          } else {
            mathBuffer += latex.substring(i, j);
          }
          i = j;
          continue;
        }
      }

      if (latex[i] == '{') {
        depth++;
      } else if (latex[i] == '}') {
        depth--;
      }

      if (latex[i] == r'\' && i + 1 < latex.length && (latex[i+1] == '{' || latex[i+1] == '}')) {
        mathBuffer += latex.substring(i, i + 2);
        i += 2;
        continue;
      }

      mathBuffer += latex[i];
      i++;
    }

    flushMath();

    if (spans.every((span) => span is WidgetSpan)) {
      // All spans are pure math — allow horizontal scroll
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Math.tex(
          latex,
          textStyle: style,
          mathStyle: MathStyle.display,
          onErrorFallback: (err) => Text(latex, style: style.copyWith(color: Colors.red)),
        ),
      );
    }

    return RichText(
      text: TextSpan(children: spans),
      softWrap: true,
    );
  }
}

Widget _buildStyledText(String text, TextStyle defaultStyle) {
  final List<TextSpan> spans = [];
  bool isItalic = false;
  bool isUnderlined = false;

  final tagRegex = RegExp(r'(<i>|</i>|<u>|</u>)');
  final matches = tagRegex.allMatches(text);

  if (matches.isEmpty) {
    return Text(
      text,
      style: defaultStyle,
      softWrap: true,
      overflow: TextOverflow.visible,
    );
  }

  int lastIndex = 0;
  for (final match in matches) {
    if (match.start > lastIndex) {
      final segment = text.substring(lastIndex, match.start);
      spans.add(TextSpan(
        text: segment,
        style: defaultStyle.copyWith(
          fontStyle: isItalic ? FontStyle.italic : defaultStyle.fontStyle,
          decoration: isUnderlined ? TextDecoration.underline : defaultStyle.decoration,
        ),
      ));
    }

    final tag = match.group(0);
    if (tag == '<i>') {
      isItalic = true;
    } else if (tag == '</i>') {
      isItalic = false;
    } else if (tag == '<u>') {
      isUnderlined = true;
    } else if (tag == '</u>') {
      isUnderlined = false;
    }

    lastIndex = match.end;
  }

  if (lastIndex < text.length) {
    final segment = text.substring(lastIndex);
    spans.add(TextSpan(
      text: segment,
      style: defaultStyle.copyWith(
        fontStyle: isItalic ? FontStyle.italic : defaultStyle.fontStyle,
        decoration: isUnderlined ? TextDecoration.underline : defaultStyle.decoration,
      ),
    ));
  }

  return RichText(
    text: TextSpan(children: spans, style: defaultStyle),
    softWrap: true,
  );
}

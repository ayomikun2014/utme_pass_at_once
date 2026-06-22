import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class AIMessageRenderer extends StatelessWidget {
  final String text;
  final bool isMe;

  const AIMessageRenderer({super.key, required this.text, required this.isMe});

  @override
  Widget build(BuildContext context) {
    // Define the base text style based on whether it's the user's or AI's bubble
    final textStyle = TextStyle(
      fontSize: 15,
      color: isMe
          ? Colors.white
          : (Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black87),
      height: 1.4,
    );

    // We use RichText so normal words can wrap around the math equations naturally
    return RichText(text: TextSpan(children: _parseLatex(text, textStyle, context)));
  }

  List<InlineSpan> _parseLatex(String content, TextStyle style, BuildContext context) {
    final List<InlineSpan> spans = [];
    final double maxBubbleWidth = MediaQuery.of(context).size.width * 0.70; // 70% of screen width

    // Regex to match \( ... \) and \[ ... \] as well as $$ ... $$ and $ ... $
    final RegExp mathRegex = RegExp(
      r'(\\\(.*?\\\))|(\\\[.*?\\\])|(\$\$.*?\$\$)|(\$.*?\$)',
      dotAll: true,
    );
    final Iterable<Match> matches = mathRegex.allMatches(content);

    int lastMatchEnd = 0;

    for (final match in matches) {
      // 1. Add normal text before the math equation
      if (match.start > lastMatchEnd) {
        String normalText = content.substring(lastMatchEnd, match.start);
        spans.add(TextSpan(text: normalText, style: style));
      }

      // 2. Extract the math content and determine if it is inline or block
      String mathContent = match.group(0)!;
      bool isBlock = mathContent.startsWith(r'\[') || mathContent.startsWith(r'$$');

      // 3. Clean the math string by removing the delimiters
      String cleanMath = mathContent
          .replaceAll(RegExp(r'^\\\[|\\\]$'), '')
          .replaceAll(RegExp(r'^\\\(|\\\)$'), '')
          .replaceAll(RegExp(r'^\$\$|\$\$$'), '')
          .replaceAll(RegExp(r'^\$|\$$'), '');

      // 4. Add the flutter_math_fork widget as a WidgetSpan
      spans.add(
        WidgetSpan(
          // Align inline equations with the text baseline
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            // Give block equations some vertical breathing room
            padding: EdgeInsets.symmetric(vertical: isBlock ? 8.0 : 0.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Math.tex(
                  cleanMath.trim(),
                  mathStyle: isBlock ? MathStyle.display : MathStyle.text,
                  textStyle: style,
                  onErrorFallback: (FlutterMathException e) {
                    // Fallback to displaying raw text if parsing fails
                    return Text(
                      cleanMath.trim(),
                      style: style.copyWith(color: Colors.red.shade300),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      lastMatchEnd = match.end;
    }

    // 5. Add any remaining normal text after the very last equation
    if (lastMatchEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastMatchEnd), style: style));
    }

    return spans;
  }
}

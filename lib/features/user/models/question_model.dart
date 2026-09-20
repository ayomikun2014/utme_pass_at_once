// Models for the questionBank Firestore structure.
//
// Firestore path:
//   questionBank/{examType}/institutions/{institutionId}/subjects/{subjectId}/years/{year}
//
// NEW flat format:
//   question  → String with inline $latex$
//   options   → Map { 'A': { key, value } }  (value is a string with inline $latex$)
//   explanationSteps → List<String>  (each step is a string with inline $latex$)

// =============================================================================
// CONTENT BLOCK MODEL
// =============================================================================

/// A single content block used in question content, option content, or
/// explanation content. Supports text, latex, image, and table types.
class ContentBlockModel {
  final String type; // 'text', 'latex', 'image', 'table'
  final String? value; // for text/latex
  final String? format; // for image (e.g. 'svg', 'png')
  final String? src; // for image URL
  final String? alt; // for image alt text
  final List<String>? headers; // for table
  final List<List<String>>? rows; // for table

  ContentBlockModel({
    required this.type,
    this.value,
    this.format,
    this.src,
    this.alt,
    this.headers,
    this.rows,
  });

  factory ContentBlockModel.fromJson(Map<String, dynamic> json) {
    // Safely parse headers from Map to List
    List<String>? parsedHeaders;
    if (json['headers'] is Map) {
      final headersMap = Map<String, dynamic>.from(json['headers']);
      final sortedKeys = headersMap.keys.toList()..sort();
      parsedHeaders = sortedKeys.map((k) => headersMap[k].toString()).toList();
    } else if (json['headers'] is List) {
      parsedHeaders = (json['headers'] as List).map((h) => h.toString()).toList();
    }

    // Safely parse rows from Map to List<List>
    List<List<String>>? parsedRows;
    if (json['rows'] is Map) {
      final rowsMap = Map<String, dynamic>.from(json['rows']);
      final sortedRowKeys = rowsMap.keys.toList()..sort();
      parsedRows = sortedRowKeys.map((rowKey) {
        final rowItems = rowsMap[rowKey];
        if (rowItems is Map) {
          final itemsMap = Map<String, dynamic>.from(rowItems);
          final sortedItemKeys = itemsMap.keys.toList()..sort();
          return sortedItemKeys.map((k) => itemsMap[k].toString()).toList();
        } else if (rowItems is List) {
          return (rowItems).map((cell) => cell.toString()).toList();
        }
        return <String>[];
      }).toList();
    } else if (json['rows'] is List) {
      parsedRows = (json['rows'] as List).map((row) {
        return (row as List).map((cell) => cell.toString()).toList();
      }).toList();
    }

    return ContentBlockModel(
      type: (json['type'] ?? 'text').toString(),
      value: json['value']?.toString(),
      format: json['format']?.toString(),
      src: json['src']?.toString(),
      alt: json['alt']?.toString(),
      headers: parsedHeaders,
      rows: parsedRows,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'type': type};
    if (value != null) map['value'] = value;
    if (format != null) map['format'] = format;
    if (src != null) map['src'] = src;
    if (alt != null) map['alt'] = alt;
    if (headers != null) map['headers'] = headers;
    if (rows != null) map['rows'] = rows;
    return map;
  }

  /// Extract plain text representation for TTS / display fallback.
  String get plainText {
    switch (type) {
      case 'text':
      case 'latex':
        return value ?? '';
      case 'image':
        return alt ?? '[Image]';
      case 'table':
        final buffer = StringBuffer();
        if (headers != null) buffer.writeln(headers!.join(' | '));
        if (rows != null) {
          for (final row in rows!) {
            buffer.writeln(row.join(' | '));
          }
        }
        return buffer.toString().trim();
      default:
        return value ?? '';
    }
  }

  bool get isImage => type == 'image';
  bool get isTable => type == 'table';
}

// =============================================================================
// OPTION MODEL
// =============================================================================

/// A single option (A, B, C, D) with rich content blocks.
class OptionModel {
  final String key; // 'A', 'B', 'C', 'D'
  final List<ContentBlockModel> content;

  OptionModel({
    required this.key,
    required this.content,
  });

  factory OptionModel.fromJson(Map<String, dynamic> json) {
    final images = _parseImageList(json['images']);
    return OptionModel(
      key: (json['key'] ?? '').toString(),
      content: parseInlineLatexString(
        (json['value'] ?? '').toString(),
        images: images,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    final result = _blocksToInlineStringWithImages(content);
    final map = <String, dynamic>{
      'key': key,
      'value': result.text,
    };
    if (result.images.isNotEmpty) {
      map['images'] = result.images;
    }
    return map;
  }

  /// Extract plain text from all content blocks for display / TTS fallback.
  String get plainText {
    if (content.isEmpty) return '';
    return content.map((c) => c.plainText).join(' ').trim();
  }
}

// =============================================================================
// PASSAGE MODEL
// =============================================================================

class Passage {
  final String id;
  final String label;
  final String? title;
  final List<ContentBlockModel> content;
  final List<Map<String, String>> images;

  Passage({
    required this.id,
    required this.label,
    this.title,
    required this.content,
    required this.images,
  });

  factory Passage.fromJson(Map<String, dynamic> json) {
    final parsedImages = _parseImageList(json['images']);
    final rawContent = (json['content'] ?? '').toString();
    return Passage(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      title: json['title']?.toString(),
      images: parsedImages,
      content: parseInlineLatexString(rawContent, images: parsedImages),
    );
  }

  Map<String, dynamic> toJson() {
    final serialized = _blocksToInlineStringWithImages(content);
    return {
      'id': id,
      'label': label,
      'title': title,
      'content': serialized.text,
      'images': images,
    };
  }
}

// =============================================================================
// INSTRUCTION MODEL
// =============================================================================

class Instruction {
  final String id;
  final String label;
  final List<ContentBlockModel> content;

  /// Diagrams belonging to the reference itself -- a circuit or a graph that
  /// several questions are asked about. Carried the same way a passage or a
  /// question carries its images.
  final List<Map<String, String>> images;

  Instruction({
    required this.id,
    required this.label,
    required this.content,
    this.images = const [],
  });

  factory Instruction.fromJson(Map<String, dynamic> json) {
    final parsedImages = _parseImageList(json['images']);
    final rawContent = (json['content'] ?? '').toString();
    return Instruction(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      images: parsedImages,
      content: parseInlineLatexString(rawContent, images: parsedImages),
    );
  }

  Map<String, dynamic> toJson() {
    final serialized = _blocksToInlineStringWithImages(content);
    return {
      'id': id,
      'label': label,
      'content': serialized.text,
      if (images.isNotEmpty) 'images': images,
    };
  }
}

// =============================================================================
// QUESTION MODEL
// =============================================================================

class QuestionModel {
  final String id;
  final int number;
  final String examType;
  final String subject;
  final String year;
  final String? passageRef;
  final Passage? passage;
  final String? instructionRef;
  final Instruction? instruction;

  // Rich content block fields (populated from either format)
  final List<ContentBlockModel> content;
  final List<OptionModel> options;
  final String answer; // 'A', 'B', 'C', 'D'
  final List<ContentBlockModel> explanation;

  QuestionModel({
    required this.id,
    this.number = 0,
    required this.examType,
    required this.subject,
    required this.year,
    this.passageRef,
    this.passage,
    this.instructionRef,
    this.instruction,
    required this.content,
    required this.options,
    required this.answer,
    this.explanation = const [],
  });

  // ===========================================================================
  // BACKWARD-COMPATIBLE GETTERS
  // ===========================================================================

  /// Alias for [answer]
  String get correctAnswer => answer;

  /// Alias for [subject]
  String get subjectId => subject;

  /// Alias for [subject] — title-cased version for display.
  String get subjectName =>
      subject.isEmpty ? '' : '${subject[0].toUpperCase()}${subject.substring(1)}';

  /// Extract first image URL from content blocks for old UI fallbacks
  String? get imageUrl => extractFirstImageUrl(content);

  // ===========================================================================
  // JSON factories
  // ===========================================================================

  factory QuestionModel.fromJson(
    Map<String, dynamic> json, {
    required String examType,
    required String institutionId,
    required String subjectId,
    required int year,
    Map<String, Passage>? passages,
    Map<String, Instruction>? instructions,
  }) {
    final qImages = _parseImageList(json['images']);
    final expImages = _parseImageList(json['explanationImages']);
    final ref = json['passageRef']?.toString();
    final resolvedPassage = (ref != null && passages != null) ? passages[ref] : null;
    final instRef = json['instructionRef']?.toString();
    final resolvedInstruction = (instRef != null && instructions != null) ? instructions[instRef] : null;

    return QuestionModel(
      id: (json['id'] ?? '').toString(),
      number: (json['number'] as num?)?.toInt() ?? 0,
      examType: examType.toLowerCase(),
      subject: subjectId.toLowerCase(),
      year: year.toString(),
      passageRef: ref,
      passage: resolvedPassage,
      instructionRef: instRef,
      instruction: resolvedInstruction,
      content: parseInlineLatexString(
        (json['question'] ?? '').toString(),
        images: qImages,
      ),
      options: parseOptions(json['options']),
      answer: (json['answer'] ?? '').toString(),
      explanation: _parseExplanationSteps(
        json['explanationSteps'],
        images: expImages,
      ),
    );
  }

  factory QuestionModel.fromFullJson(Map<String, dynamic> json) {
    final qImages = _parseImageList(json['images']);
    final expImages = _parseImageList(json['explanationImages']);
    final ref = json['passageRef']?.toString();
    final pJson = json['passage'] as Map<String, dynamic>?;
    final resolvedPassage = pJson != null ? Passage.fromJson(pJson) : null;
    final instRef = json['instructionRef']?.toString();
    final iJson = json['instruction'] as Map<String, dynamic>?;
    final resolvedInstruction = iJson != null ? Instruction.fromJson(iJson) : null;

    return QuestionModel(
      id: (json['id'] ?? '').toString(),
      number: (json['number'] as num?)?.toInt() ?? 0,
      examType: (json['examType'] ?? '').toString().toLowerCase(),
      subject: (json['subject'] ?? json['subjectId'] ?? '').toString().toLowerCase(),
      year: (json['year'] ?? '').toString(),
      passageRef: ref,
      passage: resolvedPassage,
      instructionRef: instRef,
      instruction: resolvedInstruction,
      content: parseInlineLatexString(
        (json['question'] ?? '').toString(),
        images: qImages,
      ),
      options: parseOptions(json['options']),
      answer: (json['answer'] ?? json['correctAnswer'] ?? '').toString(),
      explanation: _parseExplanationSteps(
        json['explanationSteps'],
        images: expImages,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    final qResult = _blocksToInlineStringWithImages(content);
    final expResult = _blocksToStepsWithImages(explanation);

    final map = <String, dynamic>{
      'id': id,
      'number': number,
      'examType': examType,
      'subject': subject,
      'subjectId': subject,
      'subjectName': subjectName,
      'year': year,
      'question': qResult.text,
      'options': options.map((o) => o.toJson()).toList(),
      'answer': answer,
      'explanationSteps': expResult.steps,
      'passageRef': passageRef,
      if (passage != null) 'passage': passage!.toJson(),
      'instructionRef': instructionRef,
      if (instruction != null) 'instruction': instruction!.toJson(),
    };

    if (qResult.images.isNotEmpty) {
      map['images'] = qResult.images;
    }
    if (expResult.images.isNotEmpty) {
      map['explanationImages'] = expResult.images;
    }

    return map;
  }

  Map<String, dynamic> toMap() => toJson();
}

// =============================================================================
// NEW FORMAT HELPERS — Inline $latex$ string parsing + image markers
// =============================================================================

/// Parse an images list from JSON into a list of image maps.
List<Map<String, String>> _parseImageList(dynamic value) {
  if (value == null || value is! List) return [];
  return value.map<Map<String, String>>((img) {
    if (img is! Map) return <String, String>{};
    return {
      'src': (img['src'] ?? '').toString(),
      'alt': (img['alt'] ?? '').toString(),
      'format': (img['format'] ?? 'png').toString(),
    };
  }).where((m) => m['src']?.isNotEmpty == true).toList();
}

/// Converts a string with inline $...$ delimiters and {{IMG_N}} markers
/// into a list of ContentBlockModel.
///
/// - Pure text (no $ or {{IMG}}) → single text block
/// - Pure latex ($...$) → single latex block
/// - Mixed text+latex → single latex block with \text{} wrapping
/// - {{IMG_N}} markers → replaced with image ContentBlockModel from [images]
List<ContentBlockModel> parseInlineLatexString(
  String input, {
  List<Map<String, String>> images = const [],
  /// Add images the text never referred to with a {{IMG_N}} marker. Off for
  /// callers that parse one piece of a longer passage at a time -- otherwise
  /// every piece would repeat the same picture.
  bool appendUnreferencedImages = true,
  /// Filled with the indexes of images placed by a marker, so a caller
  /// splitting text into parts can add what is left over exactly once.
  Set<int>? referencedImages,
}) {
  if (input.isEmpty) return [];

  // First, split on image markers {{IMG_N}} to handle images
  final imgMarkerRegex = RegExp(r'\{\{IMG_(\d+)\}\}');
  final hasImageMarkers = imgMarkerRegex.hasMatch(input);

  if (!hasImageMarkers) {
    // No image markers — just parse text/latex. Any images that came with the
    // text still belong to it (a diagram attached to a reference, say), so
    // they follow the words rather than being dropped.
    final blocks = _parseTextLatex(input);
    if (appendUnreferencedImages) {
      for (final image in images) {
        blocks.add(ContentBlockModel(
          type: 'image',
          src: image['src'],
          alt: image['alt'],
          format: image['format'],
        ));
      }
    }
    return blocks;
  }

  // Split on image markers and interleave text + image blocks
  final blocks = <ContentBlockModel>[];
  int lastEnd = 0;

  for (final match in imgMarkerRegex.allMatches(input)) {
    // Parse the text segment before this image marker
    final textBefore = input.substring(lastEnd, match.start);
    if (textBefore.trim().isNotEmpty) {
      blocks.addAll(_parseTextLatex(textBefore));
    }

    // Insert the image block
    final imgIndex = int.tryParse(match.group(1)!) ?? -1;
    if (imgIndex >= 0 && imgIndex < images.length) {
      referencedImages?.add(imgIndex);
      blocks.add(ContentBlockModel(
        type: 'image',
        src: images[imgIndex]['src'],
        alt: images[imgIndex]['alt'],
        format: images[imgIndex]['format'],
      ));
    }

    lastEnd = match.end;
  }

  // Parse any remaining text after the last image marker
  if (lastEnd < input.length) {
    final remaining = input.substring(lastEnd);
    if (remaining.trim().isNotEmpty) {
      blocks.addAll(_parseTextLatex(remaining));
    }
  }

  return blocks;
}

/// Internal: parse a text segment that may contain inline $...$ LaTeX.
List<ContentBlockModel> _parseTextLatex(String input) {
  if (input.isEmpty) return [];

  // No inline latex at all → pure text block
  if (!input.contains('\$')) {
    return [ContentBlockModel(type: 'text', value: input)];
  }

  final regex = RegExp(r'\$([^$]+)\$');
  final matches = regex.allMatches(input).toList();

  if (matches.isEmpty) {
    return [ContentBlockModel(type: 'text', value: input)];
  }

  // Entire string is a single $...$ block
  if (matches.length == 1 &&
      matches[0].start == 0 &&
      matches[0].end == input.length) {
    return [ContentBlockModel(type: 'latex', value: matches[0].group(1)!)];
  }

  // Mixed text + latex → build a single latex block with \text{} wrapping
  final buffer = StringBuffer();
  int lastEnd = 0;

  for (final match in matches) {
    if (match.start > lastEnd) {
      final text = input.substring(lastEnd, match.start);
      if (text.isNotEmpty) {
        buffer.write('\\text{$text}');
      }
    }
    buffer.write(match.group(1));
    lastEnd = match.end;
  }

  if (lastEnd < input.length) {
    final remaining = input.substring(lastEnd);
    if (remaining.isNotEmpty) {
      buffer.write('\\text{$remaining}');
    }
  }

  return [ContentBlockModel(type: 'latex', value: buffer.toString())];
}

/// Parse explanationSteps (`List<String>`) into `List<ContentBlockModel>`.
/// Each step becomes one or more ContentBlockModels via parseInlineLatexString.
/// Image markers reference the [images] array.
List<ContentBlockModel> _parseExplanationSteps(
  dynamic steps, {
  List<Map<String, String>> images = const [],
}) {
  if (steps == null) return [];
  if (steps is! List) return [];

  // The steps are parsed one at a time, so the images are held back until the
  // end: handing them to every step would show the same diagram once per step.
  final blocks = <ContentBlockModel>[];
  final referenced = <int>{};
  // One diagram belongs to the explanation once, however many steps mention
  // it. This also cleans up explanations already saved with a repeat.
  final seenImages = <String>{};
  void addBlock(ContentBlockModel block) {
    if (block.isImage) {
      final src = (block.src ?? '').trim();
      if (src.isNotEmpty && !seenImages.add(src)) return;
    }
    blocks.add(block);
  }

  for (final step in steps) {
    final stepStr = step.toString().trim();
    if (stepStr.isEmpty) continue;
    parseInlineLatexString(
      stepStr,
      images: images,
      appendUnreferencedImages: false,
      referencedImages: referenced,
    ).forEach(addBlock);
  }

  // Whatever no step pointed at belongs to the explanation as a whole.
  for (var i = 0; i < images.length; i++) {
    if (referenced.contains(i)) continue;
    addBlock(ContentBlockModel(
      type: 'image',
      src: images[i]['src'],
      alt: images[i]['alt'],
      format: images[i]['format'],
    ));
  }
  return blocks;
}

/// Result of converting content blocks back to an inline string + image list.
class _SerializedContent {
  final String text;
  final List<Map<String, String>> images;
  _SerializedContent(this.text, this.images);
}

/// Result of converting explanation blocks back to steps + image list.
class _SerializedExplanation {
  final List<String> steps;
  final List<Map<String, String>> images;
  _SerializedExplanation(this.steps, this.images);
}

/// Convert content blocks back to an inline string with {{IMG_N}} markers.
_SerializedContent _blocksToInlineStringWithImages(List<ContentBlockModel> blocks) {
  if (blocks.isEmpty) return _SerializedContent('', []);

  final buffer = StringBuffer();
  final images = <Map<String, String>>[];

  for (final block in blocks) {
    if (block.type == 'image') {
      final imgIndex = images.length;
      buffer.write('{{IMG_$imgIndex}}');
      images.add({
        'src': block.src ?? '',
        'alt': block.alt ?? '',
        'format': block.format ?? 'png',
      });
    } else if (block.type == 'latex' && block.value != null) {
      if (block.value!.contains('\\text{')) {
        buffer.write(_latexBlockToInlineString(block.value!));
      } else {
        buffer.write('\$${block.value}\$');
      }
    } else if (block.type == 'text' && block.value != null) {
      buffer.write(block.value);
    }
  }

  return _SerializedContent(buffer.toString(), images);
}

/// Convert explanation blocks back to step strings + image list.
_SerializedExplanation _blocksToStepsWithImages(List<ContentBlockModel> blocks) {
  if (blocks.isEmpty) return _SerializedExplanation([], []);

  final steps = <String>[];
  final images = <Map<String, String>>[];

  for (final block in blocks) {
    if (block.type == 'image') {
      final imgIndex = images.length;
      steps.add('{{IMG_$imgIndex}}');
      images.add({
        'src': block.src ?? '',
        'alt': block.alt ?? '',
        'format': block.format ?? 'png',
      });
    } else if (block.type == 'latex' && block.value != null) {
      if (block.value!.contains('\\text{')) {
        steps.add(_latexBlockToInlineString(block.value!));
      } else {
        steps.add('\$${block.value}\$');
      }
    } else if (block.type == 'text' && block.value != null) {
      if (block.value!.isNotEmpty) {
        steps.add(block.value!);
      }
    }
  }

  return _SerializedExplanation(steps, images);
}

/// Convert a latex string with \text{} back into inline $...$ format.
String _latexBlockToInlineString(String latex) {
  final buffer = StringBuffer();
  int i = 0;
  String mathBuffer = '';

  while (i < latex.length) {
    if (latex.startsWith('\\text{', i)) {
      if (mathBuffer.trim().isNotEmpty) {
        buffer.write('\$${mathBuffer.trim()}\$');
      }
      mathBuffer = '';

      int depth = 1;
      int start = i + 6;
      int j = start;
      while (j < latex.length && depth > 0) {
        if (latex[j] == '{') depth++;
        if (latex[j] == '}') depth--;
        j++;
      }
      buffer.write(latex.substring(start, j - 1));
      i = j;
    } else {
      mathBuffer += latex[i];
      i++;
    }
  }

  if (mathBuffer.trim().isNotEmpty) {
    buffer.write('\$${mathBuffer.trim()}\$');
  }

  return buffer.toString();
}



/// Safely parse a list of OptionModel from a dynamic value (List or Map).
List<OptionModel> parseOptions(dynamic value) {
  if (value == null) return [];
  final result = <OptionModel>[];

  if (value is Map) {
    // Firestore Map format: {'A': {...}, 'B': {...}}
    final entries = value.entries.toList();
    entries.sort((a, b) => a.key.compareTo(b.key));

    for (final entry in entries) {
      if (entry.value is Map) {
        result.add(OptionModel.fromJson(Map<String, dynamic>.from(entry.value)));
      }
    }
  } else if (value is List) {
    final labels = ['A', 'B', 'C', 'D', 'E', 'F'];
    for (int i = 0; i < value.length; i++) {
      final item = value[i];
      if (item is Map) {
        result.add(OptionModel.fromJson(Map<String, dynamic>.from(item)));
      } else if (item is String) {
        final key = i < labels.length ? labels[i] : '${i + 1}';
        result.add(OptionModel(
          key: key,
          content: parseInlineLatexString(item),
        ));
      }
    }
  }

  return result;
}

String extractPlainText(List<ContentBlockModel> blocks) {
  if (blocks.isEmpty) return '';
  return blocks.map((b) => b.plainText).where((t) => t.isNotEmpty).join(' ');
}

String? extractFirstImageUrl(List<ContentBlockModel> blocks) {
  for (final block in blocks) {
    if (block.isImage && block.src != null && block.src!.isNotEmpty) {
      return block.src;
    }
  }
  return null;
}

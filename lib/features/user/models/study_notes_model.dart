class StudySubjectModel {
  final String subjectId;
  final String subjectName;
  final Map<String, StudyTopicModel> topics;

  StudySubjectModel({
    required this.subjectId,
    required this.subjectName,
    required this.topics,
  });

  factory StudySubjectModel.fromMap(Map<String, dynamic> map, String id) {
    final topicsMap = Map<String, dynamic>.from(map['topics'] ?? {});
    final topics = topicsMap.map((key, value) => MapEntry(
          key,
          StudyTopicModel.fromMap(Map<String, dynamic>.from(value), key),
        ));

    return StudySubjectModel(
      subjectId: id,
      subjectName: map['subjectName'] ?? 'Unknown Subject',
      topics: topics,
    );
  }
}

class StudyTopicModel {
  final String topicId;
  final String title;
  final int sourcePage;
  final List<StudyContentBlockModel> content;

  StudyTopicModel({
    required this.topicId,
    required this.title,
    required this.sourcePage,
    required this.content,
  });

  factory StudyTopicModel.fromMap(Map<String, dynamic> map, String id) {
    final content = _convertMapToList(
      map['content'],
      (item) => StudyContentBlockModel.fromMap(Map<String, dynamic>.from(item)),
    );

    return StudyTopicModel(
      topicId: id,
      title: map['title'] ?? 'Untitled Topic',
      sourcePage: map['sourcePage'] ?? 1,
      content: content,
    );
  }
}

class StudyContentBlockModel {
  final String type; // paragraph, bullet, latex, table
  final String? text; // for paragraph
  final List<String>? items; // for bullet
  final String? value; // for latex
  final List<String>? headers; // for table
  final List<List<String>>? rows; // for table

  StudyContentBlockModel({
    required this.type,
    this.text,
    this.items,
    this.value,
    this.headers,
    this.rows,
  });

  factory StudyContentBlockModel.fromMap(Map<String, dynamic> map) {
    return StudyContentBlockModel(
      type: map['type'] ?? 'paragraph',
      text: map['text'],
      items: map['items'] != null
          ? _convertMapToList(map['items'], (item) => item.toString())
          : null,
      value: map['value'],
      headers: map['headers'] != null
          ? _convertMapToList(map['headers'], (item) => item.toString())
          : null,
      rows: map['rows'] != null
          ? _convertMapToList(
              map['rows'],
              (row) => _convertMapToList(row, (cell) => cell.toString()),
            )
          : null,
    );
  }
}

List<T> _convertMapToList<T>(dynamic value, T Function(dynamic) mapper) {
  if (value == null) return [];
  if (value is List) return value.map(mapper).toList();
  if (value is Map) {
    final keys = value.keys.toList()
      ..sort((a, b) {
        final aNum =
            int.tryParse(RegExp(r'\d+').stringMatch(a.toString()) ?? '0') ?? 0;
        final bNum =
            int.tryParse(RegExp(r'\d+').stringMatch(b.toString()) ?? '0') ?? 0;
        return aNum.compareTo(bNum);
      });
    return keys.map((k) => mapper(value[k])).toList();
  }
  return [];
}

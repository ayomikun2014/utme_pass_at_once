class NewsModel {
  final String title;
  final String description;
  final String imageUrl;
  final String link;
  final String source;
  final String pubDate;
  final String? fullContent;

  /// Whether [fullContent] is the article itself rather than a summary of it.
  ///
  /// The news feed only hands over full articles on its paid plan; on the free
  /// one it sends the publisher's summary, and the story is read on their
  /// site. The reader says which it is showing instead of pretending.
  final bool hasFullStory;

  NewsModel({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.link,
    required this.source,
    required this.pubDate,
    this.fullContent,
    this.hasFullStory = false,
  });

  /// The feed puts its own advertisement where an article should be; anything
  /// stored before that was noticed still carries it.
  static String? _realText(dynamic value) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();
    if (lower.startsWith('only available in') || lower == '[removed]' || lower == 'null') {
      return null;
    }
    return text;
  }

  /// The best text there is for this story.
  String get body {
    final full = _realText(fullContent);
    if (full != null) return full;
    final summary = _realText(description);
    return summary ?? title;
  }

  // Keep this: It's used for fetching from the News API
  factory NewsModel.fromJson(Map<String, dynamic> json) {
    return NewsModel(
      title: json['title'] ?? 'No Title',
      description: json['description'] ?? 'Read the full article online.',
      imageUrl: json['image_url'] ?? 'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?q=80&w=800&auto=format&fit=crop',
      link: json['link'] ?? '',
      source: json['source_id']?.toString().toUpperCase() ?? 'NEWS',
      pubDate: json['pubDate'] ?? '',
      fullContent: _realText(json['content'] ?? json['fullContent']),
      hasFullStory: json['hasFullStory'] == true,
    );
  }

  // Keep this: It's used for reading from your Firestore database
  factory NewsModel.fromMap(Map<String, dynamic> map) {
    return NewsModel(
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      link: map['link'] ?? '',
      source: map['source'] ?? '',
      pubDate: map['pubDate'] ?? '',
      fullContent: _realText(map['fullContent']),
      hasFullStory: map['hasFullStory'] == true,
    );
  }

  // Keep this: It saves data to Firestore with the syncedAt timestamp
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'link': link,
      'source': source,
      'pubDate': pubDate,
      'fullContent': fullContent,
      'hasFullStory': hasFullStory,
      'syncedAt': DateTime.now().toIso8601String(),
    };
  }
}
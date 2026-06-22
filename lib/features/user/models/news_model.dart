class NewsModel {
  final String title;
  final String description;
  final String imageUrl;
  final String link;
  final String source;
  final String pubDate;
  final String? fullContent;

  NewsModel({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.link,
    required this.source,
    required this.pubDate,
    this.fullContent,
  });

  // Keep this: It's used for fetching from the News API
  factory NewsModel.fromJson(Map<String, dynamic> json) {
    return NewsModel(
      title: json['title'] ?? 'No Title',
      description: json['description'] ?? 'Read the full article online.',
      imageUrl: json['image_url'] ?? 'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?q=80&w=800&auto=format&fit=crop',
      link: json['link'] ?? '',
      source: json['source_id']?.toString().toUpperCase() ?? 'NEWS',
      pubDate: json['pubDate'] ?? '',
      fullContent: json['content'] ?? json['fullContent'],
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
      fullContent: map['fullContent'],
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
      'syncedAt': DateTime.now().toIso8601String(),
    };
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';

class VideoModel {
  final String id;
  final String title;
  final String description;
  final String subject;
  final String track; // 'science' or 'art'
  final String url;
  final String duration;
  final DateTime createdAt;

  VideoModel({
    required this.id,
    required this.title,
    required this.description,
    required this.subject,
    required this.track,
    required this.url,
    required this.duration,
    required this.createdAt,
  });

  factory VideoModel.fromMap(String docId, Map<String, dynamic> map) {
    DateTime parsedDate;
    final dynamic rawCreated = map['createdAt'];
    if (rawCreated is Timestamp) {
      parsedDate = rawCreated.toDate();
    } else if (rawCreated is String) {
      parsedDate = DateTime.tryParse(rawCreated) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return VideoModel(
      id: docId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      subject: (map['subject'] ?? '').toString().toLowerCase(),
      track: (map['track'] ?? 'science').toString().toLowerCase(),
      url: map['url'] ?? '',
      duration: map['duration'] ?? '',
      createdAt: parsedDate,
    );
  }

  /// The eleven-character YouTube id inside [url], or '' when the link is not
  /// one this app can play. Handles youtu.be links, watch links, shorts,
  /// embeds, a bare id, and links typed without their "h".
  String get youtubeId {
    var clean = url.trim();
    if (clean.isEmpty) return '';
    if (clean.startsWith('ttps://')) {
      clean = 'https://${clean.substring(7)}';
    } else if (clean.startsWith('ttp://')) {
      clean = 'http://${clean.substring(6)}';
    }
    if (RegExp(r'^[\w-]{11}$').hasMatch(clean)) return clean;

    final match = RegExp(
      r'(?:youtu\.be\/|youtube(?:-nocookie)?\.com\/(?:embed\/|v\/|shorts\/|live\/|watch\?(?:.*&)?v=))([\w-]{11})',
      caseSensitive: false,
    ).firstMatch(clean);
    return match?.group(1) ?? '';
  }

  bool get isPlayable => youtubeId.isNotEmpty;

  /// YouTube's own still for this video.
  String get thumbnailUrl =>
      isPlayable ? 'https://img.youtube.com/vi/$youtubeId/hqdefault.jpg' : '';

  /// The page to open when the video will not play inside the app.
  String get watchUrl =>
      isPlayable ? 'https://www.youtube.com/watch?v=$youtubeId' : url;

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'subject': subject,
      'track': track,
      'url': url,
      'duration': duration,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

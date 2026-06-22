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

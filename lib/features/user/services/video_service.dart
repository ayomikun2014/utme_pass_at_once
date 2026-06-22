import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/services/network_service.dart';
import '../models/video_model.dart';

class VideoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<VideoModel>> fetchAllVideos() async {
    try {
      final isOnline = await NetworkService.instance.hasInternet();
      final Source source = isOnline ? Source.server : Source.cache;

      final query = _firestore.collection('videos').orderBy('createdAt', descending: true);
      final snapshot = await query.get(GetOptions(source: source));

      return snapshot.docs
          .map((doc) => VideoModel.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint("Video Service Fetch Error: $e");

      // Robust fallback to local cache
      try {
        debugPrint("Video Service: Falling back to local offline cache...");
        final snapshot = await _firestore.collection('videos')
            .orderBy('createdAt', descending: true)
            .get(const GetOptions(source: Source.cache));

        return snapshot.docs
            .map((doc) => VideoModel.fromMap(doc.id, doc.data()))
            .toList();
      } catch (cacheErr) {
        debugPrint("Video Service: Cache fallback failed: $cacheErr");
        return [];
      }
    }
  }
}

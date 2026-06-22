import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/services/network_service.dart';
import '../models/news_model.dart';

class NewsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  Future<List<NewsModel>> fetchNews({bool loadMore = false}) async {
    try {
      final isOnline = await NetworkService.instance.hasInternet();
      final Source source = isOnline ? Source.server : Source.cache;

      if (!loadMore) {
        _lastDocument = null;
        _hasMore = true;
      }

      if (!_hasMore) return [];

      Query<Map<String, dynamic>> query = _firestore.collection('news')
          .orderBy('syncedAt', descending: true)
          .limit(10);

      if (loadMore && _lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      // Fetch from the determined source (server when online, cache when offline)
      final snapshot = await query.get(GetOptions(source: source));

      if (snapshot.docs.length < 10) _hasMore = false;
      if (snapshot.docs.isNotEmpty) _lastDocument = snapshot.docs.last;

      return snapshot.docs
          .map((doc) => NewsModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint("News Fetch Error: $e");
      
      // Graceful fallback to cache if a network request fails (e.g. transient timeout)
      try {
        if (loadMore) return [];
        
        debugPrint("News Service: Retrying cache fallback after error...");
        final snapshot = await _firestore.collection('news')
            .orderBy('syncedAt', descending: true)
            .limit(10)
            .get(const GetOptions(source: Source.cache));
            
        return snapshot.docs
            .map((doc) => NewsModel.fromMap(doc.data()))
            .toList();
      } catch (cacheErr) {
        debugPrint("News Service: Cache fallback failed: $cacheErr");
        return [];
      }
    }
  }
}
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/video_model.dart';

class VideoProvider extends ChangeNotifier {
  StreamSubscription<QuerySnapshot>? _videoSubscription;

  List<VideoModel> _allVideos = [];
  bool _isLoading = false;
  String _selectedTrack = 'all'; // 'all', 'science', 'art'
  List<String> _favoritedVideoIds = [];

  static const String _videosCacheKey = 'cached_all_videos';

  List<VideoModel> get allVideos => _allVideos;
  bool get isLoading => _isLoading;
  String get selectedTrack => _selectedTrack;
  List<String> get favoritedVideoIds => _favoritedVideoIds;

  VideoProvider() {
    _initializeSettings();
  }
  Future<void> _initializeSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _selectedTrack = prefs.getString('videos_last_selected_track') ?? 'all';
      _favoritedVideoIds = prefs.getStringList('favorite_video_ids') ?? [];

      // Load cached videos from SharedPreferences first
      final String? cachedJson = prefs.getString(_videosCacheKey);
      if (cachedJson != null) {
        final List decoded = jsonDecode(cachedJson);
        _allVideos = decoded.map((e) {
          final map = Map<String, dynamic>.from(e);
          return VideoModel.fromMap(map['id'] ?? '', map);
        }).toList();
        _isLoading = false;
        notifyListeners();
      }

      _startVideoListener();
    } catch (e) {
      debugPrint("Error initializing VideoProvider settings: $e");
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveCachedVideos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_allVideos.map((v) => {
        'id': v.id,
        'title': v.title,
        'description': v.description,
        'subject': v.subject,
        'track': v.track,
        'url': v.url,
        'duration': v.duration,
        'createdAt': v.createdAt.toIso8601String(),
      }).toList());
      await prefs.setString(_videosCacheKey, jsonStr);
    } catch (e) {
      debugPrint("Error saving cached videos: $e");
    }
  }

  void _startVideoListener() {
    _videoSubscription?.cancel();
    _isLoading = true;
    notifyListeners();

    _videoSubscription = FirebaseFirestore.instance
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) async {
      _allVideos = snapshot.docs
          .map((doc) => VideoModel.fromMap(doc.id, doc.data()))
          .toList();
      _isLoading = false;
      notifyListeners();
      await _saveCachedVideos();
    }, onError: (err) {
      // The list already on screen came from the local cache, so a dropped
      // stream leaves the reader with videos rather than an empty page.
      debugPrint("Video stream error: $err");
      _isLoading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _videoSubscription?.cancel();
    super.dispose();
  }

  Future<void> setTrack(String track) async {
    if (_selectedTrack == track) return;
    _selectedTrack = track;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('videos_last_selected_track', track);
    } catch (e) {
      debugPrint("Error saving track preference: $e");
    }
  }

  Future<void> toggleFavorite(String videoId) async {
    if (_favoritedVideoIds.contains(videoId)) {
      _favoritedVideoIds.remove(videoId);
    } else {
      _favoritedVideoIds.add(videoId);
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('favorite_video_ids', _favoritedVideoIds);
    } catch (e) {
      debugPrint("Error saving favorites list: $e");
    }
  }

  bool isFavorited(String videoId) {
    return _favoritedVideoIds.contains(videoId);
  }

  // --- Dynamic Filtering Helpers ---

  /// Returns unique subjects matching the selected track (Science/Art) and search query
  List<String> getSubjectsForSelectedTrack({String search = ''}) {
    final query = search.trim().toLowerCase();
    final Set<String> subjects = {};

    for (final video in _allVideos) {
      // Filter by track first
      if (_selectedTrack != 'all' && video.track != _selectedTrack) {
        continue;
      }
      
      final subject = video.subject;
      if (query.isNotEmpty && !subject.contains(query)) {
        continue;
      }
      
      if (subject.isNotEmpty) {
        subjects.add(subject);
      }
    }

    final list = subjects.toList();
    list.sort();
    return list;
  }

  /// Returns all videos for a given subject under the active track, optional keyword search
  List<VideoModel> getVideosForSubject(String subject, {String search = ''}) {
    final query = search.trim().toLowerCase();
    final subjectKey = subject.toLowerCase();

    return _allVideos.where((v) {
      if (v.subject != subjectKey) return false;
      if (_selectedTrack != 'all' && v.track != _selectedTrack) return false;
      if (query.isNotEmpty) {
        final matchesTitle = v.title.toLowerCase().contains(query);
        final matchesDesc = v.description.toLowerCase().contains(query);
        return matchesTitle || matchesDesc;
      }
      return true;
    }).toList();
  }

  /// Returns only favorited videos for a given subject
  List<VideoModel> getFavoritesForSubject(String subject, {String search = ''}) {
    final list = getVideosForSubject(subject, search: search);
    return list.where((v) => _favoritedVideoIds.contains(v.id)).toList();
  }
}

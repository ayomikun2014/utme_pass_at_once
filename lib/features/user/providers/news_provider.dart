import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/news_model.dart';
import '../services/news_service.dart';

class NewsProvider extends ChangeNotifier {
  final NewsService _newsService = NewsService();

  List<NewsModel> _newsList = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;

  static const String _newsCacheKey = 'cached_news';

  List<NewsModel> get newsList => _newsList;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _newsService.hasMore;

  NewsModel? get featuredNews => _newsList.isNotEmpty ? _newsList.first : null;
  List<NewsModel> get remainingNews => _newsList.length > 1 ? _newsList.sublist(1) : [];

  NewsProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadCachedNews();
    await loadNews();
  }

  Future<void> _loadCachedNews() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_newsCacheKey);
      if (jsonStr != null) {
        final List decoded = jsonDecode(jsonStr);
        _newsList = decoded.map((e) => NewsModel.fromMap(Map<String, dynamic>.from(e))).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading cached news: $e");
    }
  }

  Future<void> _saveCachedNews() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_newsList.map((e) => e.toMap()).toList());
      await prefs.setString(_newsCacheKey, jsonStr);
    } catch (e) {
      debugPrint("Error saving cached news: $e");
    }
  }

  Future<void> loadNews() async {
    _isLoading = true;
    notifyListeners();

    try {
      final fetched = await _newsService.fetchNews(loadMore: false);
      if (fetched.isNotEmpty) {
        _newsList = fetched;
        await _saveCachedNews();
      }
    } catch (e) {
      debugPrint("Error loading news: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreNews() async {
    if (_isLoading || _isLoadingMore || !hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final moreNews = await _newsService.fetchNews(loadMore: true);
      _newsList.addAll(moreNews);
      await _saveCachedNews();
    } catch (e) {
      debugPrint("Error loading more news: $e");
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> refreshNews() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Force reload from top
      final fetched = await _newsService.fetchNews(loadMore: false);
      if (fetched.isNotEmpty) {
        _newsList = fetched;
        await _saveCachedNews();
      }
    } catch (e) {
      debugPrint("Error refreshing news: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
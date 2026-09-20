import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../../core/config/hive_setup.dart';
import '../models/announcement_model.dart';
import '../services/announcement_service.dart';

class AnnouncementProvider with ChangeNotifier {
  final AnnouncementService _service = AnnouncementService();
  List<AnnouncementModel> _announcements = [];
  bool _isLoading = false;

  List<AnnouncementModel> get announcements => _announcements;
  bool get isLoading => _isLoading;

  static const String _hiveKey = 'last_seen_announcement_id';
  static const String _cachedAnnouncementsKey = 'cached_announcements';

  AnnouncementProvider() {
    _loadFromCache();
  }

  void _loadFromCache() {
    try {
      final settingsBox = Hive.box(HiveSetup.settingsBoxName);
      final String? data = settingsBox.get(_cachedAnnouncementsKey);
      if (data != null && data.isNotEmpty) {
        final List<dynamic> decoded = json.decode(data);
        _announcements = decoded
            .map((item) => AnnouncementModel.fromLocalMap(Map<String, dynamic>.from(item)))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cached announcements: $e');
    }
  }

  Future<void> fetchAnnouncements() async {
    _isLoading = true;
    notifyListeners();

    try {
      final freshList = await _service.getLatestAnnouncements(limit: 100);
      if (freshList.isNotEmpty) {
        _announcements = freshList;
        // Save to cache
        try {
          final settingsBox = Hive.box(HiveSetup.settingsBoxName);
          final serialized = freshList.map((ann) => ann.toLocalMap()).toList();
          await settingsBox.put(_cachedAnnouncementsKey, json.encode(serialized));
        } catch (e) {
          debugPrint('Error saving announcements to cache: $e');
        }
      }
    } catch (e) {
      debugPrint('Error fetching announcements: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Checks if there are any unseen announcements and returns them (up to 5).
  List<AnnouncementModel> getUnseenAnnouncements() {
    if (_announcements.isEmpty) return [];

    final settingsBox = Hive.box(HiveSetup.settingsBoxName);
    final String? lastSeenId = settingsBox.get(_hiveKey);

    if (lastSeenId == null) {
      // For a new user, all existing announcements in Firebase are treated as "past" announcements.
      // We save the latest announcement's ID to Hive immediately so they don't get popups on startup.
      // All of these announcements remain fully accessible in the announcements screen.
      settingsBox.put(_hiveKey, _announcements.first.id);
      return [];
    }

    // Check if the latest announcement in our list is different from the last seen ID.
    if (_announcements.first.id == lastSeenId) {
      return [];
    }

    // Find all announcements that are newer than the last seen one
    final List<AnnouncementModel> unseen = [];
    for (final ann in _announcements) {
      if (ann.id == lastSeenId) {
        break; // Stop when we hit the last seen one (older ones are also seen)
      }
      unseen.add(ann);
      if (unseen.length >= 5) break; // Limit to max 5
    }

    return unseen;
  }

  /// Marks all current announcements as seen by storing the latest announcement ID in Hive.
  void markAllAsSeen() {
    if (_announcements.isEmpty) return;
    final settingsBox = Hive.box(HiveSetup.settingsBoxName);
    settingsBox.put(_hiveKey, _announcements.first.id);
  }
}

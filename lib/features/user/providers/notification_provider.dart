import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../../../core/services/network_service.dart';

class NotificationProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  int _unreadCount = 0;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _unreadCount;

  // Stream of notifications for real-time updates
  Stream<List<NotificationModel>> getNotificationStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
          .toList();
      
      _notifications = list;
      _unreadCount = list.where((n) => !n.isRead).length;
      // We don't call notifyListeners() here because it's a stream used by a StreamBuilder
      // but we update the local count for other UI elements.
      return list;
    });
  }

  Future<void> fetchNotifications(String uid) async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .get(GetOptions(source: NetworkService.instance.isOnline ? Source.serverAndCache : Source.cache));

      _notifications = snapshot.docs
          .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
          .toList();
      
      _unreadCount = _notifications.where((n) => !n.isRead).length;
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String uid, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
      
      // Update local state
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = NotificationModel(
          id: _notifications[index].id,
          title: _notifications[index].title,
          body: _notifications[index].body,
          type: _notifications[index].type,
          createdAt: _notifications[index].createdAt,
          isRead: true,
          payload: _notifications[index].payload,
        );
        _unreadCount = _notifications.where((n) => !n.isRead).length;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead(String uid) async {
    try {
      final batch = _firestore.batch();
      final unreadDocs = await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in unreadDocs.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      
      // Update local state
      _notifications = _notifications.map((n) => NotificationModel(
        id: n.id,
        title: n.title,
        body: n.body,
        type: n.type,
        createdAt: n.createdAt,
        isRead: true,
        payload: n.payload,
      )).toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  Future<void> markCategoryNotificationsAsRead({
    required String uid,
    required String adminId,
    required List<String> types,
  }) async {
    try {
      final query = await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      bool hasUpdates = false;

      for (var doc in query.docs) {
        final data = doc.data();
        final type = data['type'] as String? ?? '';
        final payload = data['payload'] as Map<String, dynamic>?;
        final notifAdminId = payload?['adminId'] ?? payload?['centerId'] ?? '';

        if (types.contains(type) && notifAdminId == adminId) {
          batch.update(doc.reference, {'isRead': true});
          hasUpdates = true;

          // Update local state
          final idx = _notifications.indexWhere((n) => n.id == doc.id);
          if (idx != -1) {
            _notifications[idx] = NotificationModel(
              id: _notifications[idx].id,
              title: _notifications[idx].title,
              body: _notifications[idx].body,
              type: _notifications[idx].type,
              createdAt: _notifications[idx].createdAt,
              isRead: true,
              payload: _notifications[idx].payload,
            );
          }
        }
      }

      if (hasUpdates) {
        await batch.commit();
        _unreadCount = _notifications.where((n) => !n.isRead).length;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error marking category notifications as read: $e');
    }
  }

  Future<void> deleteNotification(String uid, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(notificationId)
          .delete();
      
      _notifications.removeWhere((n) => n.id == notificationId);
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  Future<void> clearAll(String uid) async {
    try {
      final batch = _firestore.batch();
      final allDocs = await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .get();

      for (var doc in allDocs.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      
      _notifications.clear();
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
    }
  }
}

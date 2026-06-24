import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/announcement_model.dart';

class AnnouncementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<AnnouncementModel>> getLatestAnnouncements({int limit = 5}) async {
    final snapshot = await _firestore
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => AnnouncementModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Stream<List<AnnouncementModel>> streamLatestAnnouncements() {
    return _firestore
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AnnouncementModel.fromMap(doc.data(), doc.id))
            .toList());
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:utme_pass_at_once/features/user/models/study_notes_model.dart';
import 'package:utme_pass_at_once/core/services/network_service.dart';

class StudyNotesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// The single document every study note now lives under.
  ///
  /// Notes used to be split per exam -- `jamb_study_note`, `post_utme_oau` and
  /// so on -- and reached from each exam's dashboard. They are one global list
  /// now, opened from the Home and More quick links, so there is nothing to
  /// route on.
  static const String _docId = 'general';

  Future<List<StudySubjectModel>> fetchStudyNotes() async {
    final source = NetworkService.instance.isOnline
        ? Source.serverAndCache
        : Source.cache;

    final snapshot = await _firestore
        .collection('study_notes')
        .doc(_docId)
        .collection('subjects')
        .get(GetOptions(source: source));

    return snapshot.docs.map((doc) {
      return StudySubjectModel.fromMap(doc.data(), doc.id);
    }).toList();
  }
}

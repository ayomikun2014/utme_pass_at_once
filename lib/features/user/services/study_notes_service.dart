import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:utme_pass_at_once/features/user/models/study_notes_model.dart';
import 'package:utme_pass_at_once/core/services/network_service.dart';

class StudyNotesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<StudySubjectModel>> fetchStudyNotes({
    required String examType,
    String? institutionId,
  }) async {
    final source = NetworkService.instance.isOnline ? Source.serverAndCache : Source.cache;

    // Dynamically route to the correct study notes document
    String docId = examType.toLowerCase();

    // If it's Post-UTME, append the specific institution ID (e.g., 'post_utme_oau')
    if (docId == 'post_utme' && institutionId != null) {
      String baseInstitutionId = institutionId.toLowerCase();
      if (baseInstitutionId.contains('_')) {
        baseInstitutionId = baseInstitutionId.split('_').first;
      }
      docId = '${docId}_$baseInstitutionId';
    }

    final snapshot = await _firestore
        .collection('study_notes')
        .doc(docId)
        .collection('subjects')
        .get(GetOptions(source: source));

    return snapshot.docs.map((doc) {
      return StudySubjectModel.fromMap(doc.data(), doc.id);
    }).toList();
  }
}
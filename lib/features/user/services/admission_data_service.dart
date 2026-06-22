import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:utme_pass_at_once/features/user/models/admission_guideline_model.dart';
import 'package:utme_pass_at_once/core/services/network_service.dart';

class AdmissionDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Extracts the base institution ID by stripping the section suffix.
  /// e.g. "oau_science" → "oau", "unilag_arts" → "unilag", "jamb" → "jamb"
  String _getBaseInstitutionId(String institutionId) {
    if (institutionId.contains('_')) {
      return institutionId.split('_').first;
    }
    return institutionId;
  }

  Future<List<AdmissionFacultyModel>> fetchRequirements(String institutionId) async {
    final source = NetworkService.instance.isOnline ? Source.serverAndCache : Source.cache;

    final baseId = _getBaseInstitutionId(institutionId);
    final collectionName = '${baseId.toLowerCase()}_admission_data';

    debugPrint('[AdmissionDataService] Fetching requirements from: $collectionName/courses/faculties');

    final snapshot = await _firestore
        .collection(collectionName)
        .doc('courses')
        .collection('faculties')
        .get(GetOptions(source: source));

    debugPrint('[AdmissionDataService] Requirements: ${snapshot.docs.length} faculty docs');

    return snapshot.docs.map((doc) {
      final data = doc.data();
      final coursesMap = data['courses'] as Map<String, dynamic>? ?? {};
      final requirements = coursesMap.map((key, value) =>
          MapEntry(key, AdmissionCourseRequirementModel.fromMap(Map<String, dynamic>.from(value)))
      );

      return AdmissionFacultyModel(
        facultyId: doc.id,
        facultyName: data['facultyName'] ?? 'Unknown Faculty',
        requirements: requirements,
      );
    }).toList();
  }

  Future<List<AdmissionFacultyModel>> fetchCutOffs(String institutionId) async {
    final source = NetworkService.instance.isOnline ? Source.serverAndCache : Source.cache;

    final baseId = _getBaseInstitutionId(institutionId);
    final collectionName = '${baseId.toLowerCase()}_admission_data';

    debugPrint('[AdmissionDataService] Fetching cut-offs from: $collectionName/cut_offs_2023_2024/faculties');

    final snapshot = await _firestore
        .collection(collectionName)
        .doc('cut_offs_2023_2024')
        .collection('faculties')
        .get(GetOptions(source: source));

    debugPrint('[AdmissionDataService] Cut-offs: ${snapshot.docs.length} faculty docs');

    return snapshot.docs.map((doc) {
      final data = doc.data();
      final coursesMap = data['courses'] as Map<String, dynamic>? ?? {};
      final cutOffs = coursesMap.map((key, value) =>
          MapEntry(key, AdmissionCutOffModel.fromMap(Map<String, dynamic>.from(value)))
      );

      return AdmissionFacultyModel(
        facultyId: doc.id,
        facultyName: data['facultyName'] ?? 'Unknown Faculty',
        cutOffs: cutOffs,
      );
    }).toList();
  }
}
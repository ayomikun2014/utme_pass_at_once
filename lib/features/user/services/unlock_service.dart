import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/device_helper.dart';
import '../../../core/services/backend_api.dart';

class UnlockService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> validateActivationCode(String code) async {
    final trimmed = code.trim().toUpperCase();
    final doc = await _firestore.collection('vouchers').doc(trimmed).get();

    if (!doc.exists) throw Exception('Invalid activation code.');

    final data = doc.data() ?? {};
    final status = (data['status'] as String?) ?? '';

    if (status == 'used') {
      throw Exception('Activation code already used.');
    }
    final rawExamType = (data['examType'] ?? '').toString();
    if (rawExamType.isEmpty) {
      throw Exception('Invalid voucher configuration.');
    }

    return rawExamType.toLowerCase().trim();
  }

  Future<List<String>> fetchInstitutions(String examType) async {
    final normalized = examType.toLowerCase().trim();
    if (normalized != 'post_utme') {
      return [normalized];
    }
    final snapshot = await _firestore
        .collection('questionBank')
        .doc(normalized)
        .collection('institutions')
        .get();

    if (snapshot.docs.isEmpty) {
      throw Exception('No exam institutions available.');
    }

    return snapshot.docs.map((doc) => doc.id).toList();
  }

  Future<Map<String, Map<String, dynamic>>> getInstitutionNameMapping(
    String examType,
  ) async {
    try {
      final normalized = examType.toLowerCase().trim();
      if (normalized != 'post_utme') {
        final displayName = normalized == 'jamb'
            ? 'JAMB UTME'
            : normalized.toUpperCase();
        return {
          normalized: {'name': displayName, 'logo': null},
        };
      }
      final snapshot = await _firestore
          .collection('questionBank')
          .doc(normalized)
          .collection('institutions')
          .get();

      final Map<String, Map<String, dynamic>> mapping = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();

        String name = doc.id;
        if (data.containsKey('name')) {
          name = data['name'].toString();
        } else if (data.containsKey('Name')) {
          name = data['Name'].toString();
        }

        String? logo;
        if (data.containsKey('logoUrl') &&
            data['logoUrl'] != null &&
            data['logoUrl'].toString().isNotEmpty) {
          logo = data['logoUrl'].toString();
        } else if (data.containsKey('logo') &&
            data['logo'] != null &&
            data['logo'].toString().isNotEmpty) {
          logo = data['logo'].toString();
        }

        mapping[doc.id.toLowerCase()] = {'name': name, 'logo': logo};
      }

      return mapping;
    } catch (_) {
      return {};
    }
  }

  Future<List<String>> fetchSubjectsBySection(
    String examType,
    String institutionId,
    String sectionId,
  ) async {
    final normalized = examType.toLowerCase().trim();
    if (normalized != 'post_utme') {
      return fetchSubjects(examType, institutionId);
    }
    final snapshot = await _firestore
        .collection('questionBank')
        .doc(normalized)
        .collection('institutions')
        .doc(institutionId.toLowerCase())
        .collection('subjects')
        .where('sectionIds', arrayContains: sectionId)
        .get();

    if (snapshot.docs.isEmpty) {
      throw Exception('No subjects found for this section.');
    }

    return snapshot.docs.map((doc) {
      final data = doc.data();
      if (data.containsKey('name') && data['name'] != null) {
        return data['name'].toString();
      } else if (data.containsKey('Name') && data['Name'] != null) {
        return data['Name'].toString();
      }

      // Fallback: Capitalize each word of the ID
      return doc.id
          .split('_')
          .map((word) {
            if (word.isEmpty) return '';
            return word[0].toUpperCase() + word.substring(1).toLowerCase();
          })
          .join(' ');
    }).toList();
  }

  Future<List<String>> fetchSubjects(
    String examType,
    String institutionId,
  ) async {
    final normalized = examType.toLowerCase().trim();
    final QuerySnapshot<Map<String, dynamic>> snapshot;
    if (normalized != 'post_utme') {
      snapshot = await _firestore
          .collection('questionBank')
          .doc(normalized)
          .collection('subjects')
          .get();
    } else {
      snapshot = await _firestore
          .collection('questionBank')
          .doc(normalized)
          .collection('institutions')
          .doc(institutionId.toLowerCase())
          .collection('subjects')
          .get();
    }

    if (snapshot.docs.isEmpty) {
      throw Exception('No subjects found.');
    }

    return snapshot.docs.map((doc) {
      final data = doc.data();
      if (data.containsKey('name') && data['name'] != null) {
        return data['name'].toString();
      } else if (data.containsKey('Name') && data['Name'] != null) {
        return data['Name'].toString();
      }

      // Fallback: Capitalize each word of the ID
      return doc.id
          .split(' ')
          .map((word) {
            if (word.isEmpty) return '';
            return word[0].toUpperCase() + word.substring(1).toLowerCase();
          })
          .join(' ');
    }).toList();
  }

  /// Activate an exam with a code.
  ///
  /// The redemption itself belongs to the backend. It reads the voucher,
  /// marks it used, records the payment and writes the entitlement with the
  /// server's own credentials -- so none of those are writes the app needs to
  /// be allowed to make, and a reader cannot hand themselves an exam by
  /// writing to their own record.
  Future<void> activateExam({
    required String voucherCode,
    required String institutionId,
    required List<String> subjects,
    String? selectedSectionId,
    String? selectedSectionName,
  }) async {
    final normalizedSubjects = subjects
        .map((s) => s.toLowerCase().trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    await BackendApi.post('vouchers/redeem', {
      'code': voucherCode.trim().toUpperCase(),
      'institutionId': institutionId.toLowerCase().trim(),
      'sectionId': selectedSectionId ?? '',
      'sectionName': selectedSectionName ?? '',
      'subjects': normalizedSubjects,
      'deviceId': await DeviceHelper.getDeviceId(),
    });
  }
}

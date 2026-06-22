import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/device_helper.dart';

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
    final snapshot = await _firestore
        .collection('questionBank')
        .doc(normalized)
        .collection('institutions')
        .doc(institutionId.toLowerCase())
        .collection('subjects')
        .get();

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

  Future<void> activateExam({
    required String voucherCode,
    required String userId,
    required String examType,
    required String institutionId,
    required List<String> subjects,
    required String userName,
    String? selectedSectionId,
    String? selectedSectionName,
  }) async {
    final trimmedCode = voucherCode.trim().toUpperCase();
    final normalizedExamType = examType.toLowerCase().trim();
    final normalizedSubjects = subjects
        .map((s) => s.toLowerCase().trim())
        .toSet()
        .toList();

    final deviceId = await DeviceHelper.getDeviceId();

    final voucherRef = _firestore.collection('vouchers').doc(trimmedCode);
    final userRef = _firestore.collection('users').doc(userId);

    // Use a unique key for the institution/section (e.g., oau_science)
    final String institutionKey =
        (selectedSectionId != null && selectedSectionId.isNotEmpty)
        ? "${institutionId.toLowerCase()}_${selectedSectionId.toLowerCase()}"
        : institutionId.toLowerCase();

    // ------------------------------------------------------------------
    // Calculate Expiration Date (Current Date + 10 Months)
    // ------------------------------------------------------------------
    final now = DateTime.now();
    // Dart's DateTime automatically handles year overflow
    final expirationDate = DateTime(now.year, now.month + 10, now.day);

    await _firestore.runTransaction((transaction) async {
      // ------------------------------------------------------------------
      // STEP 1: Check if the user already has an active subscription for this
      // ------------------------------------------------------------------
      final userSnap = await transaction.get(userRef);
      if (userSnap.exists) {
        final userData = userSnap.data() ?? {};
        final packages =
            userData['examPackages'] as Map<String, dynamic>? ?? {};

        if (packages.containsKey(institutionKey)) {
          final existingPackage =
              packages[institutionKey] as Map<String, dynamic>;
          if (existingPackage['expiresAt'] != null) {
            final expiresAt = (existingPackage['expiresAt'] as Timestamp)
                .toDate();
            if (expiresAt.isAfter(DateTime.now())) {
              throw Exception(
                'You already have an active subscription for this section that has not expired yet.',
              );
            }
          }
        }
      }

      // ------------------------------------------------------------------
      // STEP 2: Validate the Voucher Code
      // ------------------------------------------------------------------
      final voucherSnap = await transaction.get(voucherRef);
      if (!voucherSnap.exists) {
        throw Exception('Invalid activation code.');
      }

      final voucherData = voucherSnap.data() ?? {};
      final voucherStatus = (voucherData['status'] ?? '')
          .toString()
          .toLowerCase();

      if (voucherStatus == 'used') {
        throw Exception('Activation code already used.');
      }

      final voucherExamType = (voucherData['examType'] ?? '')
          .toString()
          .toLowerCase()
          .trim();
      if (voucherExamType.isEmpty || voucherExamType != normalizedExamType) {
        throw Exception('Voucher exam type does not match this activation.');
      }

      // Fetch sub-admin details for referral if applicable (MUST BE DONE BEFORE WRITES)
      final String? createdBySubAdmin = (voucherData['subAdminId'] ?? voucherData['createdBy']) as String?;
      String? centerName;
      if (createdBySubAdmin != null && createdBySubAdmin.isNotEmpty) {
        final adminDoc = await transaction.get(
          _firestore.collection('admins').doc(createdBySubAdmin),
        );
        if (adminDoc.exists) {
          final data = adminDoc.data()!;
          centerName =
              data['schoolCenterName'] ?? data['name'] ?? 'Admin Center';
        }
      }

      // ------------------------------------------------------------------
      // STEP 3: Apply the updates securely within the transaction
      // ------------------------------------------------------------------
      // Mark voucher as used
      transaction.update(voucherRef, {
        'status': 'used',
        'isUsed': true,
        'usedByUid': userId,
        'usedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Always create a new used transaction record to represent the student's voucher redemption.
      // This tracks code usage and registers the admin/sub-admin who sold or generated the code,
      // while keeping the sub-admin's bulk purchase transaction record cleanly in 'completed' status.
      final String? paymentReference = voucherData['paymentReference'] as String?;
      final redemptionRef = _firestore.collection('payment_transactions').doc();
      transaction.set(redemptionRef, {
        'uid': userId,
        'examType': voucherExamType,
        'amount': voucherData['price'] ?? 0,
        'paymentMethod': 'voucher_redeemed',
        'status': 'used',
        'voucherCode': voucherCode,
        'subAdminUid': createdBySubAdmin ?? voucherData['generatedByAdminUid'] ?? voucherData['adminId'],
        if (paymentReference != null && paymentReference.isNotEmpty)
          'parentPaymentReference': paymentReference,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Save the Package Info with the `expiresAt` timestamp
      final Map<String, dynamic> packageInfo = {
        'accessType': 'premium',
        'examType': normalizedExamType,
        'institutionId': institutionId.toLowerCase(),
        'sectionId': selectedSectionId ?? '',
        'sectionName': selectedSectionName ?? '',
        'voucherCode': trimmedCode,
        'activatedAt': FieldValue.serverTimestamp(),
        'lastSyncedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          expirationDate,
        ), // <-- NEW 10 MONTH EXPIRATION
        'initialSubjectsFallback': normalizedSubjects,
      };

      final Map<String, dynamic> userUpdate = {
        'isPremium': true,
        'deviceId': deviceId,
        'activatedCodes': FieldValue.arrayUnion([trimmedCode]),
        'examPackages': {institutionKey: packageInfo},
        'examSelections': {
          normalizedExamType: {
            'deviceId': deviceId,
            'institutions': {institutionKey: packageInfo},
          },
        },
      };

      if (createdBySubAdmin != null && createdBySubAdmin.isNotEmpty) {
        userUpdate['referredBy'] = createdBySubAdmin;
        if (centerName != null) {
          userUpdate['schoolStatus'] = centerName;
        }
        userUpdate['referredCenters.$createdBySubAdmin'] = centerName ?? 'Admin Center';
        userUpdate['referredAdminsList'] = FieldValue.arrayUnion([createdBySubAdmin]);
      }

      transaction.set(userRef, userUpdate, SetOptions(merge: true));
    });

    // Audit log (fire-and-forget)
    try {
      await _firestore.collection('audit_logs').doc().set({
        'uid': userId,
        'userName': userName,
        'action': 'unlock_code',
        'timestamp': FieldValue.serverTimestamp(),
        'details': {
          'voucherCode': trimmedCode,
          'examType': normalizedExamType,
          'institutionId': institutionId,
          'institutionKey': institutionKey,
          'expiresAt': Timestamp.fromDate(expirationDate),
        },
      });
    } catch (_) {}
  }
}

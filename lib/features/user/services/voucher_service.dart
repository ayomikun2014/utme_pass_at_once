import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/purchase_model.dart';
import '../models/voucher_model.dart';

class VoucherService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<PurchaseModel>> fetchUserPurchases(String uid) async {
    try {
      final snap = await _db
          .collection('payment_transactions')
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();

      return snap.docs
          .map((d) => PurchaseModel.fromMap(d.data(), d.id))
          .where((item) => item.hiddenByUser != true)
          .toList();
    } catch (e) {
      debugPrint('❌ fetchUserPurchases error: $e');
      rethrow;
    }
  }

  Future<void> hideUserPurchase({
    required String transactionId,
    required String uid,
  }) async {
    try {
      await _db.collection('payment_transactions').doc(transactionId).update({
        'hiddenByUser': true,
        'userHiddenAt': FieldValue.serverTimestamp(),
        'userHiddenByUid': uid,
      });
    } catch (e) {
      debugPrint('❌ hideUserPurchase error: $e');
      rethrow;
    }
  }

  Future<List<VoucherModel>> fetchMyVouchers(String uid) async {
    try {
      final snap = await _db
          .collection('vouchers')
          .where('soldToUid', isEqualTo: uid)
          .orderBy('soldAt', descending: true)
          .get();

      return snap.docs
          .map((d) => VoucherModel.fromMap(d.data(), d.id))
          .toList();
    } catch (e) {
      debugPrint('❌ fetchMyVouchers error: $e');
      rethrow;
    }
  }

  Future<VoucherModel?> fetchVoucherByCode(String code) async {
    try {
      final snap = await _db
          .collection('vouchers')
          .doc(code.trim().toUpperCase())
          .get();

      if (!snap.exists) return null;
      return VoucherModel.fromMap(snap.data()!, snap.id);
    } catch (e) {
      debugPrint('❌ fetchVoucherByCode error: $e');
      return null;
    }
  }
}
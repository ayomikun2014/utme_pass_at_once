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

  /// Call off a payment that has not produced a code yet.
  ///
  /// Only the status is changed, which is all the rules let a buyer touch on
  /// their own transaction. If the money did arrive after all, the Paystack
  /// notice still generates the code -- cancelling here never loses a payment.
  Future<void> cancelPurchase({
    required String transactionId,
    required String reason,
  }) async {
    try {
      await _db.collection('payment_transactions').doc(transactionId).update({
        'status': 'cancelled',
        'failureReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ cancelPurchase error: $e');
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
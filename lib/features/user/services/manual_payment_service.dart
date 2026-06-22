import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class ManualPaymentService {
  ManualPaymentService._();
  static final ManualPaymentService instance = ManualPaymentService._();

  Future<void> submitManualPayment({
    required String uid,
    required String email,
    required String userName,
    required double amount,
    required String examType,
    required Uint8List imageBytes,
    required String imageExtension,
  }) async {
    try {
      // 1. Upload Proof of Payment to Firebase Storage
      final fileName = 'proof_${DateTime.now().millisecondsSinceEpoch}.$imageExtension';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('payment_proofs')
          .child(uid)
          .child(fileName);

      final uploadTask = await storageRef.putData(imageBytes);
      final proofUrl = await uploadTask.ref.getDownloadURL();

// 2. Save transaction to Firestore
      final reference = 'MANUAL_${DateTime.now().millisecondsSinceEpoch}_${uid.substring(0, 5)}';

      await FirebaseFirestore.instance.collection('payment_transactions').doc(reference).set({
        'uid': uid,
        'email': email,
        'userName': userName,
        'amount': amount,
        'amountKobo': (amount * 100).round(),
        'examType': examType,
        'status': 'pending',
        'paymentMethod': 'bank_transfer',
        'paystackReference': reference,
        'proofUrl': proofUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Note: Admin notifications are handled automatically by the Admin Panel
      // watching the payment_transactions Firestore collection, avoiding permission-denied logs.
    } catch (e) {
      debugPrint('❌ Error submitting manual payment: $e');
      rethrow;
    }
  }
}
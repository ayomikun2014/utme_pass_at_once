import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/backend_api.dart';

class ManualPaymentService {
  ManualPaymentService._();
  static final ManualPaymentService instance = ManualPaymentService._();

  /// The largest receipt the upload accepts.
  static const int maxUploadBytes = 8 * 1024 * 1024;

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
      if (imageBytes.length > maxUploadBytes) {
        throw Exception(
          'The receipt is too large to send. Please crop it and try again.',
        );
      }

      final reference =
          'MANUAL_${DateTime.now().millisecondsSinceEpoch}_${uid.substring(0, 5)}';
      final mime = _mimeFor(imageExtension);

      // The receipt goes to storage; the record keeps the path to it.
      final String proofPath;
      try {
        proofPath = await BackendApi.upload(
          path: 'receipts/$uid/$reference.${_extFor(mime)}',
          bytes: imageBytes,
          contentType: mime,
        );
      } catch (e) {
        debugPrint('Receipt upload failed: $e');
        throw Exception(
          'Could not upload your receipt. Please check your connection and try again.',
        );
      }

      await FirebaseFirestore.instance
          .collection('payment_transactions')
          .doc(reference)
          .set({
            'uid': uid,
            'email': email,
            'userName': userName,
            'amount': amount,
            'amountKobo': (amount * 100).round(),
            'examType': examType,
            'status': 'pending',
            'paymentMethod': 'bank_transfer',
            'paystackReference': reference,
            // Older records carry 'proofImage' or 'proofUrl' instead; the
            // admin panel still reads those.
            'proofPath': proofPath,
            'proofMime': mime,
            'proofBytes': imageBytes.length,
            'createdAt': FieldValue.serverTimestamp(),
          });

      // Note: Admin notifications are handled automatically by the Admin Panel
      // watching the payment_transactions Firestore collection, avoiding permission-denied logs.
    } catch (e) {
      debugPrint('❌ Error submitting manual payment: $e');
      rethrow;
    }
  }

  static String _mimeFor(String extension) {
    switch (extension.toLowerCase().replaceAll('.', '')) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  static String _extFor(String mime) => switch (mime) {
        'image/png' => 'png',
        'image/webp' => 'webp',
        'image/heic' => 'heic',
        _ => 'jpg',
      };
}

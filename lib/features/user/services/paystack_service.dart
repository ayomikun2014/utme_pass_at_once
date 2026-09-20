import 'package:flutter/foundation.dart';

import '../../../core/services/backend_api.dart';

/// Paystack checkout, through the backend (payments/initialize and
/// payments/verify). The secret key never reaches the app.
class PaystackService {
  PaystackService._();

  static final PaystackService instance = PaystackService._();

  Future<Map<String, dynamic>> initializeTransaction({
    required String email,
    required int amount,
    required String examType,
    required String uid,
    String? name,
  }) async {
    try {
      final data = await BackendApi.post('payments/initialize', {
        'email': email,
        'amount': amount,
        'examType': examType,
        'uid': uid,
        'name': name,
      });

      if (data['authorization_url'] == null || data['reference'] == null) {
        throw Exception('Invalid payment initialization response.');
      }

      return data;
    } catch (e) {
      debugPrint('❌ Error initializing transaction: $e');
      if (e is BackendException) throw Exception(e.message);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifyTransaction({
    required String reference,
  }) async {
    try {
      return await BackendApi.post('payments/verify', {'reference': reference});
    } catch (e) {
      debugPrint('❌ Error verifying transaction: $e');
      if (e is BackendException) throw Exception(e.message);
      rethrow;
    }
  }
}

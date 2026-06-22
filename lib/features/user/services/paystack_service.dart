import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:utme_pass_at_once/core/config/env.dart';

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
      final response = await http.post(
        Uri.parse(Env.paystackInitializeUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'amount': amount,
          'examType': examType,
          'uid': uid,
          'name': name,
        }),
      );

      final Map<String, dynamic> data =
      jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200 || data['status'] != true) {
        throw Exception(data['message'] ?? 'Failed to initialize transaction.');
      }

      if (data['authorization_url'] == null || data['reference'] == null) {
        throw Exception('Invalid payment initialization response.');
      }

      return data;
    } catch (e) {
      debugPrint('❌ Error initializing transaction: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifyTransaction({
    required String reference,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(Env.paystackVerifyUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'reference': reference,
        }),
      );

      final Map<String, dynamic> data =
      jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200 || data['status'] != true) {
        throw Exception(data['message'] ?? 'Failed to verify transaction.');
      }

      return data;
    } catch (e) {
      debugPrint('❌ Error verifying transaction: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> recordVoucherUsage({
    required String voucherCode,
    required String uid,
    String? email,
    String? userName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(Env.paystackRecordVoucherUsageUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'voucherCode': voucherCode,
          'uid': uid,
          'email': email,
          'userName': userName,
        }),
      );

      final Map<String, dynamic> data =
      jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200 || data['status'] != true) {
        throw Exception(data['message'] ?? 'Failed to record voucher usage.');
      }

      return data;
    } catch (e) {
      debugPrint('❌ Error recording voucher usage: $e');
      rethrow;
    }
  }
}
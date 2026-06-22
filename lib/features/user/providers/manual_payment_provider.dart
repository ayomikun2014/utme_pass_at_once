import 'dart:typed_data';
import 'package:flutter/material.dart';

// Import your service here
import '../services/manual_payment_service.dart';

class ManualPaymentProvider extends ChangeNotifier {
  bool _isLoading = false;
  String _errorMessage = '';

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  Future<bool> submitPayment({
    required String uid,
    required String email,
    required String userName,
    required double amount,
    required String examType,
    required Uint8List imageBytes,
    required String imageExtension,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = '';
      notifyListeners();

      await ManualPaymentService.instance.submitManualPayment(
        uid: uid,
        email: email,
        userName: userName,
        amount: amount,
        examType: examType,
        imageBytes: imageBytes,
        imageExtension: imageExtension,
      );

      _isLoading = false;
      notifyListeners();
      return true; // Success!

    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false; // Failed
    }
  }
}